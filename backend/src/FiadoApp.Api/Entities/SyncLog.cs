namespace FiadoApp.Api.Entities;

public class SyncLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string? DeviceId { get; set; }
    public string EntityType { get; set; } = string.Empty;
    public string Operation { get; set; } = string.Empty;
    public Guid? RemoteId { get; set; }
    public int? LocalEntityId { get; set; }
    public string PayloadJson { get; set; } = "{}";
    public string Status { get; set; } = "pending";
    public int Attempts { get; set; }
    public string? LastError { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
