using System.Security.Claims;
using System.Text.Json;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using FiadoApp.Api.Payments.Providers;
using FiadoApp.Api.Services;
using FiadoApp.Api.Subscriptions;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Payments;

public sealed class StripeBillingService(
    FiadoDbContext dbContext,
    IStripePaymentProvider stripeProvider,
    IConfiguration configuration) : IStripeBillingService
{
    private const decimal ExchangeRate = 59.25m;
    private static readonly TimeSpan OfflineGrace = TimeSpan.FromHours(72);

    public async Task<StripeCheckoutSessionResponse> CreateCheckoutSessionAsync(
        ClaimsPrincipal user,
        CreateStripeCheckoutSessionRequest request)
    {
        var businessId = BusinessId(user);
        var billingCycle = SubscriptionPlanCatalog.NormalizeBillingCycle(request.BillingCycle);
        var plan = SubscriptionPlanCatalog.PriceFor(request.PlanId, billingCycle);
        var priceId = PriceId(plan.PlanId, billingCycle);

        var business = await dbContext.Businesses
            .FirstOrDefaultAsync(x => x.Id == businessId)
            ?? throw new KeyNotFoundException("Negocio no encontrado.");

        var subscription = await dbContext.Subscriptions
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync()
            ?? CreateSubscription(businessId);
        var customerId = await EnsureStripeCustomerAsync(businessId, business.Name);

        ApplyPlan(subscription, plan, billingCycle);
        subscription.PaymentProvider = "stripe";
        subscription.ProviderCustomerId = customerId;
        subscription.Status = subscription.Status == "active" ? "active" : "trial_active";
        subscription.UpdatedAt = DateTime.UtcNow;
        subscription.SyncStatus = "synced";
        if (dbContext.Entry(subscription).State == EntityState.Detached)
        {
            dbContext.Subscriptions.Add(subscription);
        }

        await dbContext.SaveChangesAsync();

        var checkoutUrl = await stripeProvider.CreateCheckoutSessionAsync(
            businessId,
            subscription.Id,
            business.Name,
            customerId,
            priceId,
            plan.PlanId,
            billingCycle);

        return new StripeCheckoutSessionResponse(
            checkoutUrl,
            "stripe",
            "subscription",
            plan.PlanId,
            billingCycle);
    }

    public async Task<StripeCheckoutSessionResponse> CreateSetupSessionAsync(
        ClaimsPrincipal user,
        CreateStripeCheckoutSessionRequest request)
    {
        var businessId = BusinessId(user);
        var billingCycle = SubscriptionPlanCatalog.NormalizeBillingCycle(request.BillingCycle);
        var plan = SubscriptionPlanCatalog.PriceFor(request.PlanId, billingCycle);
        var priceId = PriceId(plan.PlanId, billingCycle);
        var business = await dbContext.Businesses
            .FirstOrDefaultAsync(x => x.Id == businessId)
            ?? throw new KeyNotFoundException("Negocio no encontrado.");

        var customerId = await EnsureStripeCustomerAsync(businessId, business.Name);
        business.StripeCustomerId = customerId;
        business.CurrentPlan = plan.PlanId;
        business.CurrentBillingCycle = billingCycle;
        business.SubscriptionStatus = "payment_method_required";
        business.PaymentMethodRequired = true;
        business.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        var setupUrl = await stripeProvider.CreateSetupSessionAsync(
            businessId,
            business.Name,
            customerId,
            plan.PlanId,
            billingCycle);

        return new StripeCheckoutSessionResponse(
            setupUrl,
            "stripe",
            "setup",
            plan.PlanId,
            billingCycle);
    }

    public async Task<SubscriptionStatusResponse> ActivateTrialAsync(
        ClaimsPrincipal user,
        ActivateTrialRequest request)
    {
        var businessId = BusinessId(user);
        var billingCycle = SubscriptionPlanCatalog.NormalizeBillingCycle(request.BillingCycle);
        var plan = SubscriptionPlanCatalog.PriceFor(request.PlanId, billingCycle);
        var priceId = PriceId(plan.PlanId, billingCycle);
        var business = await dbContext.Businesses
            .FirstOrDefaultAsync(x => x.Id == businessId)
            ?? throw new KeyNotFoundException("Negocio no encontrado.");

        if (business.HasUsedTrial)
        {
            throw new InvalidOperationException("Este negocio ya utilizo su periodo de prueba.");
        }

        var paymentMethod = await SavedPaymentMethodAsync(businessId);
        if (paymentMethod is null)
        {
            throw new InvalidOperationException("Agrega una tarjeta para activar tu prueba gratis de 30 dias.");
        }

        var now = DateTime.UtcNow;
        var subscription = await dbContext.Subscriptions
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();
        if (subscription is null)
        {
            subscription = CreateSubscription(businessId);
            dbContext.Subscriptions.Add(subscription);
        }

        ApplyPlan(subscription, plan, billingCycle);
        var providerSubscriptionId = await stripeProvider.CreateTrialSubscriptionAsync(
            businessId,
            subscription.Id,
            paymentMethod.ProviderCustomerId,
            paymentMethod.ProviderPaymentMethodId,
            priceId,
            plan.PlanId,
            billingCycle);
        subscription.Status = "trial_active";
        subscription.TrialStartedAt = now;
        subscription.TrialEndsAt = now.AddDays(30);
        subscription.CurrentPeriodStartedAt = now;
        subscription.CurrentPeriodEndsAt = now.AddDays(30);
        subscription.PaymentProvider = "stripe";
        subscription.ProviderCustomerId = paymentMethod.ProviderCustomerId;
        subscription.ProviderSubscriptionId = providerSubscriptionId;
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

    public async Task<SubscriptionStatusResponse> GetStatusAsync(ClaimsPrincipal user)
    {
        var businessId = BusinessId(user);
        var business = await dbContext.Businesses.AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == businessId)
            ?? throw new KeyNotFoundException("Negocio no encontrado.");
        var subscription = await dbContext.Subscriptions.AsNoTracking()
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();

        return MapStatus(business, subscription);
    }

    public async Task<string> HandleWebhookAsync(string payloadJson, string stripeSignature)
    {
        var eventType = stripeProvider.ValidateAndExtractEventType(payloadJson, stripeSignature);
        var log = new PaymentWebhookLog
        {
            Provider = "stripe",
            EventType = eventType,
            PayloadJson = payloadJson,
            Processed = false,
            CreatedAt = DateTime.UtcNow
        };
        dbContext.PaymentWebhookLogs.Add(log);

        try
        {
            using var document = JsonDocument.Parse(payloadJson);
            var root = document.RootElement;
            var obj = root.GetProperty("data").GetProperty("object");

            switch (eventType)
            {
                case "checkout.session.completed":
                    await HandleCheckoutCompletedAsync(obj);
                    break;
                case "setup_intent.succeeded":
                    await HandleSetupIntentSucceededAsync(obj);
                    break;
                case "customer.subscription.created":
                case "customer.subscription.updated":
                case "customer.subscription.deleted":
                    await HandleSubscriptionEventAsync(obj, eventType);
                    break;
                case "invoice.payment_succeeded":
                    await HandleInvoiceEventAsync(obj, "paid");
                    break;
                case "invoice.payment_failed":
                    await HandleInvoiceEventAsync(obj, "failed");
                    break;
            }

            log.Processed = true;
            log.ProcessedAt = DateTime.UtcNow;
            await dbContext.SaveChangesAsync();
            return eventType;
        }
        catch
        {
            await dbContext.SaveChangesAsync();
            throw;
        }
    }

    private async Task HandleCheckoutCompletedAsync(JsonElement session)
    {
        var metadata = session.GetProperty("metadata");
        var subscriptionId = GuidValue(metadata, "subscriptionId");
        var businessId = GuidValue(metadata, "businessId");
        var stripeSubscriptionId = StringValue(session, "subscription");
        var stripeCustomerId = StringValue(session, "customer");

        var subscription = await dbContext.Subscriptions
            .FirstOrDefaultAsync(x => x.Id == subscriptionId && x.BusinessId == businessId);
        if (subscription is null) return;

        subscription.PaymentProvider = "stripe";
        subscription.ProviderSubscriptionId = stripeSubscriptionId;
        subscription.Status = "trial_active";
        subscription.UpdatedAt = DateTime.UtcNow;
        subscription.SyncStatus = "synced";

        if (!string.IsNullOrWhiteSpace(stripeCustomerId))
        {
            await EnsureStripeCustomerRecordAsync(businessId, stripeCustomerId);
        }

        await UpdateBusinessStatusAsync(subscription.BusinessId, "trial_active", paymentMethodRequired: false);
    }

    private async Task HandleSetupIntentSucceededAsync(JsonElement setupIntent)
    {
        var customerId = StringValue(setupIntent, "customer");
        var paymentMethodId = StringValue(setupIntent, "payment_method");
        if (customerId is null || paymentMethodId is null) return;

        var business = await dbContext.Businesses
            .FirstOrDefaultAsync(x => x.StripeCustomerId == customerId);
        if (business is null)
        {
            var customerRecord = await dbContext.PaymentMethods
                .FirstOrDefaultAsync(x => x.Provider == "stripe" && x.ProviderCustomerId == customerId);
            if (customerRecord is null) return;
            business = await dbContext.Businesses.FirstOrDefaultAsync(x => x.Id == customerRecord.BusinessId);
        }
        if (business is null) return;

        var card = await stripeProvider.GetPaymentMethodAsync(paymentMethodId);
        await dbContext.PaymentMethods
            .Where(x => x.BusinessId == business.Id && x.IsDefault)
            .ExecuteUpdateAsync(x => x.SetProperty(p => p.IsDefault, false));

        var existing = await dbContext.PaymentMethods
            .FirstOrDefaultAsync(x => x.BusinessId == business.Id && x.ProviderPaymentMethodId == card.Id);
        if (existing is null)
        {
            dbContext.PaymentMethods.Add(new PaymentMethod
            {
                BusinessId = business.Id,
                Provider = "stripe",
                ProviderCustomerId = customerId,
                ProviderPaymentMethodId = card.Id,
                Brand = card.Brand,
                Last4 = card.Last4,
                ExpMonth = card.ExpMonth,
                ExpYear = card.ExpYear,
                IsDefault = true,
                CreatedAt = DateTime.UtcNow
            });
        }
        else
        {
            existing.Brand = card.Brand;
            existing.Last4 = card.Last4;
            existing.ExpMonth = card.ExpMonth;
            existing.ExpYear = card.ExpYear;
            existing.IsDefault = true;
        }

        business.PaymentMethodRequired = false;
        business.SubscriptionStatus = business.HasUsedTrial ? business.SubscriptionStatus : "payment_method_required";
        business.UpdatedAt = DateTime.UtcNow;
    }

    private async Task HandleSubscriptionEventAsync(JsonElement stripeSubscription, string eventType)
    {
        var providerSubscriptionId = StringValue(stripeSubscription, "id");
        if (providerSubscriptionId is null) return;

        var subscription = await dbContext.Subscriptions
            .FirstOrDefaultAsync(x => x.ProviderSubscriptionId == providerSubscriptionId);
        if (subscription is null)
        {
            var metadata = stripeSubscription.TryGetProperty("metadata", out var meta) ? meta : default;
            var localSubscriptionId = metadata.ValueKind == JsonValueKind.Object ? GuidValue(metadata, "subscriptionId") : Guid.Empty;
            subscription = localSubscriptionId == Guid.Empty
                ? null
                : await dbContext.Subscriptions.FirstOrDefaultAsync(x => x.Id == localSubscriptionId);
        }
        if (subscription is null) return;

        subscription.PaymentProvider = "stripe";
        subscription.ProviderSubscriptionId = providerSubscriptionId;
        subscription.Status = eventType == "customer.subscription.deleted"
            ? "canceled"
            : NormalizeStripeSubscriptionStatus(StringValue(stripeSubscription, "status") ?? subscription.Status);
        subscription.CurrentPeriodStartedAt = UnixDate(stripeSubscription, "current_period_start") ?? subscription.CurrentPeriodStartedAt;
        subscription.CurrentPeriodEndsAt = UnixDate(stripeSubscription, "current_period_end") ?? subscription.CurrentPeriodEndsAt;
        subscription.TrialEndsAt = UnixDate(stripeSubscription, "trial_end") ?? subscription.TrialEndsAt;
        subscription.UpdatedAt = DateTime.UtcNow;
        subscription.SyncStatus = "synced";
        await UpdateBusinessStatusAsync(
            subscription.BusinessId,
            subscription.Status,
            paymentMethodRequired: false);
    }

    private async Task HandleInvoiceEventAsync(JsonElement invoice, string status)
    {
        var providerSubscriptionId = StringValue(invoice, "subscription");
        var invoiceId = StringValue(invoice, "id");
        if (providerSubscriptionId is null || invoiceId is null) return;

        var subscription = await dbContext.Subscriptions
            .FirstOrDefaultAsync(x => x.ProviderSubscriptionId == providerSubscriptionId);
        if (subscription is null) return;
        if (await dbContext.SubscriptionPayments.AnyAsync(x => x.ProviderTransactionId == invoiceId))
        {
            return;
        }

        var amountCents = LongValue(invoice, status == "paid" ? "amount_paid" : "amount_due");
        var amountUsd = decimal.Round(amountCents / 100m, 2);
        dbContext.SubscriptionPayments.Add(new SubscriptionPayment
        {
            SubscriptionId = subscription.Id,
            BusinessId = subscription.BusinessId,
            AmountUsd = amountUsd,
            AmountDop = decimal.Round(amountUsd * ExchangeRate, 2),
            ExchangeRate = ExchangeRate,
            BillingCycle = subscription.BillingCycle,
            PaymentDate = DateTime.UtcNow,
            Status = status,
            Provider = "stripe",
            ProviderTransactionId = invoiceId,
            CreatedAt = DateTime.UtcNow
        });

        subscription.Status = status == "paid" ? "active" : "past_due";
        subscription.PaymentProvider = "stripe";
        subscription.UpdatedAt = DateTime.UtcNow;
        subscription.SyncStatus = "synced";
        await UpdateBusinessStatusAsync(
            subscription.BusinessId,
            subscription.Status,
            paymentMethodRequired: false);
    }

    private async Task<string> EnsureStripeCustomerAsync(Guid businessId, string businessName)
    {
        var existing = await dbContext.PaymentMethods
            .Where(x => x.BusinessId == businessId && x.Provider == "stripe")
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();
        if (existing is not null && !string.IsNullOrWhiteSpace(existing.ProviderCustomerId))
        {
            return existing.ProviderCustomerId;
        }

        var customerId = await stripeProvider.CreateCustomerAsync(businessId, businessName);
        await EnsureStripeCustomerRecordAsync(businessId, customerId);
        return customerId;
    }

    private async Task EnsureStripeCustomerRecordAsync(Guid businessId, string customerId)
    {
        var existing = await dbContext.PaymentMethods
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Provider == "stripe" && x.ProviderCustomerId == customerId);
        if (existing is not null) return;

        dbContext.PaymentMethods.Add(new PaymentMethod
        {
            BusinessId = businessId,
            Provider = "stripe",
            ProviderCustomerId = customerId,
            ProviderPaymentMethodId = string.Empty,
            Brand = "Stripe Customer",
            Last4 = string.Empty,
            ExpMonth = 0,
            ExpYear = 0,
            IsDefault = false,
            CreatedAt = DateTime.UtcNow
        });
    }

    private string PriceId(string planId, string billingCycle)
    {
        var key = $"Stripe:PriceIds:{planId}:{billingCycle}";
        var priceId = configuration[key];
        if (string.IsNullOrWhiteSpace(priceId))
        {
            throw new InvalidOperationException($"Stripe no esta configurado: falta priceId para {planId}/{billingCycle}.");
        }
        if (!priceId.StartsWith("price_", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Stripe debe usar Price IDs de modo test con formato price_...");
        }
        return priceId.Trim();
    }

    private static Subscription CreateSubscription(Guid businessId)
    {
        var now = DateTime.UtcNow;
        return new Subscription
        {
            BusinessId = businessId,
            Status = "payment_method_required",
            TrialStartedAt = now,
            TrialEndsAt = now.AddDays(30),
            CurrentPeriodStartedAt = now,
            CurrentPeriodEndsAt = now.AddDays(30)
        };
    }

    private Task<PaymentMethod?> SavedPaymentMethodAsync(Guid businessId)
        => dbContext.PaymentMethods
            .Where(x =>
                x.BusinessId == businessId &&
                x.Provider == "stripe" &&
                x.ProviderPaymentMethodId != "" &&
                x.Last4 != "" &&
                x.ExpYear > 0)
            .OrderByDescending(x => x.IsDefault)
            .ThenByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();

    private async Task UpdateBusinessStatusAsync(Guid businessId, string status, bool paymentMethodRequired)
    {
        var business = await dbContext.Businesses.FirstOrDefaultAsync(x => x.Id == businessId);
        if (business is null) return;
        business.SubscriptionStatus = status;
        business.PaymentMethodRequired = paymentMethodRequired;
        business.UpdatedAt = DateTime.UtcNow;
        var subscription = await dbContext.Subscriptions
            .Where(x => x.BusinessId == businessId)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();
        if (subscription is not null)
        {
            business.TrialStartedAt = subscription.TrialStartedAt;
            business.TrialEndsAt = subscription.TrialEndsAt;
            business.CurrentPlan = subscription.PlanId;
            business.CurrentBillingCycle = subscription.BillingCycle;
        }
    }

    private static string NormalizeStripeSubscriptionStatus(string status)
        => status switch
        {
            "trialing" => "trial_active",
            "active" => "active",
            "past_due" => "past_due",
            "canceled" => "canceled",
            "unpaid" => "expired",
            "incomplete" => "payment_method_required",
            "incomplete_expired" => "expired",
            _ => status
        };

    private static SubscriptionStatusResponse MapStatus(Business business, Subscription? subscription)
    {
        var status = subscription?.Status ?? business.SubscriptionStatus;
        var trialEndsAt = subscription?.TrialEndsAt ?? business.TrialEndsAt;
        var usable = status is "trial_active" or "active";
        DateTime? graceEndsAt = trialEndsAt is null ? null : trialEndsAt.Value.Add(OfflineGrace);
        return new SubscriptionStatusResponse(
            status,
            subscription?.PlanId ?? business.CurrentPlan,
            subscription?.BillingCycle ?? business.CurrentBillingCycle,
            trialEndsAt,
            usable,
            graceEndsAt,
            business.PaymentMethodRequired,
            business.HasUsedTrial);
    }

    private static Guid BusinessId(ClaimsPrincipal user)
        => FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "pagos stripe");

    private static Guid GuidValue(JsonElement element, string property)
        => Guid.TryParse(StringValue(element, property), out var value) ? value : Guid.Empty;

    private static string? StringValue(JsonElement element, string property)
        => element.TryGetProperty(property, out var value) && value.ValueKind != JsonValueKind.Null
            ? value.GetString()
            : null;

    private static long LongValue(JsonElement element, string property)
        => element.TryGetProperty(property, out var value) && value.TryGetInt64(out var number)
            ? number
            : 0;

    private static DateTime? UnixDate(JsonElement element, string property)
    {
        var seconds = LongValue(element, property);
        return seconds <= 0 ? null : DateTimeOffset.FromUnixTimeSeconds(seconds).UtcDateTime;
    }

    private static void ApplyPlan(Subscription subscription, SubscriptionPlanPrice plan, string billingCycle)
    {
        var months = billingCycle switch
        {
            "trimestral" => 3,
            "anual" => 12,
            _ => 1
        };
        var original = Math.Floor(plan.OriginalMonthlyUsd * months * 100m) / 100m;
        subscription.PlanId = plan.PlanId;
        subscription.PlanName = plan.PlanName;
        subscription.MonthlyPrice = plan.OriginalMonthlyUsd;
        subscription.MaxCollaborators = plan.CollaboratorsLimit;
        subscription.BillingCycle = plan.BillingCycle;
        subscription.DiscountPercent = plan.DiscountPercent;
        subscription.OriginalPrice = original;
        subscription.FinalPrice = plan.PriceUsd;
        subscription.CurrencyCode = SubscriptionPlanCatalog.CurrencyCode;
    }
}
