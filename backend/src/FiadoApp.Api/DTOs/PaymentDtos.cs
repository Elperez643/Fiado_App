namespace FiadoApp.Api.DTOs;

public sealed record CreatePaymentMethodRequest(
    string Provider = "mock",
    string MockCardLast4 = "4242",
    string Brand = "Visa",
    int ExpMonth = 12,
    int ExpYear = 2030,
    bool IsDefault = true);

public sealed record PaymentMethodResponse(
    Guid Id,
    Guid BusinessId,
    string Provider,
    string ProviderCustomerId,
    string ProviderPaymentMethodId,
    string Brand,
    string Last4,
    int ExpMonth,
    int ExpYear,
    bool IsDefault,
    DateTime CreatedAt);

public sealed record SubscriptionPaymentResponse(
    Guid Id,
    Guid SubscriptionId,
    Guid BusinessId,
    decimal AmountUsd,
    decimal AmountDop,
    decimal ExchangeRate,
    string BillingCycle,
    DateTime PaymentDate,
    string Status,
    string Provider,
    string? ProviderTransactionId);

public sealed record PaymentTransactionResponse(
    Guid Id,
    Guid PaymentId,
    string Provider,
    string RequestJson,
    string ResponseJson,
    string Status,
    DateTime CreatedAt);

public sealed record SubscriptionBillingResponse(
    Guid? SubscriptionId,
    string Plan,
    string BillingCycle,
    string Status,
    decimal AmountUsd,
    decimal AmountDop,
    decimal ExchangeRate,
    int TrialDaysLeft,
    DateTime? TrialEndsAt,
    DateTime? NextRenewalAt,
    PaymentMethodResponse? DefaultPaymentMethod);

public sealed record CreateStripeCheckoutSessionRequest(
    string PlanId,
    string BillingCycle);

public sealed record ActivateTrialRequest(
    string PlanId,
    string BillingCycle);

public sealed record StripeCheckoutSessionResponse(
    string CheckoutUrl,
    string Provider,
    string Mode,
    string PlanId,
    string BillingCycle);

public sealed record CreateAzulCardTokenSessionRequest(
    string PlanId,
    string BillingCycle);

public sealed record AzulCardTokenSessionResponse(
    string SessionUrl,
    string Provider,
    string Mode,
    string PlanId,
    string BillingCycle,
    bool SandboxMock,
    string Message);

public sealed record ConfirmAzulCardTokenRequest(
    string ProviderPaymentMethodId = "",
    string Brand = "Visa",
    string Last4 = "4242",
    int ExpMonth = 12,
    int ExpYear = 2030,
    bool IsDefault = true);

public sealed record ChargeAzulSubscriptionRequest(
    Guid? SubscriptionId = null,
    bool ForceFailure = false);

public sealed record AzulChargeResponse(
    Guid? PaymentId,
    string Provider,
    string Status,
    string ProviderTransactionId,
    string Message);

public sealed record SubscriptionStatusResponse(
    string Status,
    string Plan,
    string BillingCycle,
    DateTime? TrialEndsAt,
    bool IsUsableOffline,
    DateTime? GraceEndsAt,
    bool PaymentMethodRequired,
    bool HasUsedTrial);
