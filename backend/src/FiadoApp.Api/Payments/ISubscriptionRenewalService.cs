using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Payments;

public interface ISubscriptionRenewalService
{
    Task<IReadOnlyList<AzulChargeResponse>> RunRenewalCheckAsync(bool forceFailure = false);
}
