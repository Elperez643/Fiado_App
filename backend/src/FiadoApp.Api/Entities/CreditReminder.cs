namespace FiadoApp.Api.Entities;

public class CreditReminder : BaseEntity
{
    public Guid CreditCycleId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ClientId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string Channel { get; set; } = string.Empty;
    public string Status { get; set; } = "pendiente";
    public DateTime GeneratedAt { get; set; }
    public DateTime? SentAt { get; set; }

    public CreditCycle? CreditCycle { get; set; }
}
