using System.ComponentModel.DataAnnotations;

namespace FiadoApp.Api.DTOs;

public sealed class ClientSyncPushRequest
{
    [Required]
    public List<ClientSyncPushItemRequest> Clients { get; set; } = [];
}

public sealed class ClientSyncPushItemRequest
{
    public int LocalId { get; set; }
    public Guid? ServerId { get; set; }

    [Required]
    [MaxLength(160)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string Phone { get; set; } = string.Empty;

    [MaxLength(260)]
    public string? Address { get; set; }

    [Required]
    public string Operation { get; set; } = "create";

    public DateTime UpdatedAt { get; set; }
}
