using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Route("api/whatsapp-campaigns")]
[Authorize]
public sealed class WhatsappCampaignsController(IWhatsappCampaignService service) : ControllerBase
{
    [HttpPost("sync/push")]
    public async Task<ActionResult<WhatsappCampaignSyncPushResponse>> Push(
        WhatsappCampaignSyncPushRequest request)
        => Ok(await service.PushSyncAsync(User, request));

    [HttpPost("sync/pull")]
    public async Task<ActionResult<WhatsappCampaignSyncPullResponse>> Pull(
        WhatsappCampaignSyncPullRequest request)
        => Ok(await service.PullSyncAsync(User, request));
}
