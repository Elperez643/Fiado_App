using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Payments;

public interface IPaymentService
{
    Task<IReadOnlyList<PaymentMethodResponse>> GetMethodsAsync(ClaimsPrincipal user);
    Task<PaymentMethodResponse> CreateMethodAsync(ClaimsPrincipal user, CreatePaymentMethodRequest request);
    Task<IReadOnlyList<SubscriptionPaymentResponse>> GetHistoryAsync(ClaimsPrincipal user);
    Task<SubscriptionBillingResponse> GetSubscriptionAsync(ClaimsPrincipal user);
    Task<SubscriptionPaymentResponse> MockChargeAsync(ClaimsPrincipal user);
    Task<SubscriptionPaymentResponse> MockRenewAsync(ClaimsPrincipal user);
    Task<SubscriptionPaymentResponse> MockFailAsync(ClaimsPrincipal user);
}
