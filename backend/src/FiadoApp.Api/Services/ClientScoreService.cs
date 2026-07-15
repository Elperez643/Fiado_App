using System.Security.Claims;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class ClientScoreService(FiadoDbContext dbContext) : IClientScoreService
{
    public async Task<ClientScoreResponse?> GetByClientAsync(ClaimsPrincipal user, Guid clientId)
    {
        var businessId = BusinessId(user);
        await EnsureClientForBusinessAsync(businessId, clientId);
        return await BaseQuery(businessId)
            .Where(x => x.ClientId == clientId)
            .OrderByDescending(x => x.LastCalculatedAt)
            .Select(x => MapScore(x))
            .FirstOrDefaultAsync();
    }

    public async Task<IReadOnlyList<ClientScoreResponse>> GetByBusinessAsync(ClaimsPrincipal user)
    {
        var businessId = BusinessIdForReports(user);
        return await BaseQuery(businessId)
            .OrderByDescending(x => x.LastCalculatedAt)
            .Select(x => MapScore(x))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<ClientScoreResponse>> GetTopClientsAsync(ClaimsPrincipal user, int take = 10)
    {
        var businessId = BusinessIdForReports(user);
        return await BaseQuery(businessId)
            .OrderByDescending(x => x.Score)
            .ThenByDescending(x => x.PaymentCompliancePercent)
            .Take(Math.Clamp(take, 1, 100))
            .Select(x => MapScore(x))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<ClientScoreResponse>> GetRiskClientsAsync(ClaimsPrincipal user, int take = 10)
    {
        var businessId = BusinessIdForReports(user);
        return await BaseQuery(businessId)
            .OrderBy(x => x.Score)
            .ThenByDescending(x => x.Blocked60Count)
            .Take(Math.Clamp(take, 1, 100))
            .Select(x => MapScore(x))
            .ToListAsync();
    }

    public async Task<ClientScoreSyncPushResponse> PushSyncAsync(
        ClaimsPrincipal user,
        ClientScoreSyncPushRequest request)
    {
        var businessId = BusinessId(user);
        var response = new ClientScoreSyncPushResponse { ServerTime = DateTime.UtcNow };

        foreach (var item in request.ClientScores)
        {
            response.Results.Add(await TryApplyPushAsync(businessId, item));
        }

        return response;
    }

    public async Task<ClientScoreSyncPullResponse> PullSyncAsync(
        ClaimsPrincipal user,
        ClientScoreSyncPullRequest request)
    {
        var businessId = BusinessId(user);
        var query = BaseQuery(businessId);
        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || x.LastSyncedAt > request.LastSyncAt);
        }

        return new ClientScoreSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            ClientScores = await query
                .OrderBy(x => x.UpdatedAt)
                .Select(x => MapScore(x))
                .ToListAsync()
        };
    }

    private IQueryable<ClientScore> BaseQuery(Guid businessId)
    {
        return dbContext.ClientScores
            .AsNoTracking()
            .Include(x => x.Client)
            .Where(x => x.BusinessId == businessId);
    }

    private async Task<ClientScoreSyncPushItemResponse> TryApplyPushAsync(
        Guid businessId,
        ClientScoreSyncPushItemRequest item)
    {
        try
        {
            var score = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertFromPushAsync(businessId, item, true),
                "update" => await UpsertFromPushAsync(businessId, item, true),
                "delete" => await SoftDeleteFromPushAsync(businessId, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };

            return new ClientScoreSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = score.Id,
                Status = item.Operation == "create" ? "created" : "updated",
                ServerUpdatedAt = score.UpdatedAt
            };
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return new ClientScoreSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = item.ServerId,
                Status = "failed",
                Error = ex.Message
            };
        }
    }

    private async Task<ClientScore> UpsertFromPushAsync(
        Guid businessId,
        ClientScoreSyncPushItemRequest item,
        bool allowCreate)
    {
        var now = DateTime.UtcNow;
        var client = await ResolveClientAsync(businessId, item.Payload);
        var score = await FindForPushAsync(businessId, item, client.Id, throwIfMissing: !allowCreate);

        score ??= new ClientScore
        {
            BusinessId = businessId,
            ClientId = client.Id,
            LocalId = item.LocalId,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        score.RemoteId = FinancialSyncMapper.Text(item.Payload, "remoteId", "remote_id") ?? score.RemoteId;
        score.ClientId = client.Id;
        score.Score = Math.Clamp(FinancialSyncMapper.IntValue(item.Payload, 0, "score"), 0, 100);
        score.RiskLevel = FinancialSyncMapper.Text(item.Payload, "riskLevel", "risk_level") ?? RiskLevel(score.Score);
        score.SuggestedCreditLimit = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["suggestedCreditLimit", "suggested_credit_limit"]);
        score.PaymentCompliancePercent = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["paymentCompliancePercent", "payment_compliance_percent"]);
        score.TotalCredits = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["totalCredits", "total_credits"]);
        score.TotalPayments = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["totalPayments", "total_payments"]);
        score.Overdue30Count = FinancialSyncMapper.IntValue(item.Payload, 0, "overdue30Count", "overdue_30_count");
        score.Overdue45Count = FinancialSyncMapper.IntValue(item.Payload, 0, "overdue45Count", "overdue_45_count");
        score.Blocked60Count = FinancialSyncMapper.IntValue(item.Payload, 0, "blocked60Count", "blocked_60_count");
        score.LastCalculatedAt = FinancialSyncMapper.DateValue(item.Payload, now, "lastCalculatedAt", "last_calculated_at");
        score.DeletedAt = null;
        score.UpdatedAt = now;
        score.LastSyncedAt = now;
        score.SyncStatus = "synced";

        if (score.Id == default || dbContext.Entry(score).State == EntityState.Detached)
        {
            dbContext.ClientScores.Add(score);
        }

        await dbContext.SaveChangesAsync();
        return score;
    }

    private async Task<ClientScore> SoftDeleteFromPushAsync(Guid businessId, ClientScoreSyncPushItemRequest item)
    {
        var client = await ResolveClientAsync(businessId, item.Payload);
        var score = await FindForPushAsync(businessId, item, client.Id, throwIfMissing: true)
            ?? throw new KeyNotFoundException("Score inteligente no encontrado para este negocio.");
        score.DeletedAt = DateTime.UtcNow;
        score.UpdatedAt = DateTime.UtcNow;
        score.LastSyncedAt = DateTime.UtcNow;
        score.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return score;
    }

    private async Task<ClientScore?> FindForPushAsync(
        Guid businessId,
        ClientScoreSyncPushItemRequest item,
        Guid clientId,
        bool throwIfMissing)
    {
        var query = dbContext.ClientScores.Where(x => x.BusinessId == businessId);
        var score = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);

        score ??= await query.FirstOrDefaultAsync(x => x.ClientId == clientId);

        if (score is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Score inteligente no encontrado para este negocio.");
        }

        return score;
    }

    private async Task<Client> ResolveClientAsync(Guid businessId, IReadOnlyDictionary<string, System.Text.Json.JsonElement> payload)
    {
        var clientId = FinancialSyncMapper.GuidValue(payload, "clientId", "client_id", "cliente_id");
        Client? client = null;
        if (clientId is not null)
        {
            client = await dbContext.Clients.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == clientId);
        }

        if (client is null)
        {
            var localId = FinancialSyncMapper.IntValue(payload, 0, "clientLocalId", "client_local_id", "cliente_local_id");
            if (localId > 0)
            {
                client = await dbContext.Clients.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.LocalId == localId);
            }
        }

        return client ?? throw new InvalidOperationException("Score inteligente requiere un cliente sincronizado del mismo negocio.");
    }

    private async Task<Client> EnsureClientForBusinessAsync(Guid businessId, Guid clientId)
    {
        var client = await dbContext.Clients.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == clientId);
        return client ?? throw new KeyNotFoundException("Cliente no encontrado para este negocio.");
    }

    private static Guid BusinessId(ClaimsPrincipal user)
        => FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "score inteligente");

    private static Guid BusinessIdForReports(ClaimsPrincipal user)
    {
        var role = user.FindFirstValue(ClaimTypes.Role);
        if (!string.Equals(role, "Negocio", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("Solo el negocio puede ver reportes globales de score inteligente.");
        }
        return BusinessId(user);
    }

    private static string RiskLevel(int score)
        => score >= 70 ? "Bajo riesgo" : score >= 40 ? "Riesgo medio" : "Riesgo alto";

    private static ClientScoreResponse MapScore(ClientScore score)
    {
        return new ClientScoreResponse
        {
            Id = score.Id,
            LocalId = score.LocalId,
            RemoteId = score.RemoteId,
            BusinessId = score.BusinessId,
            ClientId = score.ClientId,
            ClientName = score.Client?.Name ?? string.Empty,
            ClientPhone = score.Client?.Phone ?? string.Empty,
            Score = score.Score,
            RiskLevel = score.RiskLevel,
            SuggestedCreditLimit = score.SuggestedCreditLimit,
            PaymentCompliancePercent = score.PaymentCompliancePercent,
            TotalCredits = score.TotalCredits,
            TotalPayments = score.TotalPayments,
            Overdue30Count = score.Overdue30Count,
            Overdue45Count = score.Overdue45Count,
            Blocked60Count = score.Blocked60Count,
            LastCalculatedAt = score.LastCalculatedAt,
            CreatedAt = score.CreatedAt,
            UpdatedAt = score.UpdatedAt,
            DeletedAt = score.DeletedAt,
            LastSyncedAt = score.LastSyncedAt
        };
    }
}
