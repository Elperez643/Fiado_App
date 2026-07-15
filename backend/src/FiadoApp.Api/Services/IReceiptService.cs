using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IReceiptService
{
    Task<IReadOnlyList<ReceiptResponse>> GetByClientAsync(ClaimsPrincipal user, Guid clientId);
    Task<ReceiptResponse> GetByIdAsync(ClaimsPrincipal user, Guid id);
    Task<ReceiptResponse> GetByCodeAsync(ClaimsPrincipal user, string code);
    Task<ReceiptSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, ReceiptSyncPushRequest request);
    Task<ReceiptSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, ReceiptSyncPullRequest request);
}
