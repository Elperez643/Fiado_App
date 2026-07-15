namespace FiadoApp.Api.DTOs;

public sealed class GenericSyncPushRequest
{
    public string? DeviceId { get; set; }
    public List<GenericSyncChangeRequest> Changes { get; set; } = [];
}

public sealed class GenericSyncChangeRequest
{
    public string Uuid { get; set; } = string.Empty;
    public string? BusinessId { get; set; }
    public string EntityType { get; set; } = string.Empty;
    public string EntityUuid { get; set; } = string.Empty;
    public string Operation { get; set; } = string.Empty;
    public object? Payload { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public sealed class GenericSyncPushResponse
{
    public string Module { get; set; } = string.Empty;
    public int Accepted { get; set; }
    public int Rejected { get; set; }
    public DateTime ServerTime { get; set; }
    public List<string> Errors { get; set; } = [];
}

public sealed class GenericSyncPullRequest
{
    public string? DeviceId { get; set; }
    public DateTime? LastPullAt { get; set; }
}

public sealed class GenericSyncPullResponse
{
    public string Module { get; set; } = string.Empty;
    public List<object> Changes { get; set; } = [];
    public DateTime ServerTime { get; set; }
    public bool HasMore { get; set; }
}
