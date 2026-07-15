using System.Security.Claims;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class MovementService(FiadoDbContext dbContext) : IMovementService
{
    public async Task<IReadOnlyList<MovementResponse>> GetByClientAsync(ClaimsPrincipal user, Guid clientId)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "movimientos");
        await EnsureClientForBusinessAsync(businessId, clientId);

        return await dbContext.Movements.AsNoTracking()
            .Where(x => x.BusinessId == businessId && x.ClientId == clientId)
            .OrderByDescending(x => x.Date)
            .Select(x => MapMovement(x))
            .ToListAsync();
    }

    public async Task<MovementResponse> CreateAsync(ClaimsPrincipal user, MovementCreateRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "movimientos");
        var client = await EnsureClientForBusinessAsync(businessId, request.ClientId);
        var now = DateTime.UtcNow;
        var movement = new Movement
        {
            BusinessId = businessId,
            ClientId = client.Id,
            ClientName = client.Name,
            ClientPhone = client.Phone,
            Type = request.Type.Trim(),
            Amount = request.Amount,
            Concept = Normalize(request.Concept),
            Date = request.Date == default ? now : request.Date,
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            LastSyncedAt = now,
            SyncStatus = "synced"
        };

        dbContext.Movements.Add(movement);
        await dbContext.SaveChangesAsync();
        return MapMovement(movement);
    }

    public async Task<MovementResponse> UpdateAsync(ClaimsPrincipal user, Guid id, MovementUpdateRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "movimientos");
        var movement = await FindMovementAsync(businessId, id);
        var client = await EnsureClientForBusinessAsync(businessId, request.ClientId);
        var now = DateTime.UtcNow;

        movement.ClientId = client.Id;
        movement.ClientName = client.Name;
        movement.ClientPhone = client.Phone;
        movement.Type = request.Type.Trim();
        movement.Amount = request.Amount;
        movement.Concept = Normalize(request.Concept);
        movement.Date = request.Date == default ? movement.Date : request.Date;
        movement.IsActive = request.IsActive;
        movement.DeletedAt = request.IsActive ? null : now;
        movement.UpdatedAt = now;
        movement.LastSyncedAt = now;
        movement.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return MapMovement(movement);
    }

    public async Task<MovementSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, MovementSyncPushRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "movimientos");
        var response = new MovementSyncPushResponse { ServerTime = DateTime.UtcNow };
        foreach (var item in request.Movements)
        {
            response.Results.Add(await TryApplyMovementPushAsync(businessId, item));
        }
        return response;
    }

    public async Task<MovementSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, MovementSyncPullRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "movimientos");
        var query = dbContext.Movements.AsNoTracking().Where(x => x.BusinessId == businessId);
        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt));
        }

        return new MovementSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            Movements = await query.OrderBy(x => x.UpdatedAt).Select(x => MapMovement(x)).ToListAsync()
        };
    }

    public async Task<IReadOnlyList<DebtItemResponse>> GetDebtItemsByMovementAsync(ClaimsPrincipal user, Guid movementId)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "deuda items");
        _ = await FindMovementAsync(businessId, movementId);

        return await dbContext.DebtItems.AsNoTracking()
            .Where(x => x.BusinessId == businessId && x.MovementId == movementId)
            .OrderBy(x => x.CreatedAt)
            .Select(x => MapDebtItem(x))
            .ToListAsync();
    }

    public async Task<DebtItemSyncPushResponse> PushDebtItemsSyncAsync(ClaimsPrincipal user, DebtItemSyncPushRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "deuda items");
        var response = new DebtItemSyncPushResponse { ServerTime = DateTime.UtcNow };
        foreach (var item in request.DebtItems)
        {
            response.Results.Add(await TryApplyDebtItemPushAsync(businessId, item));
        }
        return response;
    }

    public async Task<DebtItemSyncPullResponse> PullDebtItemsSyncAsync(ClaimsPrincipal user, DebtItemSyncPullRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "deuda items");
        var query = dbContext.DebtItems.AsNoTracking().Where(x => x.BusinessId == businessId);
        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt));
        }

        return new DebtItemSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            DebtItems = await query.OrderBy(x => x.UpdatedAt).Select(x => MapDebtItem(x)).ToListAsync()
        };
    }

    private async Task<FinancialSyncPushItemResponse> TryApplyMovementPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        try
        {
            var movement = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertMovementFromPushAsync(businessId, item, true),
                "update" => await UpsertMovementFromPushAsync(businessId, item, false),
                "delete" => await DeleteMovementFromPushAsync(businessId, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };
            return PushResult(item.LocalId, movement.Id, item.Operation == "create" ? "created" : item.Operation == "delete" ? "deleted" : "updated", movement.UpdatedAt);
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return PushFailure(item, ex.Message);
        }
    }

    private async Task<Movement> UpsertMovementFromPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool allowCreate)
    {
        var movement = await FindMovementForPushAsync(businessId, item, throwIfMissing: !allowCreate);
        var now = DateTime.UtcNow;
        var clientId = FinancialSyncMapper.GuidValue(item.Payload, "clientId", "client_id") ??
            throw new InvalidOperationException("Movimiento requiere clientId.");
        var client = await EnsureClientForBusinessAsync(businessId, clientId);

        movement ??= new Movement
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            RemoteId = LocalUuid(item),
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        movement.RemoteId = LocalUuid(item) ?? movement.RemoteId;
        movement.ClientId = client.Id;
        movement.ClientName = client.Name;
        movement.ClientPhone = client.Phone;
        movement.Type = FinancialSyncMapper.Text(item.Payload, "type", "tipo") ?? "deuda";
        movement.Amount = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["amount", "monto"]);
        movement.Concept = FinancialSyncMapper.Text(item.Payload, "concept", "concepto");
        movement.Date = FinancialSyncMapper.DateValue(item.Payload, item.UpdatedAt == default ? now : item.UpdatedAt, "date", "fecha");
        movement.IsActive = FinancialSyncMapper.BoolValue(item.Payload, true, "isActive", "is_active", "activo");
        movement.DeletedAt = movement.IsActive ? null : now;
        movement.UpdatedAt = now;
        movement.LastSyncedAt = now;
        movement.SyncStatus = "synced";

        if (movement.Id == default || dbContext.Entry(movement).State == EntityState.Detached)
        {
            dbContext.Movements.Add(movement);
        }

        await dbContext.SaveChangesAsync();
        return movement;
    }

    private async Task<Movement> DeleteMovementFromPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        var movement = await FindMovementForPushAsync(businessId, item, throwIfMissing: true) ??
            throw new KeyNotFoundException("Movimiento no encontrado para este negocio.");
        var now = DateTime.UtcNow;
        movement.IsActive = false;
        movement.DeletedAt = now;
        movement.UpdatedAt = now;
        movement.LastSyncedAt = now;
        movement.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return movement;
    }

    private async Task<FinancialSyncPushItemResponse> TryApplyDebtItemPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        try
        {
            var debtItem = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertDebtItemFromPushAsync(businessId, item, true),
                "update" => await UpsertDebtItemFromPushAsync(businessId, item, false),
                "delete" => await DeleteDebtItemFromPushAsync(businessId, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };
            return PushResult(item.LocalId, debtItem.Id, item.Operation == "create" ? "created" : item.Operation == "delete" ? "deleted" : "updated", debtItem.UpdatedAt);
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return PushFailure(item, ex.Message);
        }
    }

    private async Task<DebtItem> UpsertDebtItemFromPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool allowCreate)
    {
        var debtItem = await FindDebtItemForPushAsync(businessId, item, throwIfMissing: !allowCreate);
        var now = DateTime.UtcNow;
        var movementId = FinancialSyncMapper.GuidValue(item.Payload, "movementId", "movement_id", "movimiento_id") ??
            throw new InvalidOperationException("Deuda item requiere movementId.");
        _ = await FindMovementAsync(businessId, movementId);

        debtItem ??= new DebtItem
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            RemoteId = LocalUuid(item),
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        debtItem.RemoteId = LocalUuid(item) ?? debtItem.RemoteId;
        debtItem.MovementId = movementId;
        debtItem.ProductId = FinancialSyncMapper.GuidValue(item.Payload, "productId", "product_id", "producto_id");
        debtItem.ProductName = FinancialSyncMapper.Text(item.Payload, "productName", "product_name", "nombre_producto") ?? string.Empty;
        debtItem.CodeReference = FinancialSyncMapper.Text(item.Payload, "codeReference", "code_reference", "codigo_referencia");
        debtItem.Quantity = FinancialSyncMapper.IntValue(item.Payload, keys: ["quantity", "cantidad"]);
        debtItem.UnitPrice = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["unitPrice", "unit_price", "precio_unitario"]);
        debtItem.Subtotal = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["subtotal"]);
        debtItem.DeletedAt = null;
        debtItem.UpdatedAt = now;
        debtItem.LastSyncedAt = now;
        debtItem.SyncStatus = "synced";

        if (debtItem.Id == default || dbContext.Entry(debtItem).State == EntityState.Detached)
        {
            dbContext.DebtItems.Add(debtItem);
        }

        await dbContext.SaveChangesAsync();
        return debtItem;
    }

    private async Task<DebtItem> DeleteDebtItemFromPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        var debtItem = await FindDebtItemForPushAsync(businessId, item, throwIfMissing: true) ??
            throw new KeyNotFoundException("Deuda item no encontrado para este negocio.");
        var now = DateTime.UtcNow;
        debtItem.DeletedAt = now;
        debtItem.UpdatedAt = now;
        debtItem.LastSyncedAt = now;
        debtItem.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return debtItem;
    }

    private async Task<Movement?> FindMovementForPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.Movements.Where(x => x.BusinessId == businessId);
        var localUuid = LocalUuid(item);
        var movement = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : null;
        movement ??= !string.IsNullOrWhiteSpace(localUuid)
            ? await query.FirstOrDefaultAsync(x => x.RemoteId == localUuid)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId && x.RemoteId == null);
        if (movement is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Movimiento no encontrado para este negocio.");
        }
        return movement;
    }

    private async Task<DebtItem?> FindDebtItemForPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.DebtItems.Where(x => x.BusinessId == businessId);
        var localUuid = LocalUuid(item);
        var debtItem = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : null;
        debtItem ??= !string.IsNullOrWhiteSpace(localUuid)
            ? await query.FirstOrDefaultAsync(x => x.RemoteId == localUuid)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId && x.RemoteId == null);
        if (debtItem is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Deuda item no encontrado para este negocio.");
        }
        return debtItem;
    }

    private async Task<Movement> FindMovementAsync(Guid businessId, Guid id)
    {
        var movement = await dbContext.Movements.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == id);
        return movement ?? throw new KeyNotFoundException("Movimiento no encontrado para este negocio.");
    }

    private async Task<Client> EnsureClientForBusinessAsync(Guid businessId, Guid clientId)
    {
        var client = await dbContext.Clients.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == clientId);
        return client ?? throw new KeyNotFoundException("Cliente no encontrado para este negocio.");
    }

    private static MovementResponse MapMovement(Movement movement)
    {
        return new MovementResponse
        {
            Id = movement.Id,
            LocalId = movement.LocalId,
            RemoteId = movement.RemoteId,
            BusinessId = movement.BusinessId,
            ClientId = movement.ClientId,
            ClientName = movement.ClientName,
            ClientPhone = movement.ClientPhone,
            Type = movement.Type,
            Amount = movement.Amount,
            Concept = movement.Concept,
            Date = movement.Date,
            IsActive = movement.IsActive,
            CreatedAt = movement.CreatedAt,
            UpdatedAt = movement.UpdatedAt,
            DeletedAt = movement.DeletedAt,
            LastSyncedAt = movement.LastSyncedAt
        };
    }

    private static DebtItemResponse MapDebtItem(DebtItem item)
    {
        return new DebtItemResponse
        {
            Id = item.Id,
            LocalId = item.LocalId,
            RemoteId = item.RemoteId,
            BusinessId = item.BusinessId,
            MovementId = item.MovementId,
            ProductId = item.ProductId,
            ProductName = item.ProductName,
            CodeReference = item.CodeReference,
            Quantity = item.Quantity,
            UnitPrice = item.UnitPrice,
            Subtotal = item.Subtotal,
            CreatedAt = item.CreatedAt,
            UpdatedAt = item.UpdatedAt,
            DeletedAt = item.DeletedAt,
            LastSyncedAt = item.LastSyncedAt
        };
    }

    private static FinancialSyncPushItemResponse PushResult(int localId, Guid serverId, string status, DateTime serverUpdatedAt)
    {
        return new FinancialSyncPushItemResponse { LocalId = localId, ServerId = serverId, Status = status, ServerUpdatedAt = serverUpdatedAt };
    }

    private static FinancialSyncPushItemResponse PushFailure(FinancialSyncPushItemRequest item, string error)
    {
        return new FinancialSyncPushItemResponse { LocalId = item.LocalId, ServerId = item.ServerId, Status = "failed", Error = error };
    }

    private static string? LocalUuid(FinancialSyncPushItemRequest item)
    {
        return FinancialSyncMapper.Text(item.Payload, "localUuid", "local_uuid", "idempotencyKey", "idempotency_key");
    }

    private static string? Normalize(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }
}
