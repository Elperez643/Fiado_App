using System.Security.Claims;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class AuditService(FiadoDbContext dbContext) : IAuditService
{
    public async Task<IReadOnlyList<AuditResponse>> GetAuditsAsync(ClaimsPrincipal user)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "auditorias");
        var query = BaseAuditQuery(businessId, user);
        return await query.OrderByDescending(x => x.Date).Select(x => MapAudit(x)).ToListAsync();
    }

    public async Task<AuditResponse> GetByIdAsync(ClaimsPrincipal user, Guid id)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "auditorias");
        var audit = await BaseAuditQuery(businessId, user).FirstOrDefaultAsync(x => x.Id == id);
        return MapAudit(audit ?? throw new KeyNotFoundException("Auditoria no encontrada para este negocio."));
    }

    public async Task<IReadOnlyList<AuditReportResponse>> GetBusinessReportAsync(ClaimsPrincipal user)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "auditorias");
        if (!OperationalSyncMapper.IsBusiness(user))
        {
            throw new UnauthorizedAccessException("Solo el negocio puede consultar reportes globales de auditoria.");
        }

        return await dbContext.Audits.AsNoTracking()
            .Include(x => x.Collaborator)
            .Include(x => x.Items)
            .Where(x => x.BusinessId == businessId && x.DeletedAt == null)
            .OrderByDescending(x => x.Date)
            .Select(x => new AuditReportResponse
            {
                AuditId = x.Id,
                Collaborator = x.Collaborator == null ? null : x.Collaborator.Name,
                Date = x.Date,
                Type = x.Type,
                ProductsReviewed = x.ValidatedProducts,
                DifferencesFound = x.Items.Count(i => i.PhysicalStock != null && i.PhysicalStock != i.SystemStock),
                Observations = x.Observations
            })
            .ToListAsync();
    }

    public async Task<IReadOnlyList<AuditResponse>> GetMyAuditsAsync(ClaimsPrincipal user)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "auditorias");
        var userId = OperationalSyncMapper.UserId(user);
        return await dbContext.Audits.AsNoTracking()
            .Include(x => x.Collaborator)
            .Where(x => x.BusinessId == businessId && x.CollaboratorId == userId)
            .OrderByDescending(x => x.Date)
            .Select(x => MapAudit(x))
            .ToListAsync();
    }

    public async Task<AuditSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, AuditSyncPushRequest request)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "auditorias");
        var response = new AuditSyncPushResponse { ServerTime = DateTime.UtcNow };
        foreach (var item in request.Audits)
        {
            response.Results.Add(await TryApplyAuditAsync(businessId, user, item));
        }
        return response;
    }

    public async Task<AuditSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, AuditSyncPullRequest request)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "auditorias");
        var query = BaseAuditQuery(businessId, user);
        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt));
        }
        return new AuditSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            Audits = await query.OrderBy(x => x.UpdatedAt).Select(x => MapAudit(x)).ToListAsync()
        };
    }

    public async Task<AuditItemSyncPushResponse> PushItemsSyncAsync(ClaimsPrincipal user, AuditItemSyncPushRequest request)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "audit items");
        var response = new AuditItemSyncPushResponse { ServerTime = DateTime.UtcNow };
        foreach (var item in request.AuditItems)
        {
            response.Results.Add(await TryApplyAuditItemAsync(businessId, user, item));
        }
        return response;
    }

    public async Task<AuditItemSyncPullResponse> PullItemsSyncAsync(ClaimsPrincipal user, AuditItemSyncPullRequest request)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "audit items");
        var allowedAuditIds = BaseAuditQuery(businessId, user).Select(x => x.Id);
        var query = dbContext.AuditItems.AsNoTracking()
            .Where(x => x.BusinessId == businessId && allowedAuditIds.Contains(x.AuditId));
        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt));
        }
        return new AuditItemSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            AuditItems = await query.OrderBy(x => x.UpdatedAt).Select(x => MapItem(x)).ToListAsync()
        };
    }

    private IQueryable<Audit> BaseAuditQuery(Guid businessId, ClaimsPrincipal user)
    {
        var query = dbContext.Audits.AsNoTracking().Include(x => x.Collaborator).Where(x => x.BusinessId == businessId);
        if (OperationalSyncMapper.IsCollaborator(user))
        {
            var userId = OperationalSyncMapper.UserId(user);
            query = query.Where(x => x.CollaboratorId == userId);
        }
        return query;
    }

    private async Task<OperationalSyncPushItemResponse> TryApplyAuditAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item)
    {
        try
        {
            var audit = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertAuditAsync(businessId, user, item, true),
                "update" => await UpsertAuditAsync(businessId, user, item, false),
                "delete" => await DeleteAuditAsync(businessId, user, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };
            return Result(item.LocalId, audit.Id, item.Operation == "delete" ? "deleted" : item.Operation == "create" ? "created" : "updated", audit.UpdatedAt);
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException or UnauthorizedAccessException)
        {
            return Failure(item, ex.Message);
        }
    }

    private async Task<Audit> UpsertAuditAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item, bool allowCreate)
    {
        var audit = await FindAuditForPushAsync(businessId, item, !allowCreate);
        var now = DateTime.UtcNow;
        var collaboratorId = OperationalSyncMapper.GuidValue(item.Payload, "collaboratorId", "collaborator_id", "colaborador_id");
        if (OperationalSyncMapper.IsCollaborator(user))
        {
            collaboratorId = OperationalSyncMapper.UserId(user);
        }
        if (collaboratorId is not null)
        {
            await EnsureCollaboratorAsync(businessId, collaboratorId.Value);
        }
        audit ??= new Audit { BusinessId = businessId, LocalId = item.LocalId, CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt };
        EnsureAuditAccess(user, audit);
        audit.CollaboratorId = collaboratorId;
        audit.Type = OperationalSyncMapper.Text(item.Payload, "type", "tipo") ?? "diaria";
        audit.Date = OperationalSyncMapper.DateValue(item.Payload, now, "date", "fecha");
        audit.Status = OperationalSyncMapper.Text(item.Payload, "status", "estado") ?? "pendiente";
        audit.TotalProducts = OperationalSyncMapper.IntValue(item.Payload, keys: ["totalProducts", "total_products", "total_productos"]);
        audit.ValidatedProducts = OperationalSyncMapper.IntValue(item.Payload, keys: ["validatedProducts", "validated_products", "productos_validados"]);
        audit.Observations = OperationalSyncMapper.Text(item.Payload, "observations", "observaciones", "notes");
        audit.DeletedAt = null;
        audit.UpdatedAt = now;
        audit.LastSyncedAt = now;
        audit.SyncStatus = "synced";
        if (audit.Id == default || dbContext.Entry(audit).State == EntityState.Detached) dbContext.Audits.Add(audit);
        await dbContext.SaveChangesAsync();
        return audit;
    }

    private async Task<Audit> DeleteAuditAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item)
    {
        var audit = await FindAuditForPushAsync(businessId, item, true) ?? throw new KeyNotFoundException("Auditoria no encontrada.");
        EnsureAuditAccess(user, audit);
        var now = DateTime.UtcNow;
        audit.DeletedAt = now;
        audit.UpdatedAt = now;
        audit.LastSyncedAt = now;
        audit.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return audit;
    }

    private async Task<OperationalSyncPushItemResponse> TryApplyAuditItemAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item)
    {
        try
        {
            var auditItem = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertAuditItemAsync(businessId, user, item, true),
                "update" => await UpsertAuditItemAsync(businessId, user, item, false),
                "delete" => await DeleteAuditItemAsync(businessId, user, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };
            return Result(item.LocalId, auditItem.Id, item.Operation == "delete" ? "deleted" : item.Operation == "create" ? "created" : "updated", auditItem.UpdatedAt);
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException or UnauthorizedAccessException)
        {
            return Failure(item, ex.Message);
        }
    }

    private async Task<AuditItem> UpsertAuditItemAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item, bool allowCreate)
    {
        var auditItem = await FindItemForPushAsync(businessId, item, !allowCreate);
        var auditId = OperationalSyncMapper.GuidValue(item.Payload, "auditId", "audit_id", "auditoria_id") ?? throw new InvalidOperationException("Audit item requiere auditId.");
        var audit = await dbContext.Audits.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == auditId) ?? throw new KeyNotFoundException("Auditoria no encontrada.");
        EnsureAuditAccess(user, audit);
        var productId = OperationalSyncMapper.GuidValue(item.Payload, "productId", "product_id", "producto_id") ?? throw new InvalidOperationException("Audit item requiere productId.");
        var productExists = await dbContext.Products.AnyAsync(x => x.BusinessId == businessId && x.Id == productId);
        if (!productExists) throw new KeyNotFoundException("Producto no encontrado para este negocio.");
        var now = DateTime.UtcNow;
        auditItem ??= new AuditItem { BusinessId = businessId, LocalId = item.LocalId, CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt };
        auditItem.BusinessId = businessId;
        auditItem.AuditId = auditId;
        auditItem.ProductId = productId;
        auditItem.SystemStock = OperationalSyncMapper.IntValue(item.Payload, keys: ["systemStock", "system_stock", "stock_sistema"]);
        auditItem.PhysicalStock = OperationalSyncMapper.IntValue(item.Payload, int.MinValue, "physicalStock", "physical_stock", "stock_fisico");
        if (auditItem.PhysicalStock == int.MinValue) auditItem.PhysicalStock = null;
        auditItem.ValidationStatus = OperationalSyncMapper.Text(item.Payload, "validationStatus", "validation_status", "estado_validacion") ?? "pendiente";
        auditItem.Observation = OperationalSyncMapper.Text(item.Payload, "observation", "observacion");
        auditItem.DeletedAt = null;
        auditItem.UpdatedAt = now;
        auditItem.LastSyncedAt = now;
        auditItem.SyncStatus = "synced";
        if (auditItem.Id == default || dbContext.Entry(auditItem).State == EntityState.Detached) dbContext.AuditItems.Add(auditItem);
        await dbContext.SaveChangesAsync();
        return auditItem;
    }

    private async Task<AuditItem> DeleteAuditItemAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item)
    {
        var auditItem = await FindItemForPushAsync(businessId, item, true) ?? throw new KeyNotFoundException("Audit item no encontrado.");
        var audit = await dbContext.Audits.FirstAsync(x => x.Id == auditItem.AuditId);
        EnsureAuditAccess(user, audit);
        var now = DateTime.UtcNow;
        auditItem.DeletedAt = now;
        auditItem.UpdatedAt = now;
        auditItem.LastSyncedAt = now;
        auditItem.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return auditItem;
    }

    private async Task<Audit?> FindAuditForPushAsync(Guid businessId, OperationalSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.Audits.Where(x => x.BusinessId == businessId);
        var audit = item.ServerId is not null ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId) : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);
        if (audit == null && throwIfMissing) throw new KeyNotFoundException("Auditoria no encontrada para este negocio.");
        return audit;
    }

    private async Task<AuditItem?> FindItemForPushAsync(Guid businessId, OperationalSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.AuditItems.Where(x => x.BusinessId == businessId);
        var auditItem = item.ServerId is not null ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId) : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);
        if (auditItem == null && throwIfMissing) throw new KeyNotFoundException("Audit item no encontrado para este negocio.");
        return auditItem;
    }

    private async Task EnsureCollaboratorAsync(Guid businessId, Guid userId)
    {
        var exists = await dbContext.Users.AnyAsync(x => x.Id == userId && x.BusinessId == businessId && x.UserType == "Colaborador");
        if (!exists) throw new KeyNotFoundException("Colaborador no encontrado para este negocio.");
    }

    private static void EnsureAuditAccess(ClaimsPrincipal user, Audit audit)
    {
        if (OperationalSyncMapper.IsCollaborator(user) && audit.CollaboratorId != OperationalSyncMapper.UserId(user))
        {
            throw new UnauthorizedAccessException("El colaborador solo puede sincronizar sus auditorias.");
        }
    }

    private static AuditResponse MapAudit(Audit audit) => new()
    {
        Id = audit.Id,
        LocalId = audit.LocalId,
        RemoteId = audit.RemoteId,
        BusinessId = audit.BusinessId,
        CollaboratorId = audit.CollaboratorId,
        CollaboratorName = audit.Collaborator?.Name,
        Type = audit.Type,
        Date = audit.Date,
        Status = audit.Status,
        TotalProducts = audit.TotalProducts,
        ValidatedProducts = audit.ValidatedProducts,
        Observations = audit.Observations,
        CreatedAt = audit.CreatedAt,
        UpdatedAt = audit.UpdatedAt,
        DeletedAt = audit.DeletedAt,
        LastSyncedAt = audit.LastSyncedAt
    };

    private static AuditItemResponse MapItem(AuditItem item) => new()
    {
        Id = item.Id,
        LocalId = item.LocalId,
        RemoteId = item.RemoteId,
        BusinessId = item.BusinessId,
        AuditId = item.AuditId,
        ProductId = item.ProductId,
        SystemStock = item.SystemStock,
        PhysicalStock = item.PhysicalStock,
        ValidationStatus = item.ValidationStatus,
        Observation = item.Observation,
        CreatedAt = item.CreatedAt,
        UpdatedAt = item.UpdatedAt,
        DeletedAt = item.DeletedAt,
        LastSyncedAt = item.LastSyncedAt
    };

    private static OperationalSyncPushItemResponse Result(int localId, Guid serverId, string status, DateTime updatedAt) => new() { LocalId = localId, ServerId = serverId, Status = status, ServerUpdatedAt = updatedAt };
    private static OperationalSyncPushItemResponse Failure(OperationalSyncPushItemRequest item, string error) => new() { LocalId = item.LocalId, ServerId = item.ServerId, Status = "failed", Error = error };
}
