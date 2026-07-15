namespace FiadoApp.Api.Payments.Providers;

public interface IStripePaymentProvider : IPaymentProvider
{
    Task<string> CreateCheckoutSessionAsync(
        Guid businessId,
        Guid subscriptionId,
        string businessName,
        string providerCustomerId,
        string priceId,
        string planId,
        string billingCycle);

    Task<string> CreateSetupSessionAsync(
        Guid businessId,
        string businessName,
        string providerCustomerId,
        string planId,
        string billingCycle);

    Task<StripeSavedPaymentMethod> GetPaymentMethodAsync(string providerPaymentMethodId);

    Task<string> CreateTrialSubscriptionAsync(
        Guid businessId,
        Guid subscriptionId,
        string providerCustomerId,
        string providerPaymentMethodId,
        string priceId,
        string planId,
        string billingCycle);

    string ValidateAndExtractEventType(string payloadJson, string stripeSignature);
}

public sealed record StripeSavedPaymentMethod(
    string Id,
    string Brand,
    string Last4,
    int ExpMonth,
    int ExpYear);
