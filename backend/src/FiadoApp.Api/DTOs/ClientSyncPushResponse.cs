namespace FiadoApp.Api.DTOs;

public sealed class ClientSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<ClientSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class ClientSyncPushItemResponse
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Error { get; set; }
    public DateTime? ServerUpdatedAt { get; set; }
}
