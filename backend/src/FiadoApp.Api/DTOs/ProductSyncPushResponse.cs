namespace FiadoApp.Api.DTOs;

public sealed class ProductSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<ProductSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class ProductSyncPushItemResponse
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Error { get; set; }
    public DateTime? ServerUpdatedAt { get; set; }
}
