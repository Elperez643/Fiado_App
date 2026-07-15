using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IAuditService
{
    Task<IReadOnlyList<AuditResponse>> GetAuditsAsync(ClaimsPrincipal user);
    Task<AuditResponse> GetByIdAsync(ClaimsPrincipal user, Guid id);
    Task<IReadOnlyList<AuditReportResponse>> GetBusinessReportAsync(ClaimsPrincipal user);
    Task<IReadOnlyList<AuditResponse>> GetMyAuditsAsync(ClaimsPrincipal user);
    Task<AuditSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, AuditSyncPushRequest request);
    Task<AuditSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, AuditSyncPullRequest request);
    Task<AuditItemSyncPushResponse> PushItemsSyncAsync(ClaimsPrincipal user, AuditItemSyncPushRequest request);
    Task<AuditItemSyncPullResponse> PullItemsSyncAsync(ClaimsPrincipal user, AuditItemSyncPullRequest request);
}
