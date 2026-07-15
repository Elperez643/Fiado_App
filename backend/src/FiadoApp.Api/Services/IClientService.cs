using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IClientService
{
    Task<ClientResponse> CreateAsync(ClaimsPrincipal user, ClientCreateRequest request);
    Task<ClientResponse> UpdateAsync(ClaimsPrincipal user, Guid id, ClientUpdateRequest request);
    Task<ClientResponse> GetByIdAsync(ClaimsPrincipal user, Guid id);
    Task<IReadOnlyList<ClientResponse>> GetByBusinessAsync(ClaimsPrincipal user);
    Task<ClientSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, ClientSyncPushRequest request);
    Task<ClientSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, ClientSyncPullRequest request);
}
