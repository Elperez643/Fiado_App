namespace FiadoApp.Api.DTOs;

public sealed class ProductSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<ProductResponse> Products { get; set; } = [];
}
