using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class RegisterCollaboratorRequest
{
    [Required]
    [MaxLength(160)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string Phone { get; set; } = string.Empty;

    [Required]
    [MinLength(6)]
    public string Password { get; set; } = string.Empty;

    public Guid? BusinessId { get; set; }
}
