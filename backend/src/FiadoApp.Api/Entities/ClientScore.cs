namespace FiadoApp.Api.Entities;

public class ClientScore : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ClientId { get; set; }
    public int Score { get; set; }
    public string RiskLevel { get; set; } = string.Empty;
    public decimal SuggestedCreditLimit { get; set; }
    public decimal PaymentCompliancePercent { get; set; }
    public decimal TotalCredits { get; set; }
    public decimal TotalPayments { get; set; }
    public int Overdue30Count { get; set; }
    public int Overdue45Count { get; set; }
    public int Blocked60Count { get; set; }
    public DateTime LastCalculatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Business? Business { get; set; }
    public Client? Client { get; set; }
}
