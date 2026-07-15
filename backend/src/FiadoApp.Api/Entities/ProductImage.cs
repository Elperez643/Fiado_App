namespace FiadoApp.Api.Entities;

public class ProductImage : BaseEntity
{
    public Guid BusinessId { get; set; }
    public Guid ProductId { get; set; }
    public string? RemoteId { get; set; }
    public string? ProductRemoteId { get; set; }
    public string LocalPath { get; set; } = string.Empty;
    public string? RemoteUrl { get; set; }
    public string? StorageKey { get; set; }
    public string? FileName { get; set; }
    public string? ContentHash { get; set; }
    public string? ContentBase64 { get; set; }
    public bool HasContent { get; set; }
    public int Order { get; set; }
    public string? MimeType { get; set; }
    public long SizeBytes { get; set; }
    public int? Width { get; set; }
    public int? Height { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Product? Product { get; set; }
}
