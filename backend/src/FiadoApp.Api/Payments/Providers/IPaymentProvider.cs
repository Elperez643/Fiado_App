namespace FiadoApp.Api.Payments.Providers;

public interface IPaymentProvider
{
    Task<string> CreateCustomerAsync(Guid businessId, string businessName);
    Task<string> AttachPaymentMethodAsync(Guid businessId, string providerCustomerId, string mockCardLast4);
    Task<string> CreateSubscriptionAsync(Guid businessId, Guid subscriptionId, decimal amountUsd, string billingCycle);
    Task CancelSubscriptionAsync(Guid businessId, string providerSubscriptionId);
    Task<string> HandleWebhookAsync(string eventType, string payloadJson);
}
