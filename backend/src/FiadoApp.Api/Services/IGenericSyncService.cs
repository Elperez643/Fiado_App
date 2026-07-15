using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IGenericSyncService
{
    Task<GenericSyncPushResponse> PushAsync(
        ClaimsPrincipal user,
        string module,
        GenericSyncPushRequest request);

    Task<GenericSyncPullResponse> PullAsync(
        ClaimsPrincipal user,
        string module,
        GenericSyncPullRequest request);
}
