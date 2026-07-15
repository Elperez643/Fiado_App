namespace FiadoApp.Api.Entities;

public class Product : BaseEntity
{
    public Guid BusinessId { get; set; }
    public string? RemoteId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? CodeReference { get; set; }
    public string? Category { get; set; }
    public string? Description { get; set; }
    public int Quantity { get; set; }
    public decimal PurchasePrice { get; set; }
    public decimal SalePrice { get; set; }
    public decimal ProfitMarginPercent { get; set; }
    public int MinimumStock { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
    public string? Location { get; set; }
    public string? MeasureType { get; set; }
    public string? DemandLevel { get; set; }
    public bool IsKeyProduct { get; set; }

    public Business? Business { get; set; }
    public ICollection<ProductImage> Images { get; set; } = [];
}
