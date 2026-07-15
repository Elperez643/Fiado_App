using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace FiadoApp.Api.DTOs;

public class AuditCreateRequest
{
    public Guid? CollaboratorId { get; set; }
    [Required] public string Type { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public string Status { get; set; } = "pendiente";
    public int TotalProducts { get; set; }
    public int ValidatedProducts { get; set; }
    public string? Observations { get; set; }
}

public sealed class AuditUpdateRequest : AuditCreateRequest
{
    public bool IsDeleted { get; set; }
}

public sealed class AuditResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid? CollaboratorId { get; set; }
    public string? CollaboratorName { get; set; }
    public string Type { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public string Status { get; set; } = string.Empty;
    public int TotalProducts { get; set; }
    public int ValidatedProducts { get; set; }
    public string? Observations { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class AuditItemCreateRequest
{
    public Guid AuditId { get; set; }
    public Guid ProductId { get; set; }
    public int SystemStock { get; set; }
    public int? PhysicalStock { get; set; }
    public string ValidationStatus { get; set; } = "pendiente";
    public string? Observation { get; set; }
}

public sealed class AuditItemResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid AuditId { get; set; }
    public Guid ProductId { get; set; }
    public int SystemStock { get; set; }
    public int? PhysicalStock { get; set; }
    public string ValidationStatus { get; set; } = string.Empty;
    public string? Observation { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class AuditSyncPushRequest { public List<OperationalSyncPushItemRequest> Audits { get; set; } = []; }
public sealed class AuditSyncPushResponse { public DateTime ServerTime { get; set; } public List<OperationalSyncPushItemResponse> Results { get; set; } = []; }
public sealed class AuditSyncPullRequest { public DateTime? LastSyncAt { get; set; } }
public sealed class AuditSyncPullResponse { public DateTime ServerTime { get; set; } public List<AuditResponse> Audits { get; set; } = []; }
public sealed class AuditItemSyncPushRequest { public List<OperationalSyncPushItemRequest> AuditItems { get; set; } = []; }
public sealed class AuditItemSyncPushResponse { public DateTime ServerTime { get; set; } public List<OperationalSyncPushItemResponse> Results { get; set; } = []; }
public sealed class AuditItemSyncPullRequest { public DateTime? LastSyncAt { get; set; } }
public sealed class AuditItemSyncPullResponse { public DateTime ServerTime { get; set; } public List<AuditItemResponse> AuditItems { get; set; } = []; }

public sealed class AuditReportResponse
{
    public Guid AuditId { get; set; }
    public string? Collaborator { get; set; }
    public DateTime Date { get; set; }
    public string Type { get; set; } = string.Empty;
    public int ProductsReviewed { get; set; }
    public int DifferencesFound { get; set; }
    public string? Observations { get; set; }
}

public sealed class AuthorizationRequestCreateRequest
{
    public Guid? CollaboratorId { get; set; }
    [Required] public string RequestType { get; set; } = string.Empty;
    [Required] public string Entity { get; set; } = string.Empty;
    public Guid? EntityId { get; set; }
    public string? DataBeforeJson { get; set; }
    public string DataAfterJson { get; set; } = "{}";
}

public sealed class AuthorizationRequestResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid CollaboratorId { get; set; }
    public string? CollaboratorName { get; set; }
    public string RequestType { get; set; } = string.Empty;
    public string Entity { get; set; } = string.Empty;
    public Guid? EntityId { get; set; }
    public string? DataBeforeJson { get; set; }
    public string DataAfterJson { get; set; } = "{}";
    public string Status { get; set; } = string.Empty;
    public string? BusinessComment { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DecidedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class AuthorizationRequestDecisionRequest { public string? Comment { get; set; } }
public sealed class AuthorizationRequestSyncPushRequest { public List<OperationalSyncPushItemRequest> AuthorizationRequests { get; set; } = []; }
public sealed class AuthorizationRequestSyncPushResponse { public DateTime ServerTime { get; set; } public List<OperationalSyncPushItemResponse> Results { get; set; } = []; }
public sealed class AuthorizationRequestSyncPullRequest { public DateTime? LastSyncAt { get; set; } }
public sealed class AuthorizationRequestSyncPullResponse { public DateTime ServerTime { get; set; } public List<AuthorizationRequestResponse> AuthorizationRequests { get; set; } = []; }

public sealed class OperationalSyncPushItemRequest
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    [Required] public string Operation { get; set; } = "create";
    public Dictionary<string, JsonElement> Payload { get; set; } = [];
    public DateTime UpdatedAt { get; set; }
}

public sealed class OperationalSyncPushItemResponse
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Error { get; set; }
    public DateTime? ServerUpdatedAt { get; set; }
}
