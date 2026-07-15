namespace FiadoApp.Api.Payments.Providers.Azul;

public sealed record AzulCardTokenSession(
    string SessionUrl,
    bool SandboxMock,
    string Message);

public sealed record AzulTokenizedCard(
    string ProviderCustomerId,
    string ProviderPaymentMethodId,
    string Brand,
    string Last4,
    int ExpMonth,
    int ExpYear,
    bool SandboxMock);

public sealed record AzulChargeResult(
    bool Succeeded,
    string Status,
    string ProviderTransactionId,
    string ResponseJson,
    string Message);
