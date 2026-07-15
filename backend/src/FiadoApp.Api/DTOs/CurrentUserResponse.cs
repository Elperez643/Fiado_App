namespace FiadoApp.Api.DTOs;

public sealed class CurrentUserResponse
{
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public Guid? BusinessId { get; set; }
    public string? BusinessName { get; set; }
    public bool IsActive { get; set; }
}
