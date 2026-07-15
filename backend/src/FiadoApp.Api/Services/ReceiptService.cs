using System.Security.Claims;
using System.Text.Json;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class ReceiptService(FiadoDbContext dbContext) : IReceiptService
{
    public async Task<IReadOnlyList<ReceiptResponse>> GetByClientAsync(ClaimsPrincipal user, Guid clientId)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "comprobantes");
        await EnsureClientForBusinessAsync(businessId, clientId);
        return await dbContext.Receipts.AsNoTracking()
            .Where(x => x.BusinessId == businessId && x.ClientId == clientId)
            .OrderByDescending(x => x.Date)
            .Select(x => Map(x))
            .ToListAsync();
    }

    public async Task<ReceiptResponse> GetByIdAsync(ClaimsPrincipal user, Guid id)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "comprobantes");
        return Map(await FindReceiptAsync(businessId, id));
    }

    public async Task<ReceiptResponse> GetByCodeAsync(ClaimsPrincipal user, string code)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "comprobantes");
        var receipt = await dbContext.Receipts.AsNoTracking()
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.ReceiptCode == code);
        return Map(receipt ?? throw new KeyNotFoundException("Comprobante no encontrado para este negocio."));
    }

    public async Task<ReceiptSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, ReceiptSyncPushRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "comprobantes");
        var response = new ReceiptSyncPushResponse { ServerTime = DateTime.UtcNow };
        foreach (var item in request.Receipts)
        {
            response.Results.Add(await TryApplyPushAsync(businessId, item));
        }
        return response;
    }

    public async Task<ReceiptSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, ReceiptSyncPullRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "comprobantes");
        var query = dbContext.Receipts.AsNoTracking().Where(x => x.BusinessId == businessId);
        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt));
        }

        return new ReceiptSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            Receipts = await query.OrderBy(x => x.UpdatedAt).Select(x => Map(x)).ToListAsync()
        };
    }

    private async Task<FinancialSyncPushItemResponse> TryApplyPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        try
        {
            var receipt = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertFromPushAsync(businessId, item, true),
                "update" => await UpsertFromPushAsync(businessId, item, false),
                "delete" => await DeleteFromPushAsync(businessId, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };
            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = receipt.Id,
                Status = item.Operation == "delete" ? "deleted" : item.Operation == "create" ? "created" : "updated",
                ServerUpdatedAt = receipt.UpdatedAt
            };
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = item.ServerId,
                Status = "failed",
                Error = ex.Message
            };
        }
    }

    private async Task<Receipt> UpsertFromPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool allowCreate)
    {
        var receipt = await FindForPushAsync(businessId, item, throwIfMissing: !allowCreate);
        var now = DateTime.UtcNow;
        var movementId = FinancialSyncMapper.GuidValue(item.Payload, "movementId", "movement_id", "movimiento_id") ??
            throw new InvalidOperationException("Comprobante requiere movementId.");
        var movement = await dbContext.Movements.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == movementId) ??
            throw new KeyNotFoundException("Movimiento no encontrado para este negocio.");
        var clientId = FinancialSyncMapper.GuidValue(item.Payload, "clientId", "client_id") ?? movement.ClientId;
        var client = await EnsureClientForBusinessAsync(businessId, clientId);
        var receiptCode = FinancialSyncMapper.Text(item.Payload, "receiptCode", "receipt_code", "codigo_comprobante") ??
            throw new InvalidOperationException("Comprobante requiere receiptCode.");

        var duplicate = await dbContext.Receipts.AnyAsync(x =>
            x.BusinessId == businessId &&
            x.ReceiptCode == receiptCode &&
            (receipt == null || x.Id != receipt.Id));
        if (duplicate)
        {
            throw new InvalidOperationException("Ya existe un comprobante con ese codigo en este negocio.");
        }

        receipt ??= new Receipt
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        receipt.MovementId = movement.Id;
        receipt.ClientId = client.Id;
        receipt.ClientName = client.Name;
        receipt.ClientPhone = client.Phone;
        receipt.ReceiptCode = receiptCode;
        receipt.Type = FinancialSyncMapper.Text(item.Payload, "type", "tipo") ?? movement.Type;
        receipt.PayloadJson = BuildPayloadJson(item.Payload);
        receipt.Total = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["total"]);
        receipt.PreviousBalance = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["previousBalance", "previous_balance", "saldo_anterior"]);
        receipt.NewBalance = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["newBalance", "new_balance", "saldo_nuevo"]);
        receipt.Date = FinancialSyncMapper.DateValue(item.Payload, item.UpdatedAt == default ? now : item.UpdatedAt, "date", "fecha");
        receipt.Subtotal = FinancialSyncMapper.DecimalValue(item.Payload, receipt.Total, "subtotal");
        receipt.DeletedAt = null;
        receipt.UpdatedAt = now;
        receipt.LastSyncedAt = now;
        receipt.SyncStatus = "synced";

        if (receipt.Id == default || dbContext.Entry(receipt).State == EntityState.Detached)
        {
            dbContext.Receipts.Add(receipt);
        }

        await dbContext.SaveChangesAsync();
        return receipt;
    }

    private async Task<Receipt> DeleteFromPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        var receipt = await FindForPushAsync(businessId, item, throwIfMissing: true) ??
            throw new KeyNotFoundException("Comprobante no encontrado para este negocio.");
        var now = DateTime.UtcNow;
        receipt.DeletedAt = now;
        receipt.UpdatedAt = now;
        receipt.LastSyncedAt = now;
        receipt.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return receipt;
    }

    private async Task<Receipt?> FindForPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.Receipts.Where(x => x.BusinessId == businessId);
        var receipt = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);
        if (receipt is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Comprobante no encontrado para este negocio.");
        }
        return receipt;
    }

    private async Task<Receipt> FindReceiptAsync(Guid businessId, Guid id)
    {
        var receipt = await dbContext.Receipts.AsNoTracking().FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == id);
        return receipt ?? throw new KeyNotFoundException("Comprobante no encontrado para este negocio.");
    }

    private async Task<Client> EnsureClientForBusinessAsync(Guid businessId, Guid clientId)
    {
        var client = await dbContext.Clients.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == clientId);
        return client ?? throw new KeyNotFoundException("Cliente no encontrado para este negocio.");
    }

    private static ReceiptResponse Map(Receipt receipt)
    {
        return new ReceiptResponse
        {
            Id = receipt.Id,
            LocalId = receipt.LocalId,
            RemoteId = receipt.RemoteId,
            BusinessId = receipt.BusinessId,
            MovementId = receipt.MovementId,
            ClientId = receipt.ClientId,
            ReceiptCode = receipt.ReceiptCode,
            Type = receipt.Type,
            ClientName = receipt.ClientName,
            ClientPhone = receipt.ClientPhone,
            BusinessName = receipt.BusinessName,
            PayloadJson = receipt.PayloadJson,
            Total = receipt.Total,
            PreviousBalance = receipt.PreviousBalance,
            NewBalance = receipt.NewBalance,
            Date = receipt.Date,
            CreatedAt = receipt.CreatedAt,
            UpdatedAt = receipt.UpdatedAt,
            DeletedAt = receipt.DeletedAt,
            LastSyncedAt = receipt.LastSyncedAt
        };
    }

    private static string BuildPayloadJson(Dictionary<string, JsonElement> payload)
    {
        var raw = FinancialSyncMapper.Text(payload, "payloadJson", "payload_json");
        return string.IsNullOrWhiteSpace(raw) ? JsonSerializer.Serialize(payload) : raw;
    }
}
