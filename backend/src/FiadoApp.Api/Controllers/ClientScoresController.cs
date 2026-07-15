using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Route("api/client-scores")]
[Authorize]
public sealed class ClientScoresController(IClientScoreService clientScoreService) : ControllerBase
{
    [HttpGet("client/{clientId:guid}")]
    public async Task<ActionResult<ClientScoreResponse>> GetByClient(Guid clientId)
    {
        var score = await clientScoreService.GetByClientAsync(User, clientId);
        return score is null ? NotFound() : Ok(score);
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ClientScoreResponse>>> GetByBusiness()
        => Ok(await clientScoreService.GetByBusinessAsync(User));

    [HttpGet("top")]
    public async Task<ActionResult<IReadOnlyList<ClientScoreResponse>>> GetTop([FromQuery] int take = 10)
        => Ok(await clientScoreService.GetTopClientsAsync(User, take));

    [HttpGet("risk")]
    public async Task<ActionResult<IReadOnlyList<ClientScoreResponse>>> GetRisk([FromQuery] int take = 10)
        => Ok(await clientScoreService.GetRiskClientsAsync(User, take));

    [HttpPost("sync/push")]
    public async Task<ActionResult<ClientScoreSyncPushResponse>> Push(ClientScoreSyncPushRequest request)
        => Ok(await clientScoreService.PushSyncAsync(User, request));

    [HttpPost("sync/pull")]
    public async Task<ActionResult<ClientScoreSyncPullResponse>> Pull(ClientScoreSyncPullRequest request)
        => Ok(await clientScoreService.PullSyncAsync(User, request));
}
