// pin-login — prompt 05E §8. Public Edge Function: the normal
// returning-login mechanism, phone + 4-digit PIN, no OTP. Verified by
// genuine Supabase Auth (phone + a derived password), never faked with
// service-role authority — the service-role client here is used only
// for the private credential lookup and rate-limit/lockout
// bookkeeping (§9). Never reveals whether a phone number has an
// account, whether a PIN is configured, or (beyond the distinct
// "temporarily locked" case, §22/§40) why a login attempt failed.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { loadPinPepper, loadSupabaseEnvConfig } from "../_shared/config.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { log, maskPhone } from "../_shared/logger.ts";
import { normalizeTanzaniaPhone } from "../_shared/phone.ts";
import {
  CURRENT_CREDENTIAL_VERSION,
  deriveInternalPassword,
  isValidPin,
} from "../_shared/pin_derivation.ts";

interface PinLoginRequestBody {
  phone?: unknown;
  pin?: unknown;
}

interface CredentialLookup {
  userId: string;
  lockedUntil: string | null;
}

interface SessionPayload {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  expiresAt: number | null;
  tokenType: string;
}

interface HandleRequestDeps {
  pinPepper?: string;
  lookupCredential?: (phoneE164: string) => Promise<CredentialLookup | null>;
  signInWithPassword?: (
    phoneE164: string,
    password: string,
  ) => Promise<{ session: SessionPayload | null; error: string | null }>;
  recordFailure?: (userId: string) => Promise<void>;
  resetFailures?: (userId: string) => Promise<void>;
}

function isLocked(lockedUntil: string | null): boolean {
  if (!lockedUntil) return false;
  return new Date(lockedUntil).getTime() > Date.now();
}

function buildDefaultDeps(): Required<Omit<HandleRequestDeps, "pinPepper">> & {
  pinPepper: string;
} {
  const env = loadSupabaseEnvConfig();
  const pinPepper = loadPinPepper();

  const anonClient = createClient(env.url, env.anonKey);
  const adminClient = createClient(env.url, env.serviceRoleKey);

  return {
    pinPepper,
    lookupCredential: async (phoneE164) => {
      const { data, error } = await adminClient
        .from("user_pin_credentials")
        .select("user_id, locked_until")
        .eq("phone_e164", phoneE164)
        .maybeSingle();
      if (error || !data) return null;
      return { userId: data.user_id as string, lockedUntil: data.locked_until as string | null };
    },
    signInWithPassword: async (phoneE164, password) => {
      const { data, error } = await anonClient.auth.signInWithPassword({
        phone: phoneE164,
        password,
      });
      if (error || !data.session) {
        return { session: null, error: error ? error.message : "no session" };
      }
      const s = data.session;
      return {
        session: {
          accessToken: s.access_token,
          refreshToken: s.refresh_token,
          expiresIn: s.expires_in,
          expiresAt: s.expires_at ?? null,
          tokenType: s.token_type,
        },
        error: null,
      };
    },
    recordFailure: async (userId) => {
      await adminClient.rpc("record_pin_login_failure", { p_user_id: userId });
    },
    resetFailures: async (userId) => {
      await adminClient.rpc("reset_pin_login_failures", { p_user_id: userId });
    },
  };
}

