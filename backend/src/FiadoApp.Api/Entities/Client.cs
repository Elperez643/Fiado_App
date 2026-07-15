namespace FiadoApp.Api.Entities;

public class Client : BaseEntity
{
    public Guid BusinessId { get; set; }
    public string? RemoteId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? Address { get; set; }
    public decimal Debt { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Business? Business { get; set; }
    public ICollection<Movement> Movements { get; set; } = [];
    public ICollection<CreditCycle> CreditCycles { get; set; } = [];
}
