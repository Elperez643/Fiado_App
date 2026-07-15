using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/clients")]
public sealed class ClientsController(IClientService clientService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ClientResponse>>> GetClients()
    {
        return await ExecuteReadAsync(() => clientService.GetByBusinessAsync(User));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ClientResponse>> GetClient(Guid id)
    {
        return await ExecuteReadAsync(() => clientService.GetByIdAsync(User, id));
    }

    [HttpPost]
    public async Task<ActionResult<ClientResponse>> CreateClient(ClientCreateRequest request)
    {
        return await ExecuteWriteAsync(() => clientService.CreateAsync(User, request));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ClientResponse>> UpdateClient(Guid id, ClientUpdateRequest request)
    {
        return await ExecuteWriteAsync(() => clientService.UpdateAsync(User, id, request));
    }

    [HttpPost("sync/push")]
    public async Task<ActionResult<ClientSyncPushResponse>> PushSync(ClientSyncPushRequest request)
    {
        return await ExecuteWriteAsync(() => clientService.PushSyncAsync(User, request));
    }

    [HttpPost("sync/pull")]
    public async Task<ActionResult<ClientSyncPullResponse>> PullSync(ClientSyncPullRequest request)
    {
        return await ExecuteWriteAsync(() => clientService.PullSyncAsync(User, request));
    }

    private async Task<ActionResult<T>> ExecuteReadAsync<T>(Func<Task<T>> action)
    {
        try
        {
            return Ok(await action());
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    private async Task<ActionResult<T>> ExecuteWriteAsync<T>(Func<Task<T>> action)
    {
        try
        {
            return Ok(await action());
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
