namespace FiadoApp.Api.DTOs;

public sealed class ProductResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? CodeReference { get; set; }
    public string? Category { get; set; }
    public string? Location { get; set; }
    public string? Description { get; set; }
    public int Quantity { get; set; }
    public decimal PurchasePrice { get; set; }
    public decimal SalePrice { get; set; }
    public decimal ProfitMarginPercent { get; set; }
    public int MinimumStock { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}
