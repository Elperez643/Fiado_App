using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface ICreditCycleService
{
    Task<IReadOnlyList<CreditCycleResponse>> GetByClientAsync(ClaimsPrincipal user, Guid clientId);
    Task<IReadOnlyList<CreditCycleResponse>> GetAccountsReceivableAsync(ClaimsPrincipal user);
    Task<IReadOnlyList<CreditCycleResponse>> GetOverdue45Async(ClaimsPrincipal user);
    Task<IReadOnlyList<CreditCycleResponse>> GetBlocked60Async(ClaimsPrincipal user);
    Task<CreditCycleSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, CreditCycleSyncPushRequest request);
    Task<CreditCycleSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, CreditCycleSyncPullRequest request);
}
