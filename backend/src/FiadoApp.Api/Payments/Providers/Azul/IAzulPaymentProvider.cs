namespace FiadoApp.Api.Payments.Providers.Azul;

public interface IAzulPaymentProvider
{
    Task<AzulCardTokenSession> CreateCardTokenSessionAsync(
        Guid businessId,
        string businessName,
        string planId,
        string billingCycle);

    Task<AzulTokenizedCard> ConfirmCardTokenAsync(
        Guid businessId,
        string businessName,
        string providerPaymentMethodId,
        string brand,
        string last4,
        int expMonth,
        int expYear);

    Task<AzulChargeResult> ChargeSubscriptionAsync(
        Guid businessId,
        Guid subscriptionId,
        string providerCustomerId,
        string providerPaymentMethodId,
        decimal amountUsd,
        string billingCycle,
        bool forceFailure = false);

    Task<string> HandleWebhookAsync(string payloadJson, string signature);
}
