namespace FiadoApp.Api.DTOs;

public sealed class ClientResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? Address { get; set; }
    public decimal Debt { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}
