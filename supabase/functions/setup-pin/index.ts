// setup-pin — prompt 05E §6. Authenticated Edge Function: after OTP has
// already established a valid Supabase session, create or replace that
// user's 4-digit PIN credential. Called from:
//   - first-time setup, right after a fresh OTP verify with no PIN yet
//   - "Forgot PIN" recovery, right after the recovery OTP re-verifies
//
// Never returns, stores, or logs the PIN or the derived internal
// password — see docs/product/authentication.md.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { loadPinPepper, loadSupabaseEnvConfig } from "../_shared/config.ts";
import {
  corsPreflightResponse,
  errorResponse,
  jsonResponse,
} from "../_shared/http.ts";
import { log } from "../_shared/logger.ts";
import { normalizeTanzaniaPhone } from "../_shared/phone.ts";
import {
  CURRENT_CREDENTIAL_VERSION,
  deriveInternalPassword,
  isValidPin,
} from "../_shared/pin_derivation.ts";

interface SetupPinRequestBody {
  pin?: unknown;
}

interface ResolvedCaller {
  userId: string;
  phone: string | null;
  phoneConfirmed: boolean;
}

/** The exact external calls this handler makes, injected for testing —
 * same shape as `send-sms-hook`'s `HandleRequestDeps` pattern: real
 * implementations are constructed only when a dependency isn't
 * supplied, so tests never need to mock network calls. */
interface HandleRequestDeps {
  resolveCaller?: (authorizationHeader: string) => Promise<ResolvedCaller | null>;
  setAuthPassword?: (userId: string, password: string) => Promise<{ error: string | null }>;
  upsertCredential?: (params: {
    userId: string;
    phoneE164: string;
    credentialVersion: number;
  }) => Promise<{ error: string | null }>;
  pinPepper?: string;
}

function buildDefaultDeps(): Required<Omit<HandleRequestDeps, "pinPepper">> & { pinPepper: string } {
  const env = loadSupabaseEnvConfig();
  const pinPepper = loadPinPepper();

  const anonClient = createClient(env.url, env.anonKey);
  const adminClient = createClient(env.url, env.serviceRoleKey);

  return {
    pinPepper,
    resolveCaller: async (authorizationHeader) => {
      const jwt = authorizationHeader.replace(/^Bearer\s+/i, "");
      const { data, error } = await anonClient.auth.getUser(jwt);
      if (error || !data.user) return null;
      return {
        userId: data.user.id,
        phone: data.user.phone ?? null,
        phoneConfirmed: Boolean(data.user.phone_confirmed_at),
      };
    },
    setAuthPassword: async (userId, password) => {
      const { error } = await adminClient.auth.admin.updateUserById(userId, {
        password,
      });
      return { error: error ? error.message : null };
    },
    upsertCredential: async ({ userId, phoneE164, credentialVersion }) => {
      const nowIso = new Date().toISOString();
      const { error } = await adminClient.from("user_pin_credentials").upsert(
        {
          user_id: userId,
          phone_e164: phoneE164,
          credential_version: credentialVersion,
          failed_attempts: 0,
          locked_until: null,
          pin_set_at: nowIso,
        },
        { onConflict: "user_id" },
      );
      return { error: error ? error.message : null };
    },
  };
}

