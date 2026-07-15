using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class ProductSyncPushRequest
{
    [Required]
    public List<ProductSyncPushItemRequest> Products { get; set; } = [];
}

public sealed class ProductSyncPushItemRequest
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }

    [Required]
    [MaxLength(180)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(80)]
    public string? CodeReference { get; set; }

    [MaxLength(120)]
    public string? Category { get; set; }

    [MaxLength(160)]
    public string? Location { get; set; }

    public string? Description { get; set; }
    public int Quantity { get; set; }
    public decimal PurchasePrice { get; set; }
    public decimal SalePrice { get; set; }
    public decimal ProfitMarginPercent { get; set; }
    public int MinimumStock { get; set; }

    [Required]
    public string Operation { get; set; } = "create";

    public DateTime UpdatedAt { get; set; }
}
