namespace FiadoApp.Api.DTOs;

public sealed class ProductImageResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ProductId { get; set; }
    public string LocalPath { get; set; } = string.Empty;
    public string? RemoteUrl { get; set; }
    public string? StorageKey { get; set; }
    public int Order { get; set; }
    public string? MimeType { get; set; }
    public long SizeBytes { get; set; }
    public int? Width { get; set; }
    public int? Height { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}
