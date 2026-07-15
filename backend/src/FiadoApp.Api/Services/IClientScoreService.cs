using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IClientScoreService
{
    Task<ClientScoreResponse?> GetByClientAsync(ClaimsPrincipal user, Guid clientId);
    Task<IReadOnlyList<ClientScoreResponse>> GetByBusinessAsync(ClaimsPrincipal user);
    Task<ClientScoreSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, ClientScoreSyncPushRequest request);
    Task<ClientScoreSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, ClientScoreSyncPullRequest request);
    Task<IReadOnlyList<ClientScoreResponse>> GetTopClientsAsync(ClaimsPrincipal user, int take = 10);
    Task<IReadOnlyList<ClientScoreResponse>> GetRiskClientsAsync(ClaimsPrincipal user, int take = 10);
}
