namespace FiadoApp.Api.Payments.Webhooks;

public sealed record PaymentWebhookEnvelope(string Provider, string EventType, string PayloadJson);
