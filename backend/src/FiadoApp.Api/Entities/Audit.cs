namespace FiadoApp.Api.Entities;

public class Audit : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid? CollaboratorId { get; set; }
    public string Type { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public string Status { get; set; } = "pendiente";
    public int TotalProducts { get; set; }
    public int ValidatedProducts { get; set; }
    public string? Observations { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Business? Business { get; set; }
    public User? Collaborator { get; set; }
    public ICollection<AuditItem> Items { get; set; } = [];
}
