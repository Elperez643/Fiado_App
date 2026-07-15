namespace FiadoApp.Api.Payments.Providers;

public sealed class MockPaymentProvider : IPaymentProvider
{
    public Task<string> CreateCustomerAsync(Guid businessId, string businessName)
        => Task.FromResult($"mock_cus_{businessId:N}");

    public Task<string> AttachPaymentMethodAsync(Guid businessId, string providerCustomerId, string mockCardLast4)
    {
        if (string.IsNullOrWhiteSpace(mockCardLast4) || mockCardLast4.Length != 4)
        {
            throw new InvalidOperationException("El metodo mock solo acepta los ultimos 4 digitos.");
        }

        return Task.FromResult($"mock_pm_{mockCardLast4}_{Guid.NewGuid():N}");
    }

    public Task<string> CreateSubscriptionAsync(Guid businessId, Guid subscriptionId, decimal amountUsd, string billingCycle)
        => Task.FromResult($"mock_sub_{subscriptionId:N}");

    public Task CancelSubscriptionAsync(Guid businessId, string providerSubscriptionId)
        => Task.CompletedTask;

    public Task<string> HandleWebhookAsync(string eventType, string payloadJson)
        => Task.FromResult($"mock_evt_{eventType}_{Guid.NewGuid():N}");
}
