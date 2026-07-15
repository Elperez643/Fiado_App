namespace FiadoApp.Api.Payments;

public class PaymentWebhookLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Provider { get; set; } = "mock";
    public string EventType { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = "{}";
    public bool Processed { get; set; }
    public DateTime? ProcessedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
