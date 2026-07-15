using System.Security.Claims;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class AuthorizationRequestService(FiadoDbContext dbContext) : IAuthorizationRequestService
{
    public async Task<IReadOnlyList<AuthorizationRequestResponse>> GetPendingAsync(ClaimsPrincipal user)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "solicitudes de autorizacion");
        var query = BaseQuery(businessId, user).Where(x => x.Status == "pendiente" && x.DeletedAt == null);
        return await query.OrderByDescending(x => x.CreatedAt).Select(x => Map(x)).ToListAsync();
    }

    public async Task<IReadOnlyList<AuthorizationRequestResponse>> GetMyAsync(ClaimsPrincipal user)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "solicitudes de autorizacion");
        var userId = OperationalSyncMapper.UserId(user);
        var query = dbContext.AuthorizationRequests.AsNoTracking()
            .Include(x => x.Collaborator)
            .Where(x => x.BusinessId == businessId);

        if (OperationalSyncMapper.IsCollaborator(user))
        {
            query = query.Where(x => x.CollaboratorId == userId);
        }

        return await query.OrderByDescending(x => x.CreatedAt).Select(x => Map(x)).ToListAsync();
    }

    public async Task<AuthorizationRequestSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, AuthorizationRequestSyncPushRequest request)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "solicitudes de autorizacion");
        var response = new AuthorizationRequestSyncPushResponse { ServerTime = DateTime.UtcNow };

        foreach (var item in request.AuthorizationRequests)
        {
            response.Results.Add(await TryApplyAsync(businessId, user, item));
        }

        return response;
    }

    public async Task<AuthorizationRequestSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, AuthorizationRequestSyncPullRequest request)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "solicitudes de autorizacion");
        var query = BaseQuery(businessId, user);

        if (request.LastSyncAt is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.LastSyncAt || (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt));
        }

        return new AuthorizationRequestSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            AuthorizationRequests = await query.OrderBy(x => x.UpdatedAt).Select(x => Map(x)).ToListAsync()
        };
    }

    public Task<AuthorizationRequestResponse> ApproveAsync(ClaimsPrincipal user, Guid id, AuthorizationRequestDecisionRequest request)
        => DecideAsync(user, id, request, "aprobada");

    public Task<AuthorizationRequestResponse> RejectAsync(ClaimsPrincipal user, Guid id, AuthorizationRequestDecisionRequest request)
        => DecideAsync(user, id, request, "rechazada");

    private IQueryable<AuthorizationRequest> BaseQuery(Guid businessId, ClaimsPrincipal user)
    {
        var query = dbContext.AuthorizationRequests.AsNoTracking()
            .Include(x => x.Collaborator)
            .Where(x => x.BusinessId == businessId);

        if (OperationalSyncMapper.IsCollaborator(user))
        {
            var userId = OperationalSyncMapper.UserId(user);
            query = query.Where(x => x.CollaboratorId == userId);
        }

        return query;
    }

    private async Task<OperationalSyncPushItemResponse> TryApplyAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item)
    {
        try
        {
            var request = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertAsync(businessId, user, item, true),
                "update" => await UpsertAsync(businessId, user, item, false),
                "delete" => await DeleteAsync(businessId, user, item),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };

            return Result(item.LocalId, request.Id, item.Operation == "delete" ? "deleted" : item.Operation == "create" ? "created" : "updated", request.UpdatedAt);
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException or UnauthorizedAccessException)
        {
            return Failure(item, ex.Message);
        }
    }

    private async Task<AuthorizationRequest> UpsertAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item, bool allowCreate)
    {
        var request = await FindForPushAsync(businessId, item, !allowCreate);
        var now = DateTime.UtcNow;
        var collaboratorId = OperationalSyncMapper.GuidValue(item.Payload, "collaboratorId", "collaborator_id", "colaborador_id");

        if (OperationalSyncMapper.IsCollaborator(user))
        {
            collaboratorId = OperationalSyncMapper.UserId(user);
        }

        if (collaboratorId is null)
        {
            throw new InvalidOperationException("La solicitud requiere colaborador.");
        }

        await EnsureCollaboratorAsync(businessId, collaboratorId.Value);
        request ??= new AuthorizationRequest
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            CollaboratorId = collaboratorId.Value,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        EnsureAccess(user, request);
        request.CollaboratorId = collaboratorId.Value;
        request.RequestType = OperationalSyncMapper.Text(item.Payload, "requestType", "request_type", "tipo_solicitud") ?? request.RequestType;
        request.Entity = OperationalSyncMapper.Text(item.Payload, "entity", "entidad", "entityName") ?? request.Entity;
        request.EntityId = OperationalSyncMapper.GuidValue(item.Payload, "entityId", "entity_id", "entidad_id");
        request.DataBeforeJson = OperationalSyncMapper.Text(item.Payload, "dataBeforeJson", "beforeDataJson", "data_before_json", "datos_antes");
        request.DataAfterJson = OperationalSyncMapper.Text(item.Payload, "dataAfterJson", "afterDataJson", "data_after_json", "datos_despues") ?? request.DataAfterJson;
        request.Status = OperationalSyncMapper.Text(item.Payload, "status", "estado") ?? request.Status;
        request.BusinessComment = OperationalSyncMapper.Text(item.Payload, "businessComment", "business_comment", "comentario_negocio");
        request.DecidedAt = OperationalSyncMapper.DateValue(item.Payload, request.DecidedAt ?? default, "decidedAt", "decided_at", "resolvedAt", "resolved_at");
        if (request.DecidedAt == default) request.DecidedAt = null;
        request.DeletedAt = null;
        request.UpdatedAt = now;
        request.LastSyncedAt = now;
        request.SyncStatus = "synced";

        if (request.Id == default || dbContext.Entry(request).State == EntityState.Detached)
        {
            dbContext.AuthorizationRequests.Add(request);
        }

        await dbContext.SaveChangesAsync();
        return request;
    }

    private async Task<AuthorizationRequest> DeleteAsync(Guid businessId, ClaimsPrincipal user, OperationalSyncPushItemRequest item)
    {
        var request = await FindForPushAsync(businessId, item, true) ?? throw new KeyNotFoundException("Solicitud no encontrada.");
        EnsureAccess(user, request);
        var now = DateTime.UtcNow;
        request.DeletedAt = now;
        request.UpdatedAt = now;
        request.LastSyncedAt = now;
        request.SyncStatus = "synced";
        await dbContext.SaveChangesAsync();
        return request;
    }

    private async Task<AuthorizationRequestResponse> DecideAsync(ClaimsPrincipal user, Guid id, AuthorizationRequestDecisionRequest request, string status)
    {
        var businessId = OperationalSyncMapper.BusinessId(user, "solicitudes de autorizacion");
        if (!OperationalSyncMapper.IsBusiness(user))
        {
            throw new UnauthorizedAccessException("Solo el negocio puede aprobar o rechazar solicitudes.");
        }

        var entity = await dbContext.AuthorizationRequests.Include(x => x.Collaborator)
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == id && x.DeletedAt == null)
            ?? throw new KeyNotFoundException("Solicitud no encontrada para este negocio.");

        var now = DateTime.UtcNow;
        entity.Status = status;
        entity.BusinessComment = request.Comment;
        entity.ApprovedByUserId = OperationalSyncMapper.UserId(user);
        entity.DecidedAt = now;
        entity.UpdatedAt = now;
        entity.LastSyncedAt = now;
        entity.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return Map(entity);
    }

    private async Task<AuthorizationRequest?> FindForPushAsync(Guid businessId, OperationalSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.AuthorizationRequests.Where(x => x.BusinessId == businessId);
        var request = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);

        if (request == null && throwIfMissing)
        {
            throw new KeyNotFoundException("Solicitud no encontrada para este negocio.");
        }

        return request;
    }

    private async Task EnsureCollaboratorAsync(Guid businessId, Guid userId)
    {
        var exists = await dbContext.Users.AnyAsync(x => x.Id == userId && x.BusinessId == businessId && x.UserType == "Colaborador");
        if (!exists)
        {
            throw new KeyNotFoundException("Colaborador no encontrado para este negocio.");
        }
    }

    private static void EnsureAccess(ClaimsPrincipal user, AuthorizationRequest request)
    {
        if (OperationalSyncMapper.IsCollaborator(user) && request.CollaboratorId != OperationalSyncMapper.UserId(user))
        {
            throw new UnauthorizedAccessException("El colaborador solo puede sincronizar sus solicitudes.");
        }
    }

    private static AuthorizationRequestResponse Map(AuthorizationRequest request) => new()
    {
        Id = request.Id,
        LocalId = request.LocalId,
        RemoteId = request.RemoteId,
        BusinessId = request.BusinessId,
        CollaboratorId = request.CollaboratorId,
        CollaboratorName = request.Collaborator?.Name,
        RequestType = request.RequestType,
        Entity = request.Entity,
        EntityId = request.EntityId,
        DataBeforeJson = request.DataBeforeJson,
        DataAfterJson = request.DataAfterJson,
        Status = request.Status,
        BusinessComment = request.BusinessComment,
        CreatedAt = request.CreatedAt,
        UpdatedAt = request.UpdatedAt,
        DecidedAt = request.DecidedAt,
        DeletedAt = request.DeletedAt,
        LastSyncedAt = request.LastSyncedAt
    };

    private static OperationalSyncPushItemResponse Result(int localId, Guid serverId, string status, DateTime updatedAt) => new() { LocalId = localId, ServerId = serverId, Status = status, ServerUpdatedAt = updatedAt };
    private static OperationalSyncPushItemResponse Failure(OperationalSyncPushItemRequest item, string error) => new() { LocalId = item.LocalId, ServerId = item.ServerId, Status = "failed", Error = error };
}
