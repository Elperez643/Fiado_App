namespace FiadoApp.Api.DTOs;

public sealed class ClientSyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<ClientResponse> Clients { get; set; } = [];
}
