using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace FiadoApp.Api.DTOs;

public class MovementCreateRequest
{
    [Required]
    public Guid ClientId { get; set; }
    [Required]
    public string Type { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? Concept { get; set; }
    public DateTime Date { get; set; }
}

public sealed class MovementUpdateRequest : MovementCreateRequest
{
    public bool IsActive { get; set; } = true;
}

public sealed class MovementResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ClientId { get; set; }
    public string ClientName { get; set; } = string.Empty;
    public string? ClientPhone { get; set; }
    public string Type { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? Concept { get; set; }
    public DateTime Date { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class MovementSyncPushRequest
{
    public List<FinancialSyncPushItemRequest> Movements { get; set; } = [];
}

public sealed class MovementSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<FinancialSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class MovementSyncPullRequest
{
    public DateTime? LastSyncAt { get; set; }
}

public sealed class MovementSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<MovementResponse> Movements { get; set; } = [];
}

public sealed class DebtItemCreateRequest
{
    [Required]
    public Guid MovementId { get; set; }
    public Guid? ProductId { get; set; }
    [Required]
    public string ProductName { get; set; } = string.Empty;
    public string? CodeReference { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Subtotal { get; set; }
}

public sealed class DebtItemResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid MovementId { get; set; }
    public Guid? ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string? CodeReference { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Subtotal { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class DebtItemSyncPushRequest
{
    public List<FinancialSyncPushItemRequest> DebtItems { get; set; } = [];
}

public sealed class DebtItemSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<FinancialSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class DebtItemSyncPullRequest
{
    public DateTime? LastSyncAt { get; set; }
}

public sealed class DebtItemSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<DebtItemResponse> DebtItems { get; set; } = [];
}

public sealed class ReceiptCreateRequest
{
    [Required]
    public Guid MovementId { get; set; }
    [Required]
    public Guid ClientId { get; set; }
    [Required]
    public string ReceiptCode { get; set; } = string.Empty;
    [Required]
    public string Type { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = "{}";
    public decimal Total { get; set; }
    public decimal? PreviousBalance { get; set; }
    public decimal? NewBalance { get; set; }
    public DateTime Date { get; set; }
}

public sealed class ReceiptResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid MovementId { get; set; }
    public Guid ClientId { get; set; }
    public string ReceiptCode { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string ClientName { get; set; } = string.Empty;
    public string? ClientPhone { get; set; }
    public string? BusinessName { get; set; }
    public string PayloadJson { get; set; } = "{}";
    public decimal Total { get; set; }
    public decimal? PreviousBalance { get; set; }
    public decimal? NewBalance { get; set; }
    public DateTime Date { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class ReceiptSyncPushRequest
{
    public List<FinancialSyncPushItemRequest> Receipts { get; set; } = [];
}

public sealed class ReceiptSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<FinancialSyncPushItemResponse> Results { get; set; } = [];
}

public sealed class ReceiptSyncPullRequest
{
    public DateTime? LastSyncAt { get; set; }
}

public sealed class ReceiptSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<ReceiptResponse> Receipts { get; set; } = [];
}

public sealed class CreditCycleResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid ClientId { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime DueDate30 { get; set; }
    public DateTime DueDate45 { get; set; }
    public DateTime BlockDate60 { get; set; }
    public string Status { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal PendingBalance { get; set; }
    public bool IsBlocked { get; set; }
    public DateTime? SettledAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class CreditCycleSyncPushRequest
{
    public List<FinancialSyncPushItemRequest> CreditCycles { get; set; } = [];
    public List<FinancialSyncPushItemRequest> CreditReminders { get; set; } = [];
    public List<FinancialSyncPushItemRequest> CreditExceptions { get; set; } = [];
}

public sealed class CreditCycleSyncPushResponse
{
    public DateTime ServerTime { get; set; }
    public List<FinancialSyncPushItemResponse> Results { get; set; } = [];
    public List<FinancialSyncPushItemResponse> CreditReminderResults { get; set; } = [];
    public List<FinancialSyncPushItemResponse> CreditExceptionResults { get; set; } = [];
}

public sealed class CreditCycleSyncPullRequest
{
    public DateTime? LastSyncAt { get; set; }
}

public sealed class CreditCycleSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<CreditCycleResponse> CreditCycles { get; set; } = [];
    public List<CreditReminderResponse> CreditReminders { get; set; } = [];
    public List<CreditExceptionResponse> CreditExceptions { get; set; } = [];
}

public sealed class CreditReminderResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid CreditCycleId { get; set; }
    public Guid ClientId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string Channel { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime GeneratedAt { get; set; }
    public DateTime? SentAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public sealed class CreditExceptionResponse
{
    public Guid Id { get; set; }
    public int? LocalId { get; set; }
    public string? RemoteId { get; set; }
    public Guid BusinessId { get; set; }
    public Guid CreditCycleId { get; set; }
    public Guid ClientId { get; set; }
    public Guid? UserId { get; set; }
    public string? Reason { get; set; }
    public decimal Amount { get; set; }
    public Guid? MovementId { get; set; }
    public DateTime Date { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }
}

public sealed class FinancialSyncPushItemRequest
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    [Required]
    public string Operation { get; set; } = "create";
    public Dictionary<string, JsonElement> Payload { get; set; } = [];
    public DateTime UpdatedAt { get; set; }
}

public sealed class FinancialSyncPushItemResponse
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Error { get; set; }
    public DateTime? ServerUpdatedAt { get; set; }
}
