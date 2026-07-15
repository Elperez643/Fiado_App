using System.Security.Claims;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class ClientService(FiadoDbContext dbContext) : IClientService
{
    public async Task<ClientResponse> CreateAsync(ClaimsPrincipal user, ClientCreateRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var phone = NormalizePhone(request.Phone);
        await EnsurePhoneIsAvailableAsync(businessId, phone, null);

        var now = DateTime.UtcNow;
        var client = new Client
        {
            BusinessId = businessId,
            Name = request.Name.Trim(),
            Phone = phone,
            Address = NormalizeOptional(request.Address),
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            LastSyncedAt = now
        };

        dbContext.Clients.Add(client);
        await dbContext.SaveChangesAsync();

        return Map(client);
    }

    public async Task<ClientResponse> UpdateAsync(ClaimsPrincipal user, Guid id, ClientUpdateRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var client = await FindClientForBusinessAsync(businessId, id);
        var phone = NormalizePhone(request.Phone);
        await EnsurePhoneIsAvailableAsync(businessId, phone, id);

        var now = DateTime.UtcNow;
        client.Name = request.Name.Trim();
        client.Phone = phone;
        client.Address = NormalizeOptional(request.Address);
        client.IsActive = request.IsActive;
        client.DeletedAt = request.IsActive ? null : now;
        client.UpdatedAt = now;
        client.LastSyncedAt = now;
        client.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return Map(client);
    }

    public async Task<ClientResponse> GetByIdAsync(ClaimsPrincipal user, Guid id)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        return Map(await FindClientForBusinessAsync(businessId, id));
    }

    public async Task<IReadOnlyList<ClientResponse>> GetByBusinessAsync(ClaimsPrincipal user)
    {
        var businessId = GetBusinessIdForBusinessUser(user);

        return await dbContext.Clients
            .AsNoTracking()
            .Where(x => x.BusinessId == businessId)
            .OrderBy(x => x.Name)
            .Select(x => Map(x))
            .ToListAsync();
    }

    public async Task<ClientSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, ClientSyncPushRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var response = new ClientSyncPushResponse { ServerTime = DateTime.UtcNow };

        foreach (var item in request.Clients)
        {
            try
            {
                var result = await ApplyPushItemAsync(businessId, item);
                response.Results.Add(result);
            }
            catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
            {
                response.Results.Add(new ClientSyncPushItemResponse
                {
                    LocalId = item.LocalId,
                    ServerId = item.ServerId,
                    Status = "failed",
                    Error = ex.Message
                });
            }
        }

        return response;
    }

    public async Task<ClientSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, ClientSyncPullRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var query = dbContext.Clients
            .AsNoTracking()
            .Where(x => x.BusinessId == businessId);

        if (request.LastSyncAt is not null)
        {
            query = query.Where(x =>
                x.UpdatedAt > request.LastSyncAt.Value ||
                (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt.Value));
        }

        var clients = await query
            .OrderBy(x => x.UpdatedAt)
            .Select(x => Map(x))
            .ToListAsync();

        return new ClientSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            Clients = clients
        };
    }

    private async Task<ClientSyncPushItemResponse> ApplyPushItemAsync(
        Guid businessId,
        ClientSyncPushItemRequest item)
    {
        var operation = item.Operation.Trim().ToLowerInvariant();

        return operation switch
        {
            "create" => await ApplyCreatePushAsync(businessId, item),
            "update" => await ApplyUpdatePushAsync(businessId, item),
            "delete" => await ApplyDeletePushAsync(businessId, item),
            _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
        };
    }

    private async Task<ClientSyncPushItemResponse> ApplyCreatePushAsync(
        Guid businessId,
        ClientSyncPushItemRequest item)
    {
        var phone = NormalizePhone(item.Phone);
        var existingByLocalId = await dbContext.Clients
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.LocalId == item.LocalId);

        if (existingByLocalId is not null)
        {
            return await UpdateClientFromPushAsync(existingByLocalId, item, "updated");
        }

        var existingByPhone = await dbContext.Clients
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Phone == phone);
        if (existingByPhone is not null)
        {
            return await UpdateClientFromPushAsync(existingByPhone, item, "updated");
        }

        var now = DateTime.UtcNow;
        var client = new Client
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            Name = item.Name.Trim(),
            Phone = phone,
            Address = NormalizeOptional(item.Address),
            IsActive = true,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt,
            UpdatedAt = now,
            LastSyncedAt = now,
            SyncStatus = "synced"
        };

        dbContext.Clients.Add(client);
        await dbContext.SaveChangesAsync();

        return BuildPushResult(item.LocalId, client.Id, "created", client.UpdatedAt);
    }

    private async Task<ClientSyncPushItemResponse> ApplyUpdatePushAsync(
        Guid businessId,
        ClientSyncPushItemRequest item)
    {
        var client = await FindClientForPushAsync(businessId, item);
        return await UpdateClientFromPushAsync(client, item, "updated");
    }

    private async Task<ClientSyncPushItemResponse> ApplyDeletePushAsync(
        Guid businessId,
        ClientSyncPushItemRequest item)
    {
        var client = await FindClientForPushAsync(businessId, item);
        var now = DateTime.UtcNow;

        client.IsActive = false;
        client.DeletedAt = now;
        client.UpdatedAt = now;
        client.LastSyncedAt = now;
        client.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return BuildPushResult(item.LocalId, client.Id, "deleted", client.UpdatedAt);
    }

    private async Task<ClientSyncPushItemResponse> UpdateClientFromPushAsync(
        Client client,
        ClientSyncPushItemRequest item,
        string status)
    {
        var phone = NormalizePhone(item.Phone);
        await EnsurePhoneIsAvailableAsync(client.BusinessId, phone, client.Id);

        var now = DateTime.UtcNow;
        client.LocalId = item.LocalId;
        client.Name = item.Name.Trim();
        client.Phone = phone;
        client.Address = NormalizeOptional(item.Address);
        client.IsActive = true;
        client.DeletedAt = null;
        client.UpdatedAt = now;
        client.LastSyncedAt = now;
        client.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return BuildPushResult(item.LocalId, client.Id, status, client.UpdatedAt);
    }

    private async Task<Client> FindClientForPushAsync(Guid businessId, ClientSyncPushItemRequest item)
    {
        var query = dbContext.Clients.Where(x => x.BusinessId == businessId);

        var client = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);

        return client ?? throw new KeyNotFoundException("Cliente no encontrado para este negocio.");
    }

    private async Task<Client> FindClientForBusinessAsync(Guid businessId, Guid id)
    {
        var client = await dbContext.Clients
            .FirstOrDefaultAsync(x => x.Id == id && x.BusinessId == businessId);

        return client ?? throw new KeyNotFoundException("Cliente no encontrado para este negocio.");
    }

    private async Task EnsurePhoneIsAvailableAsync(Guid businessId, string phone, Guid? currentClientId)
    {
        var exists = await dbContext.Clients.AnyAsync(x =>
            x.BusinessId == businessId &&
            x.Phone == phone &&
            (currentClientId == null || x.Id != currentClientId));

        if (exists)
        {
            throw new InvalidOperationException("Ya existe un cliente con ese telefono en este negocio.");
        }
    }

    private static ClientSyncPushItemResponse BuildPushResult(
        int localId,
        Guid serverId,
        string status,
        DateTime serverUpdatedAt)
    {
        return new ClientSyncPushItemResponse
        {
            LocalId = localId,
            ServerId = serverId,
            Status = status,
            ServerUpdatedAt = serverUpdatedAt
        };
    }

    private static ClientResponse Map(Client client)
    {
        return new ClientResponse
        {
            Id = client.Id,
            LocalId = client.LocalId,
            RemoteId = client.RemoteId,
            BusinessId = client.BusinessId,
            Name = client.Name,
            Phone = client.Phone,
            Address = client.Address,
            Debt = client.Debt,
            IsActive = client.IsActive,
            CreatedAt = client.CreatedAt,
            UpdatedAt = client.UpdatedAt,
            DeletedAt = client.DeletedAt,
            LastSyncedAt = client.LastSyncedAt
        };
    }

    private static Guid GetBusinessIdForBusinessUser(ClaimsPrincipal user)
    {
        var role = user.FindFirstValue(ClaimTypes.Role);
        if (string.Equals(role, "Personal", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("El usuario Personal no puede acceder a clientes de negocio.");
        }

        if (!string.Equals(role, "Negocio", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(role, "Colaborador", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("Rol no autorizado para clientes de negocio.");
        }

        var businessIdValue = user.FindFirstValue("business_id");
        if (!Guid.TryParse(businessIdValue, out var businessId))
        {
            throw new UnauthorizedAccessException("El usuario autenticado no tiene negocio asociado.");
        }

        return businessId;
    }

    private static string NormalizePhone(string phone)
    {
        return phone.Trim();
    }

    private static string? NormalizeOptional(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }
}
