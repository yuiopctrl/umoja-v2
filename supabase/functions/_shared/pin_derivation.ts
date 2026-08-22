/**
 * Derives the high-entropy internal Supabase Auth password from a
 * user's 4-digit PIN — prompt 05E §1-2. A raw 4-digit PIN (10,000
 * possible values) is far too weak to use directly as an Auth
 * password; this stretches it into a value that is only ever
 * reproducible by someone who has both the exact PIN *and*
 * PIN_PEPPER (a server-only secret, never present in Flutter — see
 * `docs/product/authentication.md`).
 *
 * `HMAC-SHA256(PIN_PEPPER, "<domain prefix>:<user_id>:<pin>")`,
 * base64-encoded. Deterministic for the same (version, userId, pin,
 * pepper) — required so setup-pin and pin-login independently compute
 * the identical value without ever storing it themselves (Supabase
 * Auth stores its own hash of it via `admin.updateUserById`, which is
 * the only place it is ever persisted). Base64 (not hex) so the result
 * mixes case and includes `+/=` — comfortably satisfies any reasonable
 * Supabase Auth password policy — and its ~44-character length stays
 * well under typical password-hashing length limits (e.g. bcrypt's
 * 72-byte input cap).
 *
 * `credential_version` exists so this derivation can change later
 * (prompt 05E §25) without a complex multi-key rotation system now —
 * see `DOMAIN_PREFIXES` below.
 */
const DOMAIN_PREFIXES: Record<number, string> = {
  1: "umoja-pin-v1",
};

export const CURRENT_CREDENTIAL_VERSION = 1;

export class UnsupportedCredentialVersionError extends Error {
  constructor(version: number) {
    super(`Unsupported PIN credential version: ${version}`);
  }
}

function domainPrefixFor(version: number): string {
  const prefix = DOMAIN_PREFIXES[version];
  if (!prefix) throw new UnsupportedCredentialVersionError(version);
  return prefix;
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/**
 * Derives the internal password for (userId, pin) under
 * `credential_version`. Never logs or returns the PIN or the pepper —
 * callers must not log the return value either.
 */
export async function deriveInternalPassword(
  userId: string,
  pin: string,
  pepper: string,
  credentialVersion: number = CURRENT_CREDENTIAL_VERSION,
): Promise<string> {
  const domainPrefix = domainPrefixFor(credentialVersion);
  const encoder = new TextEncoder();

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const message = encoder.encode(`${domainPrefix}:${userId}:${pin}`);
  const signature = await crypto.subtle.sign("HMAC", key, message);
  return toBase64(new Uint8Array(signature));
}

/** Exactly 4 numeric digits — the only PIN shape ever accepted. */
export const PIN_PATTERN = /^\d{4}$/;

export function isValidPin(pin: unknown): pin is string {
  return typeof pin === "string" && PIN_PATTERN.test(pin);
}
