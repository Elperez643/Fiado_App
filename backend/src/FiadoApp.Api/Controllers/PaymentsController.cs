using FiadoApp.Api.DTOs;
using FiadoApp.Api.Payments;
using FiadoApp.Api.Payments.Providers.Azul;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/payments")]
public sealed class PaymentsController(
    IPaymentService paymentService,
    IStripeBillingService stripeBillingService,
    IAzulPaymentService azulPaymentService) : ControllerBase
{
    [HttpGet("methods")]
    public Task<ActionResult<IReadOnlyList<PaymentMethodResponse>>> GetMethods()
        => Read(() => paymentService.GetMethodsAsync(User));

    [HttpPost("methods")]
    public Task<ActionResult<PaymentMethodResponse>> CreateMethod(CreatePaymentMethodRequest request)
        => Write(() => paymentService.CreateMethodAsync(User, request));

    [HttpGet("history")]
    public Task<ActionResult<IReadOnlyList<SubscriptionPaymentResponse>>> GetHistory()
        => Read(() => paymentService.GetHistoryAsync(User));

    [HttpPost("mock/charge")]
    public Task<ActionResult<SubscriptionPaymentResponse>> MockCharge()
        => Write(() => paymentService.MockChargeAsync(User));

    [HttpPost("mock/renew")]
    public Task<ActionResult<SubscriptionPaymentResponse>> MockRenew()
        => Write(() => paymentService.MockRenewAsync(User));

    [HttpPost("mock/fail")]
    public Task<ActionResult<SubscriptionPaymentResponse>> MockFail()
        => Write(() => paymentService.MockFailAsync(User));

    [HttpGet("subscription")]
    public Task<ActionResult<SubscriptionBillingResponse>> GetSubscription()
        => Read(() => paymentService.GetSubscriptionAsync(User));

    [HttpPost("stripe/create-checkout-session")]
    public Task<ActionResult<StripeCheckoutSessionResponse>> CreateStripeCheckoutSession(
        CreateStripeCheckoutSessionRequest request)
        => Write(() => stripeBillingService.CreateCheckoutSessionAsync(User, request));

    [HttpPost("stripe/create-setup-session")]
    public Task<ActionResult<StripeCheckoutSessionResponse>> CreateStripeSetupSession(
        CreateStripeCheckoutSessionRequest request)
        => Write(() => stripeBillingService.CreateSetupSessionAsync(User, request));

    [HttpPost("azul/create-card-token-session")]
    public Task<ActionResult<AzulCardTokenSessionResponse>> CreateAzulCardTokenSession(
        CreateAzulCardTokenSessionRequest request)
        => Write(() => azulPaymentService.CreateCardTokenSessionAsync(User, request));

    [HttpPost("azul/confirm-card-token")]
    public Task<ActionResult<PaymentMethodResponse>> ConfirmAzulCardToken(
        ConfirmAzulCardTokenRequest request)
        => Write(() => azulPaymentService.ConfirmCardTokenAsync(User, request));

    [HttpPost("azul/charge-subscription")]
    public Task<ActionResult<AzulChargeResponse>> ChargeAzulSubscription(
        ChargeAzulSubscriptionRequest request)
        => Write(() => azulPaymentService.ChargeSubscriptionAsync(User, request));

    [AllowAnonymous]
    [HttpPost("stripe/webhook")]
    public async Task<ActionResult> StripeWebhook()
    {
        var payload = await new StreamReader(Request.Body).ReadToEndAsync();
        var signature = Request.Headers["Stripe-Signature"].ToString();
        try
        {
            var eventType = await stripeBillingService.HandleWebhookAsync(payload, signature);
            return Ok(new { received = true, eventType });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = SanitizedWebhookError(ex.Message) });
        }
        catch (Stripe.StripeException ex)
        {
            return BadRequest(new { message = SanitizedWebhookError(ex.Message) });
        }
    }

    [AllowAnonymous]
    [HttpPost("azul/webhook")]
    public async Task<ActionResult> AzulWebhook()
    {
        var payload = await new StreamReader(Request.Body).ReadToEndAsync();
        var signature = Request.Headers["Azul-Signature"].ToString();
        try
        {
            var eventType = await azulPaymentService.HandleWebhookAsync(payload, signature);
            return Ok(new { received = true, eventType });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = SanitizedWebhookError(ex.Message) });
        }
        catch (NotSupportedException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

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
        catch (NotSupportedException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    private static string SanitizedWebhookError(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return "Webhook Stripe invalido.";
        }

        return message.Contains("secret", StringComparison.OrdinalIgnoreCase) ||
               message.Contains("signature", StringComparison.OrdinalIgnoreCase)
            ? "Webhook Stripe invalido."
            : message;
    }
}
