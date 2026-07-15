using System.Security.Claims;
using System.Text.Json;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using FiadoApp.Api.Services;
using FiadoApp.Api.Subscriptions;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Payments.Providers.Azul;

public sealed class AzulPaymentService(
    FiadoDbContext dbContext,
    IAzulPaymentProvider azulProvider) : IAzulPaymentService
{
    private const decimal ExchangeRate = 59.25m;

    public async Task<AzulCardTokenSessionResponse> CreateCardTokenSessionAsync(
        ClaimsPrincipal user,
        CreateAzulCardTokenSessionRequest request)
    {
        var businessId = BusinessId(user);
        var billingCycle = SubscriptionPlanCatalog.NormalizeBillingCycle(request.BillingCycle);
        var plan = SubscriptionPlanCatalog.PriceFor(request.PlanId, billingCycle);
        var business = await BusinessAsync(businessId);

        business.CurrentPlan = plan.PlanId;
        business.CurrentBillingCycle = billingCycle;
        business.SubscriptionStatus = "payment_method_required";
        business.PaymentMethodRequired = true;
        business.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        var session = await azulProvider.CreateCardTokenSessionAsync(
            businessId,
            business.Name,
            plan.PlanId,
            billingCycle);

        return new AzulCardTokenSessionResponse(
            session.SessionUrl,
            "Azul",
            "card_token",
            plan.PlanId,
            billingCycle,
            session.SandboxMock,
            session.Message);
    }

    public async Task<PaymentMethodResponse> ConfirmCardTokenAsync(
        ClaimsPrincipal user,
        ConfirmAzulCardTokenRequest request)
    {
        var businessId = BusinessId(user);
        var business = await BusinessAsync(businessId);
        var card = await azulProvider.ConfirmCardTokenAsync(
            businessId,
            business.Name,
            request.ProviderPaymentMethodId,
            request.Brand,
            request.Last4,
            request.ExpMonth,
            request.ExpYear);

        if (request.IsDefault)
        {
            await dbContext.PaymentMethods
                .Where(x => x.BusinessId == businessId && x.IsDefault)
                .ExecuteUpdateAsync(x => x.SetProperty(p => p.IsDefault, false));
        }

        var method = new PaymentMethod
        {
            BusinessId = businessId,
            Provider = "Azul",
            ProviderCustomerId = card.ProviderCustomerId,
            ProviderPaymentMethodId = card.ProviderPaymentMethodId,
            Brand = card.Brand,
            Last4 = card.Last4,
            ExpMonth = card.ExpMonth,
            ExpYear = card.ExpYear,
            IsDefault = request.IsDefault,
            CreatedAt = DateTime.UtcNow
        };

        dbContext.PaymentMethods.Add(method);
        business.PaymentMethodRequired = false;
        business.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();
        return MapMethod(method);
    }

    public async Task<SubscriptionStatusResponse> ActivateTrialAsync(
        ClaimsPrincipal user,
        ActivateTrialRequest request)
    {
        var businessId = BusinessId(user);
        var billingCycle = SubscriptionPlanCatalog.NormalizeBillingCycle(request.BillingCycle);
        var plan = SubscriptionPlanCatalog.PriceFor(request.PlanId, billingCycle);
        var business = await BusinessAsync(businessId);

        if (business.HasUsedTrial)
        {
            throw new InvalidOperationException("Este negocio ya utilizo su periodo de prueba.");
        }

        var paymentMethod = await SavedPaymentMethodAsync(businessId)
            ?? throw new InvalidOperationException("Agrega una tarjeta para activar tu prueba gratis de 30 dias.");

        var now = DateTime.UtcNow;
        var subscription = await CurrentSubscriptionAsync(businessId);
        if (subscription is null)
        {
            subscription = new Subscription { BusinessId = businessId };
            dbContext.Subscriptions.Add(subscription);
        }

        ApplyPlan(subscription, plan, billingCycle);
        subscription.Status = "trial_active";
        subscription.TrialStartedAt = now;
        subscription.TrialEndsAt = now.AddDays(30);
        subscription.CurrentPeriodStartedAt = now;
        subscription.CurrentPeriodEndsAt = now.AddDays(30);
        subscription.PaymentProvider = "Azul";
        subscription.ProviderCustomerId = paymentMethod.ProviderCustomerId;
        subscription.ProviderSubscriptionId ??= $"azul_trial_{subscription.Id:N}";
        subscription.UpdatedAt = now;
        subscription.SyncStatus = "synced";

        business.HasUsedTrial = true;
        business.TrialStartedAt = subscription.TrialStartedAt;
        business.TrialEndsAt = subscription.TrialEndsAt;
        business.SubscriptionStatus = "trial_active";
        business.PaymentMethodRequired = false;
        business.CurrentPlan = plan.PlanId;
        business.CurrentBillingCycle = billingCycle;
        business.UpdatedAt = now;

        await dbContext.SaveChangesAsync();
        return MapStatus(business, subscription);
    }

    public async Task<AzulChargeResponse> ChargeSubscriptionAsync(
        ClaimsPrincipal user,
        ChargeAzulSubscriptionRequest request)
    {
        var businessId = BusinessId(user);
        var subscription = request.SubscriptionId is null
            ? await CurrentSubscriptionAsync(businessId)
            : await dbContext.Subscriptions.FirstOrDefaultAsync(x =>
                x.Id == request.SubscriptionId && x.BusinessId == businessId);
        if (subscription is null)
        {
            throw new InvalidOperationException("No hay suscripcion para cobrar.");
        }

        return await ChargeSubscriptionCoreAsync(businessId, subscription, request.ForceFailure);
    }

    public async Task<AzulChargeResponse> ChargeSubscriptionForRenewalAsync(
        Guid businessId,
        Guid subscriptionId,
        bool forceFailure = false)
    {
        var subscription = await dbContext.Subscriptions
            .FirstOrDefaultAsync(x => x.Id == subscriptionId && x.BusinessId == businessId)
            ?? throw new InvalidOperationException("No hay suscripcion para renovar.");
        return await ChargeSubscriptionCoreAsync(businessId, subscription, forceFailure);
    }

    public Task<string> HandleWebhookAsync(string payloadJson, string signature)
        => azulProvider.HandleWebhookAsync(payloadJson, signature);

    private async Task<AzulChargeResponse> ChargeSubscriptionCoreAsync(
        Guid businessId,
        Subscription subscription,
        bool forceFailure)
    {
        var paymentMethod = await SavedPaymentMethodAsync(businessId)
            ?? throw new InvalidOperationException("No hay metodo de pago Azul guardado.");
        var catalogPrice = SubscriptionPlanCatalog.PriceFor(subscription.PlanId, subscription.BillingCycle);
        var charge = await azulProvider.ChargeSubscriptionAsync(
            businessId,
            subscription.Id,
            paymentMethod.ProviderCustomerId,
            paymentMethod.ProviderPaymentMethodId,
            catalogPrice.PriceUsd,
            subscription.BillingCycle,
            forceFailure);

        var payment = new SubscriptionPayment
        {
            SubscriptionId = subscription.Id,
            BusinessId = businessId,
            AmountUsd = catalogPrice.PriceUsd,
            AmountDop = decimal.Round(catalogPrice.PriceUsd * ExchangeRate, 2),
            ExchangeRate = ExchangeRate,
            BillingCycle = subscription.BillingCycle,
            PaymentDate = DateTime.UtcNow,
            Status = charge.Status,
            Provider = "Azul",
            ProviderTransactionId = charge.ProviderTransactionId,
            CreatedAt = DateTime.UtcNow
        };
        dbContext.SubscriptionPayments.Add(payment);
        dbContext.PaymentTransactions.Add(new PaymentTransaction
        {
            PaymentId = payment.Id,
            Provider = "Azul",
            RequestJson = JsonSerializer.Serialize(new
            {
                businessId,
                subscription.Id,
                paymentMethod.ProviderPaymentMethodId,
                catalogPrice.PriceUsd,
                subscription.BillingCycle
            }),
            ResponseJson = charge.ResponseJson,
            Status = charge.Status,
            CreatedAt = DateTime.UtcNow
        });

        subscription.Status = charge.Succeeded ? "active" : "past_due";
        subscription.CurrentPeriodStartedAt = DateTime.UtcNow;
        subscription.CurrentPeriodEndsAt = charge.Succeeded
            ? DateTime.UtcNow.AddDays(PeriodDays(subscription.BillingCycle))
            : subscription.CurrentPeriodEndsAt;
        subscription.UpdatedAt = DateTime.UtcNow;
        subscription.SyncStatus = "synced";

        var business = await BusinessAsync(businessId);
        business.SubscriptionStatus = subscription.Status;
        business.PaymentMethodRequired = false;
        business.UpdatedAt = DateTime.UtcNow;

        await dbContext.SaveChangesAsync();
        return new AzulChargeResponse(
            payment.Id,
            "Azul",
            charge.Status,
            charge.ProviderTransactionId,
            charge.Message);
    }

    private async Task<Business> BusinessAsync(Guid businessId)
        => await dbContext.Businesses.FirstOrDefaultAsync(x => x.Id == businessId)
           ?? throw new KeyNotFoundException("Negocio no encontrado.");

    private Task<Subscription?> CurrentSubscriptionAsync(Guid businessId)
        => dbContext.Subscriptions
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();

    private Task<PaymentMethod?> SavedPaymentMethodAsync(Guid businessId)
        => dbContext.PaymentMethods
            .Where(x =>
                x.BusinessId == businessId &&
                x.Provider == "Azul" &&
                x.ProviderPaymentMethodId != "" &&
                x.Last4 != "" &&
                x.ExpYear > 0)
            .OrderByDescending(x => x.IsDefault)
            .ThenByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();

    private static Guid BusinessId(ClaimsPrincipal user)
        => FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "pagos Azul");

    private static int PeriodDays(string billingCycle) => billingCycle switch
    {
        "trimestral" => 90,
        "anual" => 365,
        _ => 30
    };

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

    private static SubscriptionStatusResponse MapStatus(Business business, Subscription subscription)
    {
        var graceEndsAt = subscription.TrialEndsAt.AddHours(72);
        return new SubscriptionStatusResponse(
            subscription.Status,
            subscription.PlanId,
            subscription.BillingCycle,
            subscription.TrialEndsAt,
            subscription.Status is "trial_active" or "active",
            graceEndsAt,
            business.PaymentMethodRequired,
            business.HasUsedTrial);
    }

    private static void ApplyPlan(Subscription subscription, SubscriptionPlanPrice plan, string billingCycle)
    {
        var months = billingCycle switch
        {
            "trimestral" => 3,
            "anual" => 12,
            _ => 1
        };
        subscription.PlanId = plan.PlanId;
        subscription.PlanName = plan.PlanName;
        subscription.MonthlyPrice = plan.OriginalMonthlyUsd;
        subscription.MaxCollaborators = plan.CollaboratorsLimit;
        subscription.BillingCycle = plan.BillingCycle;
        subscription.DiscountPercent = plan.DiscountPercent;
        subscription.OriginalPrice = Math.Floor(plan.OriginalMonthlyUsd * months * 100m) / 100m;
        subscription.FinalPrice = plan.PriceUsd;
        subscription.CurrencyCode = SubscriptionPlanCatalog.CurrencyCode;
    }
}
