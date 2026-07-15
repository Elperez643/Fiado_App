using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class ProductImageCreateRequest
{
    [Required]
    public Guid ProductId { get; set; }

    [Required]
    [MaxLength(1024)]
    public string LocalPath { get; set; } = string.Empty;

    [MaxLength(2048)]
    public string? RemoteUrl { get; set; }

    [MaxLength(512)]
    public string? StorageKey { get; set; }

    public int Order { get; set; }
    public string? MimeType { get; set; }
    public long SizeBytes { get; set; }
    public int? Width { get; set; }
    public int? Height { get; set; }
}
