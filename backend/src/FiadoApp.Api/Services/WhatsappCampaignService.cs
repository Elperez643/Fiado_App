using System.Security.Claims;
using System.Text.Json;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class WhatsappCampaignService(FiadoDbContext dbContext) : IWhatsappCampaignService
{
    public async Task<WhatsappCampaignSyncPushResponse> PushSyncAsync(
        ClaimsPrincipal user,
        WhatsappCampaignSyncPushRequest request)
    {
        var businessId = BusinessId(user);
        var response = new WhatsappCampaignSyncPushResponse { ServerTime = DateTime.UtcNow };

        foreach (var item in request.Campaigns)
        {
            response.Results.Add(await TryApplyPushAsync(businessId, item));
        }

        return response;
    }

    public async Task<WhatsappCampaignSyncPullResponse> PullSyncAsync(
        ClaimsPrincipal user,
        WhatsappCampaignSyncPullRequest request)
    {
        var businessId = BusinessId(user);
        var query = dbContext.WhatsappCampaignPublications
            .AsNoTracking()
            .Where(x => x.BusinessId == businessId);

        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || x.LastSyncedAt > request.LastSyncAt);
        }

        return new WhatsappCampaignSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            Campaigns = await query
                .OrderBy(x => x.UpdatedAt)
                .Select(x => Map(x))
                .ToListAsync()
        };
    }

    private async Task<WhatsappCampaignSyncPushItemResponse> TryApplyPushAsync(
        Guid businessId,
        WhatsappCampaignSyncPushItemRequest item)
    {
        try
        {
            var campaign = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertFromPushAsync(businessId, item, true),
                "update" => await UpsertFromPushAsync(businessId, item, true),
                "delete" => await SoftDeleteFromPushAsync(businessId, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };

            return new WhatsappCampaignSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = campaign.Id,
                Status = item.Operation == "create" ? "created" : "updated",
                ServerUpdatedAt = campaign.UpdatedAt
            };
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return new WhatsappCampaignSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = item.ServerId,
                Status = "failed",
                Error = ex.Message
            };
        }
    }

    private async Task<WhatsappCampaignPublication> UpsertFromPushAsync(
        Guid businessId,
        WhatsappCampaignSyncPushItemRequest item,
        bool allowCreate)
    {
        var now = DateTime.UtcNow;
        var localUuid = Text(item.Payload, "localUuid", "local_uuid") ??
            throw new InvalidOperationException("Campana WhatsApp requiere localUuid.");
        var campaign = await FindForPushAsync(businessId, item, localUuid, throwIfMissing: !allowCreate);

        campaign ??= new WhatsappCampaignPublication
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            LocalUuid = localUuid,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        campaign.RemoteId = Text(item.Payload, "remoteId", "remote_id") ?? campaign.RemoteId;
        campaign.LocalUuid = localUuid;
        campaign.DateKey = Text(item.Payload, "dateKey", "date_key") ?? DateKey(now);
        campaign.Mode = Text(item.Payload, "mode") ?? "catalogo";
        campaign.ProductIdsJson = JsonArrayText(item.Payload, "productIds", "product_ids");
        campaign.RenderedImagePathsJson = JsonArrayText(item.Payload, "renderedImagePaths", "rendered_image_paths");
        campaign.StatusTextsJson = JsonArrayText(item.Payload, "statusTexts", "status_texts");
        campaign.Status = Text(item.Payload, "status") ?? "pendiente";
        campaign.CampaignStatus = Text(item.Payload, "campaignStatus", "campaign_status") ?? "activo";
        campaign.ConsumesQuota = BoolValue(item.Payload, "consumesQuota", "consumes_quota");
        campaign.QuotaUnits = Math.Clamp(IntValue(item.Payload, 1, "quotaUnits", "quota_units"), 1, 500);
        campaign.StartDate = DateValue(item.Payload, now, "startDate", "fechaInicio", "fecha_inicio");
        campaign.DurationDays = DurationDays(item.Payload);
        campaign.OpenedWhatsappAt = DateValueOrNull(item.Payload, "openedWhatsappAt", "opened_whatsapp_at");
        campaign.ConfirmedByUserAt = DateValueOrNull(item.Payload, "confirmedByUserAt", "confirmed_by_user_at");
        campaign.CanceledByUserAt = DateValueOrNull(item.Payload, "canceledByUserAt", "canceled_by_user_at");
        campaign.FailedAt = DateValueOrNull(item.Payload, "failedAt", "failed_at");
        campaign.EstimatedExpiresAt = DateValueOrNull(item.Payload, "estimatedExpiresAt", "estimated_expires_at");
        campaign.Error = Text(item.Payload, "error");
        var hasActiveFlag = item.Payload.ContainsKey("isActive") || item.Payload.ContainsKey("is_active");
        campaign.IsActive = !BoolValue(item.Payload, "deleted", "isDeleted") &&
            (!hasActiveFlag || BoolValue(item.Payload, "isActive", "is_active"));
        campaign.DeletedAt = DateValueOrNull(item.Payload, "deletedAt", "deleted_at");
        campaign.UpdatedAt = now;
        campaign.LastSyncedAt = now;
        campaign.SyncStatus = "synced";

        if (campaign.Id == default || dbContext.Entry(campaign).State == EntityState.Detached)
        {
            dbContext.WhatsappCampaignPublications.Add(campaign);
        }

        await dbContext.SaveChangesAsync();
        return campaign;
    }

    private async Task<WhatsappCampaignPublication> SoftDeleteFromPushAsync(
        Guid businessId,
        WhatsappCampaignSyncPushItemRequest item)
    {
        var localUuid = Text(item.Payload, "localUuid", "local_uuid") ?? string.Empty;
        var campaign = await FindForPushAsync(businessId, item, localUuid, throwIfMissing: true)
            ?? throw new KeyNotFoundException("Campana WhatsApp no encontrada para este negocio.");
        campaign.IsActive = false;
        campaign.DeletedAt = DateTime.UtcNow;
        campaign.UpdatedAt = DateTime.UtcNow;
        campaign.LastSyncedAt = DateTime.UtcNow;
        campaign.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return campaign;
    }

    private async Task<WhatsappCampaignPublication?> FindForPushAsync(
        Guid businessId,
        WhatsappCampaignSyncPushItemRequest item,
        string localUuid,
        bool throwIfMissing)
    {
        var query = dbContext.WhatsappCampaignPublications.Where(x => x.BusinessId == businessId);
        var campaign = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);

        if (campaign is null && !string.IsNullOrWhiteSpace(localUuid))
        {
            campaign = await query.FirstOrDefaultAsync(x => x.LocalUuid == localUuid);
        }

        if (campaign is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Campana WhatsApp no encontrada para este negocio.");
        }

        return campaign;
    }

    private static Guid BusinessId(ClaimsPrincipal user)
        => FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "campanas WhatsApp");

    private static WhatsappCampaignResponse Map(WhatsappCampaignPublication campaign)
    {
        return new WhatsappCampaignResponse
        {
            Id = campaign.Id,
            LocalId = campaign.LocalId,
            RemoteId = campaign.RemoteId,
            BusinessId = campaign.BusinessId,
            LocalUuid = campaign.LocalUuid,
            DateKey = campaign.DateKey,
            Mode = campaign.Mode,
            ProductIds = JsonList(campaign.ProductIdsJson),
            RenderedImagePaths = JsonList(campaign.RenderedImagePathsJson),
            StatusTexts = JsonList(campaign.StatusTextsJson),
            Status = campaign.Status,
            CampaignStatus = campaign.CampaignStatus,
            ConsumesQuota = campaign.ConsumesQuota,
            QuotaUnits = campaign.QuotaUnits,
            StartDate = campaign.StartDate,
            DurationDays = campaign.DurationDays,
            CreatedAt = campaign.CreatedAt,
            UpdatedAt = campaign.UpdatedAt,
            OpenedWhatsappAt = campaign.OpenedWhatsappAt,
            ConfirmedByUserAt = campaign.ConfirmedByUserAt,
            CanceledByUserAt = campaign.CanceledByUserAt,
            FailedAt = campaign.FailedAt,
            EstimatedExpiresAt = campaign.EstimatedExpiresAt,
            Error = campaign.Error,
            IsActive = campaign.IsActive,
            DeletedAt = campaign.DeletedAt,
            LastSyncedAt = campaign.LastSyncedAt
        };
    }

    private static List<string> JsonList(string json)
        => JsonSerializer.Deserialize<List<string>>(json) ?? [];

    private static string JsonArrayText(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (payload.TryGetValue(key, out var value) && value.ValueKind == JsonValueKind.Array)
            {
                return value.GetRawText();
            }
        }

        return "[]";
    }

    private static string? Text(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
        => FinancialSyncMapper.Text(payload, keys);

    private static int IntValue(IReadOnlyDictionary<string, JsonElement> payload, int defaultValue, params string[] keys)
        => FinancialSyncMapper.IntValue(payload, defaultValue, keys);

    private static DateTime DateValue(IReadOnlyDictionary<string, JsonElement> payload, DateTime defaultValue, params string[] keys)
        => FinancialSyncMapper.DateValue(payload, defaultValue, keys);

    private static DateTime? DateValueOrNull(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (payload.TryGetValue(key, out var value) &&
                value.ValueKind != JsonValueKind.Null &&
                DateTime.TryParse(value.ToString(), out var date))
            {
                return date;
            }
        }

        return null;
    }

    private static bool BoolValue(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (!payload.TryGetValue(key, out var value)) continue;
            if (value.ValueKind is JsonValueKind.True) return true;
            if (value.ValueKind is JsonValueKind.False) return false;
            if (bool.TryParse(value.ToString(), out var parsed)) return parsed;
        }

        return false;
    }

    private static int DurationDays(IReadOnlyDictionary<string, JsonElement> payload)
    {
        var value = IntValue(payload, 7, "durationDays", "duracionDias", "duracion_dias");
        return value is 15 or 30 ? value : 7;
    }

    private static string DateKey(DateTime date)
        => $"{date.Year}{date.Month.ToString().PadLeft(2, '0')}{date.Day.ToString().PadLeft(2, '0')}";
}
