export type LogLevel = "info" | "warn" | "error";

/**
 * Masks a phone number for safe logging, keeping only the last 4
 * digits, e.g. "+255713676401" -> "*********6401" — same convention
 * as `send-sms-hook/logger.ts`.
 */
export function maskPhone(phone: string): string {
  if (phone.length <= 4) return "*".repeat(phone.length);
  const visible = phone.slice(-4);
  return `${"*".repeat(phone.length - 4)}${visible}`;
}

/**
 * Structured, safe logging (prompt 05E §41). Callers must never pass
 * a PIN, a derived internal password, an access/refresh token, an
 * Authorization header value, or PIN_PEPPER in `fields` — only masked/
 * derived values (masked phone, a resolved user id, outcome category,
 * duration, correlation id).
 */
export function log(
  level: LogLevel,
  message: string,
  fields: Record<string, unknown> = {},
): void {
  const entry = { level, message, ...fields, ts: new Date().toISOString() };
  const line = JSON.stringify(entry);
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else console.log(line);
}
