namespace FiadoApp.Api.Entities;

public class CreditException : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid CreditCycleId { get; set; }
    public Guid ClientId { get; set; }
    public Guid? UserId { get; set; }
    public string? Reason { get; set; }
    public decimal Amount { get; set; }
    public Guid? MovementId { get; set; }
    public DateTime Date { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public CreditCycle? CreditCycle { get; set; }
    public Client? Client { get; set; }
    public Movement? Movement { get; set; }
}
