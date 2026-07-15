using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace FiadoApp.Api.DTOs;

public sealed class WhatsappCampaignResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public string LocalUuid { get; set; } = string.Empty;
    public string DateKey { get; set; } = string.Empty;
    public string Mode { get; set; } = "catalogo";
    public List<string> ProductIds { get; set; } = [];
    public List<string> RenderedImagePaths { get; set; } = [];
    public List<string> StatusTexts { get; set; } = [];
    public string Status { get; set; } = "pendiente";
    public string CampaignStatus { get; set; } = "activo";
    public bool ConsumesQuota { get; set; }
    public int QuotaUnits { get; set; } = 1;
    public DateTime StartDate { get; set; }
    public int DurationDays { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? OpenedWhatsappAt { get; set; }
    public DateTime? ConfirmedByUserAt { get; set; }
    public DateTime? CanceledByUserAt { get; set; }
    public DateTime? FailedAt { get; set; }
    public DateTime? EstimatedExpiresAt { get; set; }
    public string? Error { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class WhatsappCampaignSyncPushRequest
{
    public List<WhatsappCampaignSyncPushItemRequest> Campaigns { get; set; } = [];
}

public sealed class WhatsappCampaignSyncPushItemRequest
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    [Required]
    public string Operation { get; set; } = "create";
    public Dictionary<string, JsonElement> Payload { get; set; } = [];
    public DateTime UpdatedAt { get; set; }
}

public sealed class WhatsappCampaignSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<WhatsappCampaignSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class WhatsappCampaignSyncPushItemResponse
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Error { get; set; }
    public DateTime? ServerUpdatedAt { get; set; }
}

public sealed class WhatsappCampaignSyncPullRequest
{
    public DateTime? LastSyncAt { get; set; }
}

public sealed class WhatsappCampaignSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<WhatsappCampaignResponse> Campaigns { get; set; } = [];
}
