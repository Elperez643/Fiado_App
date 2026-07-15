namespace FiadoApp.Api.Entities;

public class Business : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public Guid OwnerUserId { get; set; }
    public string? Phone { get; set; }
    public bool HasUsedTrial { get; set; }
    public DateTime? TrialStartedAt { get; set; }
    public DateTime? TrialEndsAt { get; set; }
    public string SubscriptionStatus { get; set; } = "registration_incomplete";
    public string? StripeCustomerId { get; set; }
    public string CurrentPlan { get; set; } = "basico";
    public string CurrentBillingCycle { get; set; } = "mensual";
    public bool PaymentMethodRequired { get; set; } = true;

    public User? OwnerUser { get; set; }
    public ICollection<User> Members { get; set; } = [];
    public ICollection<Client> Clients { get; set; } = [];
    public ICollection<Product> Products { get; set; } = [];
    public ICollection<CreditCycle> CreditCycles { get; set; } = [];
    public ICollection<AuthorizationRequest> AuthorizationRequests { get; set; } = [];
}
