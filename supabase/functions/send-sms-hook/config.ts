/** Minimal env-reading interface so config loading is testable without
 * touching real process/Deno environment variables. */
export interface EnvReader {
  get(key: string): string | undefined;
}

export interface NextSmsConfig {
  baseUrl: string;
  singleSmsPath: string;
  authorization: string;
  senderId: string;
}

function requireEnv(env: EnvReader, key: string): string {
  const value = env.get(key);
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

/**
 * Loads and validates the NextSMS provider configuration from
 * environment variables. Never logs or returns anything beyond what
 * was configured — callers must be careful not to log `authorization`.
 *
 * Throws if any required variable is missing, or if
 * NEXTSMS_DEFAULT_SENDER_ID is not present in the comma-separated
 * NEXTSMS_ALLOWED_SENDER_IDS allowlist.
 */
export function loadNextSmsConfig(env: EnvReader = Deno.env): NextSmsConfig {
  const baseUrl = requireEnv(env, "NEXTSMS_BASE_URL");
  const singleSmsPath = requireEnv(env, "NEXTSMS_SINGLE_SMS_PATH");
  const authorization = requireEnv(env, "NEXTSMS_AUTHORIZATION");
  const senderId = requireEnv(env, "NEXTSMS_DEFAULT_SENDER_ID");

  const allowedSenderIds = requireEnv(env, "NEXTSMS_ALLOWED_SENDER_IDS")
    .split(",")
    .map((id) => id.trim())
    .filter((id) => id.length > 0);

  if (!allowedSenderIds.includes(senderId)) {
    throw new Error(
      `NEXTSMS_DEFAULT_SENDER_ID ("${senderId}") is not present in NEXTSMS_ALLOWED_SENDER_IDS`,
    );
  }

  return { baseUrl, singleSmsPath, authorization, senderId };
}

/**
 * Strips the Standard Webhooks `v1,whsec_` prefix from
 * SEND_SMS_HOOK_SECRETS, leaving the base64 secret the `Webhook` class
 * expects. Only that fixed prefix is stripped — never any other
 * transformation of the secret value.
 */
export function loadHookSecret(env: EnvReader = Deno.env): string {
  const raw = requireEnv(env, "SEND_SMS_HOOK_SECRETS");
  const prefix = "v1,whsec_";
  if (!raw.startsWith(prefix)) {
    throw new Error(
      `SEND_SMS_HOOK_SECRETS must start with "${prefix}" (the Standard Webhooks secret format Supabase generates)`,
    );
  }
  return raw.slice(prefix.length);
}
