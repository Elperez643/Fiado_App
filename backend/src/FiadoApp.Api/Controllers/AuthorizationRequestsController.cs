using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
public sealed class AuthorizationRequestsController(IAuthorizationRequestService authorizationRequestService) : ControllerBase
{
    [HttpGet("api/authorization-requests/pending")]
    public async Task<ActionResult<IReadOnlyList<AuthorizationRequestResponse>>> GetPending()
        => await Read(() => authorizationRequestService.GetPendingAsync(User));

    [HttpGet("api/authorization-requests/my")]
    public async Task<ActionResult<IReadOnlyList<AuthorizationRequestResponse>>> GetMy()
        => await Read(() => authorizationRequestService.GetMyAsync(User));

    [HttpPost("api/authorization-requests/sync/push")]
    public async Task<ActionResult<AuthorizationRequestSyncPushResponse>> Push(AuthorizationRequestSyncPushRequest request)
        => await Write(() => authorizationRequestService.PushSyncAsync(User, request));

    [HttpPost("api/authorization-requests/sync/pull")]
    public async Task<ActionResult<AuthorizationRequestSyncPullResponse>> Pull(AuthorizationRequestSyncPullRequest request)
        => await Write(() => authorizationRequestService.PullSyncAsync(User, request));

    [HttpPost("api/authorization-requests/{id:guid}/approve")]
    public async Task<ActionResult<AuthorizationRequestResponse>> Approve(Guid id, AuthorizationRequestDecisionRequest request)
        => await Write(() => authorizationRequestService.ApproveAsync(User, id, request));

    [HttpPost("api/authorization-requests/{id:guid}/reject")]
    public async Task<ActionResult<AuthorizationRequestResponse>> Reject(Guid id, AuthorizationRequestDecisionRequest request)
        => await Write(() => authorizationRequestService.RejectAsync(User, id, request));

    private async Task<ActionResult<T>> Read<T>(Func<Task<T>> action)
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
