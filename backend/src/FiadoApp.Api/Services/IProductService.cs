using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IProductService
{
    Task<ProductResponse> CreateAsync(ClaimsPrincipal user, ProductCreateRequest request);
    Task<ProductResponse> UpdateAsync(ClaimsPrincipal user, Guid id, ProductUpdateRequest request);
    Task<ProductResponse> GetByIdAsync(ClaimsPrincipal user, Guid id);
    Task<IReadOnlyList<ProductResponse>> GetByBusinessAsync(ClaimsPrincipal user);
    Task<ProductSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, ProductSyncPushRequest request);
    Task<ProductSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, ProductSyncPullRequest request);
    Task<IReadOnlyList<ProductImageResponse>> GetImagesByProductAsync(ClaimsPrincipal user, Guid productId);
    Task<ProductImageSyncPushResponse> PushImagesSyncAsync(ClaimsPrincipal user, ProductImageSyncPushRequest request);
    Task<ProductImageSyncPullResponse> PullImagesSyncAsync(ClaimsPrincipal user, ProductImageSyncPullRequest request);
}
