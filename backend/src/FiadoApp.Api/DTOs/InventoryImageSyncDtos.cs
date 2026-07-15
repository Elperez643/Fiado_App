namespace FiadoApp.Api.DTOs;

public sealed class InventoryImagePushRequest
{
    public List<InventoryImageMetadataDto> Images { get; set; } = [];
    public List<LegacyInventoryImageChangeDto> Changes { get; set; } = [];
}

public sealed class LegacyInventoryImageChangeDto
{
    public InventoryImageMetadataDto Payload { get; set; } = new();
}

public sealed class InventoryImagePushResponse
{
    public int Accepted { get; set; }
    public int Rejected { get; set; }
    public DateTime ServerTime { get; set; } = DateTime.UtcNow;
    public List<string> Errors { get; set; } = [];
}

public sealed class InventoryImagePullRequest
{
    public DateTime? Since { get; set; }
    public int Limit { get; set; } = 25;
    public List<string> ProductUuids { get; set; } = [];
    public string? ProductUuid { get; set; }
    public bool OnlyMissingContent { get; set; }
    public bool Content { get; set; }
}

public sealed class InventoryImagePullResponse
{
    public DateTime ServerTime { get; set; } = DateTime.UtcNow;
    public List<InventoryImageMetadataDto> Images { get; set; } = [];
    public bool HasMore { get; set; }
}

public sealed class InventoryImageMetadataDto
{
    public string Uuid { get; set; } = string.Empty;
    public string ProductUuid { get; set; } = string.Empty;
    public Guid? ServerId { get; set; }
    public Guid? BusinessId { get; set; }
    public string? FileName { get; set; }
    public string? MimeType { get; set; }
    public long SizeBytes { get; set; }
    public string? ContentHash { get; set; }
    public int? Width { get; set; }
    public int? Height { get; set; }
    public bool IsCover { get; set; }
    public int SortOrder { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public bool HasContent { get; set; }
    public string? ContentBase64 { get; set; }
}

public sealed class InventoryImageContentPushRequest
{
    public string ImageUuid { get; set; } = string.Empty;
    public string? ProductUuid { get; set; }
    public string ContentBase64 { get; set; } = string.Empty;
    public string? ContentHash { get; set; }
    public string? MimeType { get; set; }
    public long SizeBytes { get; set; }
}

public sealed class InventoryImageContentResponse
{
    public string ImageUuid { get; set; } = string.Empty;
    public string? ProductUuid { get; set; }
    public string? ContentBase64 { get; set; }
    public string? ContentHash { get; set; }
    public string? MimeType { get; set; }
    public long SizeBytes { get; set; }
}
