namespace FiadoApp.Api.Entities;

public class AuditItem : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid AuditId { get; set; }
    public Guid ProductId { get; set; }
    public int SystemStock { get; set; }
    public int? PhysicalStock { get; set; }
    public string ValidationStatus { get; set; } = "pendiente";
    public string? Observation { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Audit? Audit { get; set; }
    public Product? Product { get; set; }
}
