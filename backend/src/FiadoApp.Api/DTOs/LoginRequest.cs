using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class LoginRequest
{
    [Required]
    [MaxLength(32)]
    public string Phone { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;

    [Required]
    [MaxLength(128)]
    public string DeviceId { get; set; } = string.Empty;

    [MaxLength(260)]
    public string? DeviceInfo { get; set; }
}
