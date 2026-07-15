namespace FiadoApp.Api.Entities;

public class WhatsappCampaignPublication : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public string LocalUuid { get; set; } = string.Empty;
    public string DateKey { get; set; } = string.Empty;
    public string Mode { get; set; } = "catalogo";
    public string ProductIdsJson { get; set; } = "[]";
    public string RenderedImagePathsJson { get; set; } = "[]";
    public string StatusTextsJson { get; set; } = "[]";
    public string Status { get; set; } = "pendiente";
    public string CampaignStatus { get; set; } = "activo";
    public bool ConsumesQuota { get; set; }
    public int QuotaUnits { get; set; } = 1;
    public DateTime StartDate { get; set; } = DateTime.UtcNow;
    public int DurationDays { get; set; } = 7;
    public DateTime? OpenedWhatsappAt { get; set; }
    public DateTime? ConfirmedByUserAt { get; set; }
    public DateTime? CanceledByUserAt { get; set; }
    public DateTime? FailedAt { get; set; }
    public DateTime? EstimatedExpiresAt { get; set; }
    public string? Error { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Business? Business { get; set; }
}
