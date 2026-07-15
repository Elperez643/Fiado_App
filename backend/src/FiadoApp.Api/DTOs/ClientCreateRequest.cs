using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class ClientCreateRequest
{
    [Required]
    [MaxLength(160)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string Phone { get; set; } = string.Empty;

    [MaxLength(260)]
    public string? Address { get; set; }
}
