using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IMovementService
{
    Task<IReadOnlyList<MovementResponse>> GetByClientAsync(ClaimsPrincipal user, Guid clientId);
    Task<MovementResponse> CreateAsync(ClaimsPrincipal user, MovementCreateRequest request);
    Task<MovementResponse> UpdateAsync(ClaimsPrincipal user, Guid id, MovementUpdateRequest request);
    Task<MovementSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, MovementSyncPushRequest request);
    Task<MovementSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, MovementSyncPullRequest request);
    Task<IReadOnlyList<DebtItemResponse>> GetDebtItemsByMovementAsync(ClaimsPrincipal user, Guid movementId);
    Task<DebtItemSyncPushResponse> PushDebtItemsSyncAsync(ClaimsPrincipal user, DebtItemSyncPushRequest request);
    Task<DebtItemSyncPullResponse> PullDebtItemsSyncAsync(ClaimsPrincipal user, DebtItemSyncPullRequest request);
}
