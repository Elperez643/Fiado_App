using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace FiadoApp.Api.DTOs;

public sealed class ClientScoreResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ClientId { get; set; }
    public string ClientName { get; set; } = string.Empty;
    public string ClientPhone { get; set; } = string.Empty;
    public int Score { get; set; }
    public string RiskLevel { get; set; } = string.Empty;
    public decimal SuggestedCreditLimit { get; set; }
    public decimal PaymentCompliancePercent { get; set; }
    public decimal TotalCredits { get; set; }
    public decimal TotalPayments { get; set; }
    public int Overdue30Count { get; set; }
    public int Overdue45Count { get; set; }
    public int Blocked60Count { get; set; }
    public DateTime LastCalculatedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class ClientScoreSyncPushRequest
{
    public List<ClientScoreSyncPushItemRequest> ClientScores { get; set; } = [];
}

public sealed class ClientScoreSyncPushItemRequest
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    [Required]
    public string Operation { get; set; } = "create";
    public Dictionary<string, JsonElement> Payload { get; set; } = [];
    public DateTime UpdatedAt { get; set; }
}

public sealed class ClientScoreSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<ClientScoreSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class ClientScoreSyncPushItemResponse
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Error { get; set; }
    public DateTime? ServerUpdatedAt { get; set; }
}

public sealed class ClientScoreSyncPullRequest
{
    public DateTime? LastSyncAt { get; set; }
}

public sealed class ClientScoreSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<ClientScoreResponse> ClientScores { get; set; } = [];
}
