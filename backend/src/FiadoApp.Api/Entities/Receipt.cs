namespace FiadoApp.Api.Entities;

public class Receipt : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid MovementId { get; set; }
    public Guid ClientId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string ClientName { get; set; } = string.Empty;
    public string? ClientPhone { get; set; }
    public string? BusinessName { get; set; }
    public string ReceiptCode { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public decimal Subtotal { get; set; }
    public decimal Total { get; set; }
    public decimal? PreviousBalance { get; set; }
    public decimal? NewBalance { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public string PayloadJson { get; set; } = "{}";
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Movement? Movement { get; set; }
    public Client? Client { get; set; }
}
