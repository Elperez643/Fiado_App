namespace FiadoApp.Api.Entities;

public class Subscription : BaseEntity
{
    public Guid BusinessId { get; set; }
    public string PlanId { get; set; } = "basico";
    public string PlanName { get; set; } = "Basico";
    public decimal MonthlyPrice { get; set; }
    public int MaxCollaborators { get; set; }
    public string BillingCycle { get; set; } = "mensual";
    public int DiscountPercent { get; set; }
    public decimal OriginalPrice { get; set; }
    public decimal FinalPrice { get; set; }
    public string CurrencyCode { get; set; } = "USD";
    public string Status { get; set; } = "trial";
    public DateTime TrialStartedAt { get; set; }
    public DateTime TrialEndsAt { get; set; }
    public DateTime? CurrentPeriodStartedAt { get; set; }
    public DateTime? CurrentPeriodEndsAt { get; set; }
    public bool CancelAtPeriodEnd { get; set; }
    public string? PaymentProvider { get; set; }
    public string? ProviderSubscriptionId { get; set; }
    public string? ProviderCustomerId { get; set; }

    public Business? Business { get; set; }
}
