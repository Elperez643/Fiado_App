namespace FiadoApp.Api.DTOs;

public sealed class AuthResponse
{
    public string Token { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public CurrentUserResponse User { get; set; } = new();
    public string? SubscriptionStatus { get; set; }
    public bool PaymentMethodRequired { get; set; }
    public string? Message { get; set; }
    public int SessionVersion { get; set; }
    public string? DeviceId { get; set; }
}
