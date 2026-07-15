namespace FiadoApp.Api.Entities;

public class Movement : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ClientId { get; set; }
    public Guid? PersonalUserId { get; set; }
    public string ClientName { get; set; } = string.Empty;
    public string? ClientPhone { get; set; }
    public string Type { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? Concept { get; set; }
    public DateTime Date { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Business? Business { get; set; }
    public Client? Client { get; set; }
    public ICollection<DebtItem> DebtItems { get; set; } = [];
    public ICollection<Receipt> Receipts { get; set; } = [];
}
