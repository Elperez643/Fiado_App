using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/sync/{module}")]
public sealed class SyncController(IGenericSyncService syncService) : ControllerBase
{
    [HttpPost("push")]
    public async Task<ActionResult<GenericSyncPushResponse>> Push(
        string module,
        GenericSyncPushRequest request)
    {
        return await Write(() => syncService.PushAsync(User, module, request));
    }

    [HttpPost("pull")]
    public async Task<ActionResult<GenericSyncPullResponse>> Pull(
        string module,
        GenericSyncPullRequest request)
    {
        return await Write(() => syncService.PullAsync(User, module, request));
    }

    private async Task<ActionResult<T>> Write<T>(Func<Task<T>> action)
    {
        try
        {
            return Ok(await action());
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
