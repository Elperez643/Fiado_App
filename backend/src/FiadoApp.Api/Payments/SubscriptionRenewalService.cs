using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Payments.Providers.Azul;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Payments;

public sealed class SubscriptionRenewalService(
    FiadoDbContext dbContext,
    IAzulPaymentService azulPaymentService,
    IConfiguration configuration) : ISubscriptionRenewalService
{
    public async Task<IReadOnlyList<AzulChargeResponse>> RunRenewalCheckAsync(bool forceFailure = false)
    {
        var provider = configuration["Payments:Provider"]?.Trim();
        if (!string.Equals(provider, "Azul", StringComparison.OrdinalIgnoreCase))
        {
            return [];
        }

        var now = DateTime.UtcNow;
        var dueTrials = await dbContext.Subscriptions.AsNoTracking()
            .Where(x =>
                x.Status == "trial_active" &&
                x.TrialEndsAt <= now &&
                x.PaymentProvider == "Azul")
            .OrderBy(x => x.TrialEndsAt)
            .Take(100)
            .Select(x => new { x.BusinessId, x.Id })
            .ToListAsync();

        var results = new List<AzulChargeResponse>();
        foreach (var trial in dueTrials)
        {
            results.Add(await azulPaymentService.ChargeSubscriptionForRenewalAsync(
                trial.BusinessId,
                trial.Id,
                forceFailure));
        }

        return results;
    }
}
