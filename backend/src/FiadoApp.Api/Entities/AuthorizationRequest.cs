namespace FiadoApp.Api.Entities;

public class AuthorizationRequest : BaseEntity
{
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid CollaboratorId { get; set; }
    public string RequestType { get; set; } = string.Empty;
    public string Entity { get; set; } = string.Empty;
    public Guid? EntityId { get; set; }
    public string? DataBeforeJson { get; set; }
    public string DataAfterJson { get; set; } = "{}";
    public string Status { get; set; } = "pendiente";
    public string? BusinessComment { get; set; }
    public Guid? ApprovedByUserId { get; set; }
    public DateTime? DecidedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    public Business? Business { get; set; }
    public User? Collaborator { get; set; }
    public User? ApprovedByUser { get; set; }
}
