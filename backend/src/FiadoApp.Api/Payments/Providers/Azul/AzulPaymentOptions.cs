namespace FiadoApp.Api.Payments.Providers.Azul;

public sealed class AzulPaymentOptions
{
    public string MerchantId { get; set; } = string.Empty;
    public string MerchantName { get; set; } = string.Empty;
    public string AuthKey { get; set; } = string.Empty;
    public string ApiUrl { get; set; } = string.Empty;
    public string SuccessUrl { get; set; } = string.Empty;
    public string CancelUrl { get; set; } = string.Empty;
    public string WebhookSecret { get; set; } = string.Empty;
    public string Currency { get; set; } = "USD";
    public string Environment { get; set; } = "Sandbox";

    public bool HasRealCredentials =>
        !string.IsNullOrWhiteSpace(MerchantId) &&
        !string.IsNullOrWhiteSpace(AuthKey) &&
        !string.IsNullOrWhiteSpace(ApiUrl);
}
