namespace FiadoApp.Api.Entities;

public class User : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string UserType { get; set; } = string.Empty;
    public Guid? BusinessId { get; set; }
    public string PasswordHash { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public string? ActiveDeviceId { get; set; }
    public int SessionVersion { get; set; }
    public DateTime? LastLoginAt { get; set; }
    public DateTime? LastSeenAt { get; set; }
    public string? DeviceInfo { get; set; }

    public Business? Business { get; set; }
}
