namespace FiadoApp.Api.DTOs;

public sealed class ProductImageSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<ProductImageResponse> Images { get; set; } = [];
}