export async function handleRequest(
  req: Request,
  deps: HandleRequestDeps = {},
): Promise<Response> {
  log("info", "pin-login: request received");

  let defaults: ReturnType<typeof buildDefaultDeps> | null;
  try {
    defaults =
      deps.lookupCredential && deps.signInWithPassword && deps.recordFailure &&
        deps.resetFailures && deps.pinPepper
        ? null
        : buildDefaultDeps();
  } catch (error) {
    // See setup-pin/index.ts's identical guard — most commonly a
    // missing/misconfigured secret; never a raw crash.
    log("error", "pin-login: server misconfigured", {
      reason: error instanceof Error ? error.message : "unknown",
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  const lookupCredential = deps.lookupCredential ?? defaults!.lookupCredential;
  const signInWithPassword = deps.signInWithPassword ?? defaults!.signInWithPassword;
  const recordFailure = deps.recordFailure ?? defaults!.recordFailure;
  const resetFailures = deps.resetFailures ?? defaults!.resetFailures;
  const pinPepper = deps.pinPepper ?? defaults!.pinPepper;

  let body: PinLoginRequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("INVALID_CREDENTIALS", 401);
  }

  const phoneE164 = typeof body.phone === "string" ? normalizeTanzaniaPhone(body.phone) : null;
  const pinOk = isValidPin(body.pin);

  // Malformed input gets exactly the same generic response as a wrong
  // credential — prompt 05E §22/§36: never reveal *why* a login
  // attempt failed beyond the distinct lockout case below.
  if (!phoneE164 || !pinOk) {
    log("warn", "pin-login: malformed request");
    return errorResponse("INVALID_CREDENTIALS", 401);
  }
  const pin = body.pin as string;

  let credential: CredentialLookup | null;
  try {
    credential = await lookupCredential(phoneE164);
  } catch (error) {
    log("error", "pin-login: credential lookup failed", {
      reason: error instanceof Error ? error.message : "unknown",
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  if (!credential) {
    // Unknown phone AND "no PIN credential for a known phone" both
    // land here, indistinguishably — prompt 05E §22.
    log("info", "pin-login: no credential for phone", { phone: maskPhone(phoneE164) });
    return errorResponse("INVALID_CREDENTIALS", 401);
  }

  if (isLocked(credential.lockedUntil)) {
    log("info", "pin-login: attempt against a locked credential", {
      userId: credential.userId,
    });
    return errorResponse("PIN_TEMPORARILY_LOCKED", 429);
  }

  let derivedPassword: string;
  try {
    derivedPassword = await deriveInternalPassword(
      credential.userId,
      pin,
      pinPepper,
      CURRENT_CREDENTIAL_VERSION,
    );
  } catch (error) {
    log("error", "pin-login: password derivation failed", {
      reason: error instanceof Error ? error.message : "unknown",
      userId: credential.userId,
    });
    return errorResponse("SERVER_ERROR", 500);
  }

  let signInResult: { session: SessionPayload | null; error: string | null };
  try {
    signInResult = await signInWithPassword(phoneE164, derivedPassword);
  } catch (error) {
    log("error", "pin-login: sign-in call failed unexpectedly", {
      reason: error instanceof Error ? error.message : "unknown",
      userId: credential.userId,
    });
    return errorResponse("NETWORK_ERROR", 502);
  }

  if (!signInResult.session) {
    // A wrong PIN and any other Supabase Auth password-verification
    // failure both land here — the specific GoTrue error is logged
    // (not the derived password itself) but never returned.
    log("info", "pin-login: password verification failed (wrong PIN)", {
      userId: credential.userId,
    });
    try {
      await recordFailure(credential.userId);
    } catch (error) {
      log("error", "pin-login: failed to record failed attempt", {
        reason: error instanceof Error ? error.message : "unknown",
        userId: credential.userId,
      });
    }
    return errorResponse("INVALID_CREDENTIALS", 401);
  }

  try {
    await resetFailures(credential.userId);
  } catch (error) {
    // The session is already genuinely valid at this point — a failure
    // to reset the counter must not fail the login itself.
    log("error", "pin-login: failed to reset failure counter after success", {
      reason: error instanceof Error ? error.message : "unknown",
      userId: credential.userId,
    });
  }

  log("info", "pin-login: successful login", { userId: credential.userId });
  const session = signInResult.session;
  return jsonResponse(
    {
      session: {
        access_token: session.accessToken,
        refresh_token: session.refreshToken,
        expires_in: session.expiresIn,
        expires_at: session.expiresAt,
        token_type: session.tokenType,
      },
    },
    200,
  );
}

if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
