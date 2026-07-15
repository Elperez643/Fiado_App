using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class RegisterBusinessRequest
{
    [Required]
    [MaxLength(160)]
    public string OwnerName { get; set; } = string.Empty;

    [Required]
    [MaxLength(160)]
    public string BusinessName { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string Phone { get; set; } = string.Empty;

    [Required]
    [MinLength(6)]
    public string Password { get; set; } = string.Empty;

    [MaxLength(128)]
    public string? DeviceId { get; set; }

    [MaxLength(260)]
    public string? DeviceInfo { get; set; }
}
