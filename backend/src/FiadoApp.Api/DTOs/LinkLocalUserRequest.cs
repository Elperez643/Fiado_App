using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class LinkLocalUserRequest
{
    [Required]
    [MaxLength(32)]
    public string Phone { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;

    [Required]
    [MaxLength(160)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string Role { get; set; } = string.Empty;

    [MaxLength(160)]
    public string? BusinessName { get; set; }

    [MaxLength(128)]
    public string? DeviceId { get; set; }

    [MaxLength(260)]
    public string? DeviceInfo { get; set; }
}
