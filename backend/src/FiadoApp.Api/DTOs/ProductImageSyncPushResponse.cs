namespace FiadoApp.Api.DTOs;

public sealed class ProductImageSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<ProductImageSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class ProductImageSyncPushItemResponse
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public Guid? ProductServerId { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Error { get; set; }
    public DateTime? ServerUpdatedAt { get; set; }
}
