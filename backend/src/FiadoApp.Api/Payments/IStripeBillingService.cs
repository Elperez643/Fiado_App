using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Payments;

public interface IStripeBillingService
{
    Task<StripeCheckoutSessionResponse> CreateCheckoutSessionAsync(
        ClaimsPrincipal user,
        CreateStripeCheckoutSessionRequest request);

    Task<StripeCheckoutSessionResponse> CreateSetupSessionAsync(
        ClaimsPrincipal user,
        CreateStripeCheckoutSessionRequest request);

    Task<SubscriptionStatusResponse> ActivateTrialAsync(
        ClaimsPrincipal user,
        ActivateTrialRequest request);

    Task<SubscriptionStatusResponse> GetStatusAsync(ClaimsPrincipal user);

    Task<string> HandleWebhookAsync(string payloadJson, string stripeSignature);
}
