using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Payments.Providers.Azul;

public interface IAzulPaymentService
{
    Task<AzulCardTokenSessionResponse> CreateCardTokenSessionAsync(
        ClaimsPrincipal user,
        CreateAzulCardTokenSessionRequest request);

    Task<PaymentMethodResponse> ConfirmCardTokenAsync(
        ClaimsPrincipal user,
        ConfirmAzulCardTokenRequest request);

    Task<SubscriptionStatusResponse> ActivateTrialAsync(
        ClaimsPrincipal user,
        ActivateTrialRequest request);

    Task<AzulChargeResponse> ChargeSubscriptionAsync(
        ClaimsPrincipal user,
        ChargeAzulSubscriptionRequest request);

    Task<AzulChargeResponse> ChargeSubscriptionForRenewalAsync(
        Guid businessId,
        Guid subscriptionId,
        bool forceFailure = false);

    Task<string> HandleWebhookAsync(string payloadJson, string signature);
}
