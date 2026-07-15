using FiadoApp.Api.DTOs;
using FiadoApp.Api.Payments;
using FiadoApp.Api.Payments.Providers.Azul;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/subscriptions")]
public sealed class SubscriptionsController(
    IStripeBillingService stripeBillingService,
    IAzulPaymentService azulPaymentService,
    ISubscriptionRenewalService subscriptionRenewalService,
    IConfiguration configuration,
    IWebHostEnvironment environment) : ControllerBase
{
    [HttpPost("activate-trial")]
    public async Task<ActionResult<SubscriptionStatusResponse>> ActivateTrial(ActivateTrialRequest request)
    {
        try
        {
            if (string.Equals(configuration["Payments:Provider"], "Azul", StringComparison.OrdinalIgnoreCase))
            {
                return Ok(await azulPaymentService.ActivateTrialAsync(User, request));
            }

            return Ok(await stripeBillingService.ActivateTrialAsync(User, request));
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
        catch (NotSupportedException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("status")]
    public async Task<ActionResult<SubscriptionStatusResponse>> Status()
    {
        try
        {
            return Ok(await stripeBillingService.GetStatusAsync(User));
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

    [HttpPost("run-renewal-check")]
    public async Task<ActionResult<IReadOnlyList<AzulChargeResponse>>> RunRenewalCheck(
        ChargeAzulSubscriptionRequest request)
    {
        if (!environment.IsDevelopment() && !User.IsInRole("Admin"))
        {
            return NotFound();
        }

        try
        {
            return Ok(await subscriptionRenewalService.RunRenewalCheckAsync(request.ForceFailure));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (NotSupportedException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