export async function handleRequest(
  req: Request,
  deps: HandleRequestDeps = {},
): Promise<Response> {
  log("info", "setup-pin: request received");

  let defaults: ReturnType<typeof buildDefaultDeps> | null;
  try {
    defaults = deps.resolveCaller && deps.setAuthPassword && deps.upsertCredential && deps.pinPepper
      ? null
      : buildDefaultDeps();
  } catch (error) {
    // Most commonly a missing/misconfigured secret (e.g. PIN_PEPPER not
    // set via `supabase secrets set`) — `error.message` is safe to log
    // (it names the missing variable, never a value), but this must
    // never crash the function with an unhandled exception/unshaped
    // response.
    log("error", "setup-pin: server misconfigured", {
      reason: error instanceof Error ? error.message : "unknown",
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  const resolveCaller = deps.resolveCaller ?? defaults!.resolveCaller;
  const setAuthPassword = deps.setAuthPassword ?? defaults!.setAuthPassword;
  const upsertCredential = deps.upsertCredential ?? defaults!.upsertCredential;
  const pinPepper = deps.pinPepper ?? defaults!.pinPepper;

  const authorizationHeader = req.headers.get("Authorization");
  if (!authorizationHeader) {
    log("warn", "setup-pin: missing Authorization header");
    return errorResponse("UNAUTHORIZED", 401);
  }

  let caller: ResolvedCaller | null;
  try {
    caller = await resolveCaller(authorizationHeader);
  } catch (error) {
    log("error", "setup-pin: unexpected error resolving caller", {
      reason: error instanceof Error ? error.message : "unknown",
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  if (!caller) {
    log("warn", "setup-pin: caller could not be resolved from Authorization header");
    return errorResponse("UNAUTHORIZED", 401);
  }

  let body: SetupPinRequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("INVALID_PIN", 400);
  }

  if (!isValidPin(body.pin)) {
    log("warn", "setup-pin: rejected non-4-digit PIN", { userId: caller.userId });
    return errorResponse("INVALID_PIN", 400);
  }
  const pin = body.pin;

  if (!caller.phone || !caller.phoneConfirmed) {
    log("warn", "setup-pin: caller has no verified phone", { userId: caller.userId });
    return errorResponse("PHONE_NOT_VERIFIED", 403);
  }

  const phoneE164 = normalizeTanzaniaPhone(caller.phone);
  if (!phoneE164) {
    // The phone on an authenticated Supabase user should already be
    // canonical E.164 — this is an internal consistency problem, not
    // something the caller did wrong.
    log("error", "setup-pin: authenticated user's phone failed normalization", {
      userId: caller.userId,
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  let derivedPassword: string;
  try {
    derivedPassword = await deriveInternalPassword(
      caller.userId,
      pin,
      pinPepper,
      CURRENT_CREDENTIAL_VERSION,
    );
  } catch (error) {
    log("error", "setup-pin: password derivation failed", {
      reason: error instanceof Error ? error.message : "unknown",
      userId: caller.userId,
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  const passwordResult = await setAuthPassword(caller.userId, derivedPassword);
  if (passwordResult.error) {
    log("error", "setup-pin: failed to update Supabase Auth password", {
      userId: caller.userId,
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  // From this point on, the Auth password already matches this PIN —
  // see the consistency analysis below. `upsertCredential` is retried a
  // few times, in-request, before giving up: it's the one step whose
  // failure here (right after the password already changed) is worth
  // squeezing the odds of down to near-zero, since a transient
  // failure (a momentary DB blip) is far more likely to succeed on an
  // immediate second attempt than to need a whole separate client
  // retry round trip.
  let credentialResult: { error: string | null } = { error: null };
  const upsertAttempts = 3;
  for (let attempt = 1; attempt <= upsertAttempts; attempt++) {
    credentialResult = await upsertCredential({
      userId: caller.userId,
      phoneE164,
      credentialVersion: CURRENT_CREDENTIAL_VERSION,
    });
    if (!credentialResult.error) break;
    if (attempt < upsertAttempts) {
      log("warn", "setup-pin: credential metadata upsert failed, retrying", {
        userId: caller.userId,
        attempt,
      });
      await new Promise((resolve) => setTimeout(resolve, 150 * attempt));
    }
  }
  if (credentialResult.error) {
    // Execution order and why this is still safe even after exhausting
    // retries — see docs/product/authentication.md, "setup-pin
    // consistency":
    //
    // 1. First-time setup (no prior row): no row is ever written before
    //    the Auth password change succeeds, so a failure here leaves
    //    `rpc_has_pin_credential()` correctly reporting `false` — the
    //    client is never told a credential exists when it doesn't. No
    //    partial/broken credential is ever exposed as usable.
    // 2. Recovery (a prior row already exists): the row is left exactly
    //    as it was — still pointing at the same `user_id`, so
    //    `pin-login`'s lookup still succeeds and, because the Auth
    //    password already changed above, the *new* PIN can actually
    //    already sign in (pin-login never reads `credential_version`/
    //    `pin_set_at` for the sign-in step itself, only for lookup and
    //    lockout bookkeeping) — so this is never a lockout either, only
    //    (rarely, after 3 failed attempts) briefly stale bookkeeping
    //    metadata that a later successful `setup-pin` call corrects.
    //
    // Both underlying operations are idempotent (setAuthPassword
    // re-sets the same derived value; upsertCredential is keyed on
    // user_id), so the client reporting this as a retryable failure —
    // never a false success — converges to a fully consistent state
    // either from the retries above or the client's own retry.
    log("error", "setup-pin: auth password updated but credential metadata upsert failed after retries", {
      userId: caller.userId,
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  log("info", "setup-pin: PIN credential set", { userId: caller.userId });
  return jsonResponse({ ok: true }, 200);
}

// Same reasoning as pin-login/index.ts: the Flutter web build
// preflights this cross-origin POST via OPTIONS before ever sending
// the real request. Exported so it is directly unit-testable.
export function serveRequest(req: Request): Response | Promise<Response> {
  if (req.method === "OPTIONS") return corsPreflightResponse();
  return handleRequest(req);
}

if (import.meta.main) {
  Deno.serve(serveRequest);
}
