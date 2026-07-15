using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IAuthorizationRequestService
{
    Task<IReadOnlyList<AuthorizationRequestResponse>> GetPendingAsync(ClaimsPrincipal user);
    Task<IReadOnlyList<AuthorizationRequestResponse>> GetMyAsync(ClaimsPrincipal user);
    Task<AuthorizationRequestSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, AuthorizationRequestSyncPushRequest request);
    Task<AuthorizationRequestSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, AuthorizationRequestSyncPullRequest request);
    Task<AuthorizationRequestResponse> ApproveAsync(ClaimsPrincipal user, Guid id, AuthorizationRequestDecisionRequest request);
    Task<AuthorizationRequestResponse> RejectAsync(ClaimsPrincipal user, Guid id, AuthorizationRequestDecisionRequest request);
}
