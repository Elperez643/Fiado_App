namespace FiadoApp.Api.Payments;

public class PaymentMethod
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid BusinessId { get; set; }
    public string Provider { get; set; } = "mock";
    public string ProviderCustomerId { get; set; } = string.Empty;
    public string ProviderPaymentMethodId { get; set; } = string.Empty;
    public string Brand { get; set; } = "Visa";
    public string Last4 { get; set; } = "4242";
    public int ExpMonth { get; set; }
    public int ExpYear { get; set; }
    public bool IsDefault { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
