namespace FiadoApp.Api.Entities;

public class CreditCycle : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ClientId { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime DueDate30 { get; set; }
    public DateTime DueDate45 { get; set; }
    public DateTime Block60Date { get; set; }
    public string Status { get; set; } = "activo";
    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal PendingBalance { get; set; }
    public bool IsBlocked { get; set; }
    public DateTime? SettledAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Business? Business { get; set; }
    public Client? Client { get; set; }
    public ICollection<CreditReminder> Reminders { get; set; } = [];
}
