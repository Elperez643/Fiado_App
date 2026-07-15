using System.Security.Claims;
using FiadoApp.Api.DTOs;

namespace FiadoApp.Api.Services;

public interface IWhatsappCampaignService
{
    Task<WhatsappCampaignSyncPushResponse> PushSyncAsync(
        ClaimsPrincipal user,
        WhatsappCampaignSyncPushRequest request);

    Task<WhatsappCampaignSyncPullResponse> PullSyncAsync(
        ClaimsPrincipal user,
        WhatsappCampaignSyncPullRequest request);
}
