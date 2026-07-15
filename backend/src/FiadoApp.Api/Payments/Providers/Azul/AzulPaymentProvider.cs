using System.Text.Json;
using FiadoApp.Api.Payments.Providers;
using Microsoft.Extensions.Options;

namespace FiadoApp.Api.Payments.Providers.Azul;

public sealed class AzulPaymentProvider(IOptions<AzulPaymentOptions> options) : IAzulPaymentProvider, IPaymentProvider
{
    private readonly AzulPaymentOptions _options = options.Value;

    public Task<AzulCardTokenSession> CreateCardTokenSessionAsync(
        Guid businessId,
        string businessName,
        string planId,
        string billingCycle)
    {
        if (!_options.HasRealCredentials)
        {
            return Task.FromResult(new AzulCardTokenSession(
                $"azul-sandbox-mock://tokenize?businessId={businessId}&plan={planId}&cycle={billingCycle}",
                SandboxMock: true,
                "AzulSandboxMock activo: pendiente credenciales reales Azul."));
        }

        throw new NotSupportedException("Integracion real Azul pendiente de credenciales y contrato API.");
    }

    public Task<AzulTokenizedCard> ConfirmCardTokenAsync(
        Guid businessId,
        string businessName,
        string providerPaymentMethodId,
        string brand,
        string last4,
        int expMonth,
        int expYear)
    {
        if (!_options.HasRealCredentials)
        {
            var safeLast4 = NormalizeLast4(last4);
            return Task.FromResult(new AzulTokenizedCard(
                $"azul_mock_customer_{businessId:N}",
                string.IsNullOrWhiteSpace(providerPaymentMethodId)
                    ? $"azul_mock_token_{safeLast4}_{Guid.NewGuid():N}"
                    : providerPaymentMethodId.Trim(),
                string.IsNullOrWhiteSpace(brand) ? "Visa" : brand.Trim(),
                safeLast4,
                expMonth <= 0 ? 12 : expMonth,
                expYear <= 0 ? DateTime.UtcNow.Year + 4 : expYear,
                SandboxMock: true));
        }

        throw new NotSupportedException("Tokenizacion real Azul pendiente de credenciales y contrato API.");
    }

    public Task<AzulChargeResult> ChargeSubscriptionAsync(
        Guid businessId,
        Guid subscriptionId,
        string providerCustomerId,
        string providerPaymentMethodId,
        decimal amountUsd,
        string billingCycle,
        bool forceFailure = false)
    {
        if (!_options.HasRealCredentials)
        {
            var succeeded = !forceFailure && !providerPaymentMethodId.Contains("fail", StringComparison.OrdinalIgnoreCase);
            var transactionId = $"azul_mock_tx_{Guid.NewGuid():N}";
            var response = JsonSerializer.Serialize(new
            {
                provider = "Azul",
                sandboxMock = true,
                transactionId,
                status = succeeded ? "paid" : "failed",
                businessId,
                subscriptionId,
                amountUsd,
                billingCycle
            });
            return Task.FromResult(new AzulChargeResult(
                succeeded,
                succeeded ? "paid" : "failed",
                transactionId,
                response,
                succeeded
                    ? "Cobro AzulSandboxMock aprobado."
                    : "Cobro AzulSandboxMock rechazado."));
        }

        throw new NotSupportedException("Cobro real Azul pendiente de credenciales y contrato API.");
    }

    public Task<string> HandleWebhookAsync(string payloadJson, string signature)
    {
        if (!_options.HasRealCredentials)
        {
            return Task.FromResult("azul.sandbox_mock.webhook_received");
        }

        if (string.IsNullOrWhiteSpace(_options.WebhookSecret))
        {
            throw new InvalidOperationException("Azul WebhookSecret no esta configurado.");
        }

        throw new NotSupportedException("Webhook real Azul pendiente de credenciales y contrato API.");
    }

    public Task<string> CreateCustomerAsync(Guid businessId, string businessName)
        => Task.FromResult($"azul_customer_{businessId:N}");

    public Task<string> AttachPaymentMethodAsync(Guid businessId, string providerCustomerId, string mockCardLast4)
        => Task.FromResult($"azul_mock_token_{NormalizeLast4(mockCardLast4)}_{Guid.NewGuid():N}");

    public Task<string> CreateSubscriptionAsync(Guid businessId, Guid subscriptionId, decimal amountUsd, string billingCycle)
        => Task.FromResult($"azul_subscription_{subscriptionId:N}");

    public Task CancelSubscriptionAsync(Guid businessId, string providerSubscriptionId)
        => Task.CompletedTask;

    Task<string> IPaymentProvider.HandleWebhookAsync(string eventType, string payloadJson)
        => Task.FromResult(eventType);

    private static string NormalizeLast4(string last4)
    {
        var digits = new string((last4 ?? string.Empty).Where(char.IsDigit).ToArray());
        return digits.Length == 4 ? digits : "4242";
    }
}
