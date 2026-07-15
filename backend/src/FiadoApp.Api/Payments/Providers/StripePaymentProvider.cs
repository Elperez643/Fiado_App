using Stripe;
using Stripe.Checkout;

namespace FiadoApp.Api.Payments.Providers;

public sealed class StripePaymentProvider(IConfiguration configuration) : IStripePaymentProvider
{
    public Task<string> CreateCustomerAsync(Guid businessId, string businessName)
    {
        EnsureConfigured();
        var service = new CustomerService();
        return CreateCustomerCoreAsync(service, businessId, businessName);
    }

    public Task<string> AttachPaymentMethodAsync(Guid businessId, string providerCustomerId, string mockCardLast4)
    {
        throw new InvalidOperationException("Stripe Checkout administra los metodos de pago; Fiado App no adjunta tarjetas.");
    }

    public Task<string> CreateSubscriptionAsync(Guid businessId, Guid subscriptionId, decimal amountUsd, string billingCycle)
    {
        throw new InvalidOperationException("Las suscripciones Stripe se crean mediante Checkout Session.");
    }

    public async Task CancelSubscriptionAsync(Guid businessId, string providerSubscriptionId)
    {
        EnsureConfigured();
        var service = new SubscriptionService();
        await service.CancelAsync(providerSubscriptionId);
    }

    public Task<string> HandleWebhookAsync(string eventType, string payloadJson)
        => Task.FromResult(eventType);

    public async Task<string> CreateCheckoutSessionAsync(
        Guid businessId,
        Guid subscriptionId,
        string businessName,
        string providerCustomerId,
        string priceId,
        string planId,
        string billingCycle)
    {
        EnsureConfigured();
        var service = new SessionService();
        var options = new SessionCreateOptions
        {
            Mode = "subscription",
            Customer = providerCustomerId,
            SuccessUrl = Required("Stripe:SuccessUrl"),
            CancelUrl = Required("Stripe:CancelUrl"),
            ClientReferenceId = businessId.ToString(),
            LineItems =
            [
                new SessionLineItemOptions
                {
                    Price = priceId,
                    Quantity = 1
                }
            ],
            SubscriptionData = new SessionSubscriptionDataOptions
            {
                TrialPeriodDays = 30,
                Metadata = Metadata(businessId, subscriptionId, planId, billingCycle)
            },
            Metadata = Metadata(businessId, subscriptionId, planId, billingCycle),
            CustomerUpdate = new SessionCustomerUpdateOptions
            {
                Name = "auto"
            }
        };

        var session = await service.CreateAsync(options);
        if (string.IsNullOrWhiteSpace(session.Url))
        {
            throw new InvalidOperationException("Stripe no devolvio URL de Checkout.");
        }

        return session.Url;
    }

    public async Task<string> CreateSetupSessionAsync(
        Guid businessId,
        string businessName,
        string providerCustomerId,
        string planId,
        string billingCycle)
    {
        EnsureConfigured();
        var service = new SessionService();
        var options = new SessionCreateOptions
        {
            Mode = "setup",
            Customer = providerCustomerId,
            SuccessUrl = Required("Stripe:SuccessUrl"),
            CancelUrl = Required("Stripe:CancelUrl"),
            ClientReferenceId = businessId.ToString(),
            Metadata = new Dictionary<string, string>
            {
                ["businessId"] = businessId.ToString(),
                ["planId"] = planId,
                ["billingCycle"] = billingCycle
            },
            CustomerUpdate = new SessionCustomerUpdateOptions
            {
                Name = "auto"
            }
        };

        var session = await service.CreateAsync(options);
        if (string.IsNullOrWhiteSpace(session.Url))
        {
            throw new InvalidOperationException("Stripe no devolvio URL de Setup.");
        }

        return session.Url;
    }

    public async Task<StripeSavedPaymentMethod> GetPaymentMethodAsync(string providerPaymentMethodId)
    {
        EnsureConfigured();
        var method = await new PaymentMethodService().GetAsync(providerPaymentMethodId);
        return new StripeSavedPaymentMethod(
            method.Id,
            method.Card?.Brand ?? "card",
            method.Card?.Last4 ?? "0000",
            (int)(method.Card?.ExpMonth ?? 0),
            (int)(method.Card?.ExpYear ?? 0));
    }

    public async Task<string> CreateTrialSubscriptionAsync(
        Guid businessId,
        Guid subscriptionId,
        string providerCustomerId,
        string providerPaymentMethodId,
        string priceId,
        string planId,
        string billingCycle)
    {
        EnsureConfigured();
        var service = new SubscriptionService();
        var subscription = await service.CreateAsync(new SubscriptionCreateOptions
        {
            Customer = providerCustomerId,
            DefaultPaymentMethod = providerPaymentMethodId,
            TrialPeriodDays = 30,
            Items =
            [
                new SubscriptionItemOptions
                {
                    Price = priceId
                }
            ],
            Metadata = Metadata(businessId, subscriptionId, planId, billingCycle),
            PaymentSettings = new SubscriptionPaymentSettingsOptions
            {
                SaveDefaultPaymentMethod = "on_subscription"
            }
        });

        if (string.IsNullOrWhiteSpace(subscription.Id))
        {
            throw new InvalidOperationException("Stripe no devolvio suscripcion.");
        }

        return subscription.Id;
    }

    public string ValidateAndExtractEventType(string payloadJson, string stripeSignature)
    {
        EnsureConfigured();
        var webhookSecret = Required("Stripe:WebhookSecret");
        var stripeEvent = EventUtility.ConstructEvent(
            payloadJson,
            stripeSignature,
            webhookSecret,
            throwOnApiVersionMismatch: false);
        return stripeEvent.Type;
    }

    private async Task<string> CreateCustomerCoreAsync(
        CustomerService service,
        Guid businessId,
        string businessName)
    {
        var customer = await service.CreateAsync(new CustomerCreateOptions
        {
            Name = businessName,
            Metadata = new Dictionary<string, string>
            {
                ["businessId"] = businessId.ToString(),
                ["source"] = "fiado_app_test"
            }
        });
        return customer.Id;
    }

    private void EnsureConfigured()
    {
        var secretKey = Required("Stripe:SecretKey");
        if (!secretKey.StartsWith("sk_test_", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Stripe debe configurarse en modo TEST con una clave sk_test_.");
        }
        StripeConfiguration.ApiKey = secretKey;
    }

    private string Required(string key)
    {
        var value = configuration[key];
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Stripe no esta configurado: falta {key}.");
        }
        return value.Trim();
    }

    private static Dictionary<string, string> Metadata(
        Guid businessId,
        Guid subscriptionId,
        string planId,
        string billingCycle)
    {
        return new Dictionary<string, string>
        {
            ["businessId"] = businessId.ToString(),
            ["subscriptionId"] = subscriptionId.ToString(),
            ["planId"] = planId,
            ["billingCycle"] = billingCycle
        };
    }
}
