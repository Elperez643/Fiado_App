namespace FiadoApp.Api.Payments;

public class PaymentTransaction
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PaymentId { get; set; }
    public string Provider { get; set; } = "mock";
    public string RequestJson { get; set; } = "{}";
    public string ResponseJson { get; set; } = "{}";
    public string Status { get; set; } = "pending";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
