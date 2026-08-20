// Supabase Auth "Send SMS" HTTP Hook — see docs/product/authentication.md.
//
// Supabase Auth calls this endpoint synchronously, before a user JWT
// exists, whenever it needs to deliver a phone-OTP SMS. Authentication
// for the call is the Standard Webhooks signature (SEND_SMS_HOOK_SECRETS),
// not a JWT — this function is registered with `verify_jwt = false` in
// supabase/config.toml for exactly that reason.
//
// This hook is ONLY for authentication OTP delivery right now. It is
// not, and must not become, the general Umoja notification/messaging
// engine — see docs/product/authentication.md.
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

import { loadHookSecret, loadNextSmsConfig } from "./config.ts";
import { log, maskPhone } from "./logger.ts";
import { buildOtpMessage } from "./message.ts";
import { sendNextSmsOtp } from "./nextsms.ts";
import { toNextSmsRecipient } from "./phone.ts";

interface SendSmsHookPayload {
  user?: { phone?: string };
  sms?: { otp?: string };
}

interface HandleRequestDeps {
  sendOtp?: typeof sendNextSmsOtp;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Shape Supabase Auth Hooks expect for a rejected/failed hook call. */
function hookError(httpCode: number, message: string): Response {
  return jsonResponse({ error: { http_code: httpCode, message } }, httpCode);
}

/**
 * Handles one Send SMS Hook invocation end to end: verifies the
 * Standard Webhooks signature, validates the payload, calls NextSMS
 * synchronously, and maps the result to a Supabase Auth Hook-compatible
 * response. Exported (rather than only wired into `Deno.serve`) so it
 * can be exercised directly in tests with a real `Request` object.
 */
export async function handleRequest(
  req: Request,
  deps: HandleRequestDeps = {},
): Promise<Response> {
  const sendOtp = deps.sendOtp ?? sendNextSmsOtp;

  // The raw body must be read (and kept) before any parsing — Standard
  // Webhooks signatures are computed over the exact raw bytes sent.
  const rawBody = await req.text();
  const headers = Object.fromEntries(req.headers);

  let payload: SendSmsHookPayload;
  try {
    const secret = loadHookSecret();
    const wh = new Webhook(secret);
    payload = wh.verify(rawBody, headers) as SendSmsHookPayload;
  } catch (error) {
    log("warn", "send-sms-hook: webhook signature verification failed", {
      reason: error instanceof Error ? error.message : "unknown",
    });
    return hookError(401, "Invalid webhook signature");
  }

  const phone = payload.user?.phone;
  const otp = payload.sms?.otp;

  if (!phone) {
    log("warn", "send-sms-hook: missing phone in payload");
    return hookError(400, "Missing phone number");
  }

  if (!otp) {
    log("warn", "send-sms-hook: missing otp in payload", {
      phone: maskPhone(phone),
    });
    return hookError(400, "Missing OTP");
  }

  let recipient: string;
  try {
    recipient = toNextSmsRecipient(phone);
  } catch {
    log("warn", "send-sms-hook: invalid phone format", {
      phone: maskPhone(phone),
    });
    return hookError(400, "Invalid phone number");
  }

  let config;
  try {
    config = loadNextSmsConfig();
  } catch (error) {
    log("error", "send-sms-hook: provider configuration error", {
      reason: error instanceof Error ? error.message : "unknown",
    });
    return hookError(500, "Unable to send verification SMS");
  }

  const reference = `UMOJA-OTP-${crypto.randomUUID()}`;
  const message = buildOtpMessage(otp);

  log("info", "send-sms-hook: request received, sending OTP", {
    phone: maskPhone(phone),
    reference,
  });

  const startedAt = performance.now();
  try {
    const result = await sendOtp({ recipient, message, reference, config });
    const durationMs = Math.round(performance.now() - startedAt);

    if (!result.ok) {
      log("error", "send-sms-hook: NextSMS returned a non-2xx response", {
        status: result.status,
        durationMs,
        reference,
      });
      return hookError(502, "Unable to send verification SMS");
    }

    log("info", "send-sms-hook: NextSMS accepted the message", {
      status: result.status,
      durationMs,
      reference,
    });
    return jsonResponse({}, 200);
  } catch (error) {
    const durationMs = Math.round(performance.now() - startedAt);
    log("error", "send-sms-hook: unexpected error calling NextSMS", {
      reason: error instanceof Error ? error.message : "unknown",
      durationMs,
      reference,
    });
    return hookError(500, "Unable to send verification SMS");
  }
}

// Guarded so importing `handleRequest` from tests does not also start an
// HTTP server as a side effect.
if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
