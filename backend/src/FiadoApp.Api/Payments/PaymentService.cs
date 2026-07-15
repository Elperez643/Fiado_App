using System.Security.Claims;
using System.Text.Json;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Payments.Providers;
using FiadoApp.Api.Services;
using FiadoApp.Api.Subscriptions;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Payments;

public sealed class PaymentService(FiadoDbContext dbContext, IPaymentProvider paymentProvider) : IPaymentService
{
    private const decimal MockExchangeRate = 59.25m;

    public async Task<IReadOnlyList<PaymentMethodResponse>> GetMethodsAsync(ClaimsPrincipal user)
    {
        var businessId = BusinessId(user);
        return await dbContext.PaymentMethods.AsNoTracking()
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.IsDefault)
            .ThenByDescending(x => x.CreatedAt)
            .Select(x => MapMethod(x))
            .ToListAsync();
    }

    public async Task<PaymentMethodResponse> CreateMethodAsync(ClaimsPrincipal user, CreatePaymentMethodRequest request)
    {
        var businessId = BusinessId(user);
        if (!string.Equals(request.Provider, "mock", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("Solo el proveedor mock esta habilitado por ahora.");
        }

        if (request.MockCardLast4 != "4242")
        {
            throw new InvalidOperationException("El mock de pago exitoso usa tarjeta terminada en 4242.");
        }

        var business = await dbContext.Businesses.AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == businessId)
            ?? throw new KeyNotFoundException("Negocio no encontrado.");
        var customerId = await paymentProvider.CreateCustomerAsync(businessId, business.Name);
        var providerMethodId = await paymentProvider.AttachPaymentMethodAsync(
            businessId,
            customerId,
            request.MockCardLast4);

        if (request.IsDefault)
        {
            await dbContext.PaymentMethods
                .Where(x => x.BusinessId == businessId && x.IsDefault)
                .ExecuteUpdateAsync(x => x.SetProperty(p => p.IsDefault, false));
        }

        var method = new PaymentMethod
        {
            BusinessId = businessId,
            Provider = "mock",
            ProviderCustomerId = customerId,
            ProviderPaymentMethodId = providerMethodId,
            Brand = string.IsNullOrWhiteSpace(request.Brand) ? "Visa" : request.Brand.Trim(),
            Last4 = request.MockCardLast4,
            ExpMonth = request.ExpMonth,
            ExpYear = request.ExpYear,
            IsDefault = request.IsDefault,
            CreatedAt = DateTime.UtcNow
        };

        dbContext.PaymentMethods.Add(method);
        await dbContext.SaveChangesAsync();
        return MapMethod(method);
    }

    public async Task<IReadOnlyList<SubscriptionPaymentResponse>> GetHistoryAsync(ClaimsPrincipal user)
    {
        var businessId = BusinessId(user);
        return await dbContext.SubscriptionPayments.AsNoTracking()
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.PaymentDate)
            .Select(x => MapPayment(x))
            .ToListAsync();
    }

    public async Task<SubscriptionBillingResponse> GetSubscriptionAsync(ClaimsPrincipal user)
    {
        var businessId = BusinessId(user);
        var subscription = await CurrentSubscriptionAsync(businessId);
        var defaultMethod = await dbContext.PaymentMethods.AsNoTracking()
            .Where(x => x.BusinessId == businessId && x.IsDefault)
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => MapMethod(x))
            .FirstOrDefaultAsync();

        if (subscription is null)
        {
            return new SubscriptionBillingResponse(
                null,
                "Sin plan",
                "mensual",
                "missing",
                0,
                0,
                MockExchangeRate,
                0,
                null,
                null,
                defaultMethod);
        }

        var catalogPrice = CatalogPriceOrNull(subscription.PlanId, subscription.BillingCycle);
        var amountUsd = catalogPrice?.PriceUsd ?? subscription.FinalPrice;
        return new SubscriptionBillingResponse(
            subscription.Id,
            catalogPrice?.PlanName ?? subscription.PlanName,
            catalogPrice?.BillingCycle ?? subscription.BillingCycle,
            subscription.Status,
            amountUsd,
            decimal.Round(amountUsd * MockExchangeRate, 2),
            MockExchangeRate,
            TrialDaysLeft(subscription.TrialEndsAt),
            subscription.TrialEndsAt,
            subscription.CurrentPeriodEndsAt ?? subscription.TrialEndsAt,
            defaultMethod);
    }

    public Task<SubscriptionPaymentResponse> MockChargeAsync(ClaimsPrincipal user)
        => CreateMockPaymentAsync(user, "paid", "mock_charge");

    public Task<SubscriptionPaymentResponse> MockRenewAsync(ClaimsPrincipal user)
        => CreateMockPaymentAsync(user, "renewed", "mock_renewal");

    public Task<SubscriptionPaymentResponse> MockFailAsync(ClaimsPrincipal user)
        => CreateMockPaymentAsync(user, "failed", "mock_failure");

    private async Task<SubscriptionPaymentResponse> CreateMockPaymentAsync(
        ClaimsPrincipal user,
        string paymentStatus,
        string operation)
    {
        var businessId = BusinessId(user);
        var subscription = await CurrentSubscriptionAsync(businessId)
            ?? throw new InvalidOperationException("No hay suscripcion local para cobrar.");
        var defaultMethod = await dbContext.PaymentMethods.AsNoTracking()
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.IsDefault);
        if (defaultMethod is null)
        {
            throw new InvalidOperationException("Agrega un metodo de pago mock antes de simular cobros.");
        }

        var now = DateTime.UtcNow;
        var catalogPrice = CatalogPriceOrNull(subscription.PlanId, subscription.BillingCycle);
        var amountUsd = catalogPrice?.PriceUsd ?? subscription.FinalPrice;
        var payment = new SubscriptionPayment
        {
            SubscriptionId = subscription.Id,
            BusinessId = businessId,
            AmountUsd = amountUsd,
            AmountDop = decimal.Round(amountUsd * MockExchangeRate, 2),
            ExchangeRate = MockExchangeRate,
            BillingCycle = subscription.BillingCycle,
            PaymentDate = now,
            Status = paymentStatus,
            Provider = "mock",
            ProviderTransactionId = $"mock_tx_{Guid.NewGuid():N}",
            CreatedAt = now
        };

        dbContext.SubscriptionPayments.Add(payment);
        dbContext.PaymentTransactions.Add(new PaymentTransaction
        {
            PaymentId = payment.Id,
            Provider = "mock",
            RequestJson = JsonSerializer.Serialize(new { operation, subscription.Id, businessId }),
            ResponseJson = JsonSerializer.Serialize(new { status = paymentStatus, payment.ProviderTransactionId }),
            Status = paymentStatus,
            CreatedAt = now
        });

        if (paymentStatus is "paid" or "renewed")
        {
            subscription.Status = "active";
            subscription.PaymentProvider = "mock";
            if (catalogPrice is not null)
            {
                ApplyCatalogPrice(subscription, catalogPrice);
            }
            subscription.ProviderSubscriptionId ??= await paymentProvider.CreateSubscriptionAsync(
                businessId,
                subscription.Id,
                amountUsd,
                subscription.BillingCycle);
            subscription.CurrentPeriodStartedAt = now;
            subscription.CurrentPeriodEndsAt = now.AddDays(PeriodDays(subscription.BillingCycle));
            subscription.UpdatedAt = now;
            subscription.SyncStatus = "synced";
        }

        await dbContext.SaveChangesAsync();
        return MapPayment(payment);
    }

    private Task<Entities.Subscription?> CurrentSubscriptionAsync(Guid businessId)
        => dbContext.Subscriptions
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();

    private static int PeriodDays(string billingCycle) => billingCycle switch
    {
        "trimestral" => 90,
        "anual" => 365,
        _ => 30
    };

    private static int TrialDaysLeft(DateTime trialEndsAt)
    {
        var days = (trialEndsAt.Date - DateTime.UtcNow.Date).Days;
        return days < 0 ? 0 : days;
    }

    private static Guid BusinessId(ClaimsPrincipal user)
        => FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "pagos");

    private static SubscriptionPlanPrice? CatalogPriceOrNull(string planId, string billingCycle)
    {
        try
        {
            return SubscriptionPlanCatalog.PriceFor(planId, billingCycle);
        }
        catch (InvalidOperationException)
        {
            return null;
        }
    }

    private static void ApplyCatalogPrice(Entities.Subscription subscription, SubscriptionPlanPrice price)
    {
        var months = price.BillingCycle switch
        {
            "trimestral" => 3,
            "anual" => 12,
            _ => 1
        };
        subscription.PlanId = price.PlanId;
        subscription.PlanName = price.PlanName;
        subscription.MonthlyPrice = price.OriginalMonthlyUsd;
        subscription.MaxCollaborators = price.CollaboratorsLimit;
        subscription.BillingCycle = price.BillingCycle;
        subscription.DiscountPercent = price.DiscountPercent;
        subscription.OriginalPrice = Math.Floor(price.OriginalMonthlyUsd * months * 100m) / 100m;
        subscription.FinalPrice = price.PriceUsd;
        subscription.CurrencyCode = SubscriptionPlanCatalog.CurrencyCode;
    }

    private static PaymentMethodResponse MapMethod(PaymentMethod method) => new(
        method.Id,
        method.BusinessId,
        method.Provider,
        method.ProviderCustomerId,
        method.ProviderPaymentMethodId,
        method.Brand,
        method.Last4,
        method.ExpMonth,
        method.ExpYear,
        method.IsDefault,
        method.CreatedAt);

    private static SubscriptionPaymentResponse MapPayment(SubscriptionPayment payment) => new(
        payment.Id,
        payment.SubscriptionId,
        payment.BusinessId,
        payment.AmountUsd,
        payment.AmountDop,
        payment.ExchangeRate,
        payment.BillingCycle,
        payment.PaymentDate,
        payment.Status,
        payment.Provider,
        payment.ProviderTransactionId);
}
