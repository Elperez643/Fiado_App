namespace FiadoApp.Api.Payments;

public class SubscriptionPayment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid SubscriptionId { get; set; }
    public Guid BusinessId { get; set; }
    public decimal AmountUsd { get; set; }
    public decimal AmountDop { get; set; }
    public decimal ExchangeRate { get; set; }
    public string BillingCycle { get; set; } = "mensual";
    public DateTime PaymentDate { get; set; } = DateTime.UtcNow;
    public string Status { get; set; } = "pending";
    public string Provider { get; set; } = "mock";
    public string? ProviderTransactionId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
