export type LogLevel = "info" | "warn" | "error";

/**
 * Masks a phone number for safe logging, keeping only the last 4
 * digits, e.g. "+255713676401" -> "*********6401".
 */
export function maskPhone(phone: string): string {
  if (phone.length <= 4) return "*".repeat(phone.length);
  const visible = phone.slice(-4);
  return `${"*".repeat(phone.length - 4)}${visible}`;
}

/**
 * Structured, safe logging. Callers must never pass OTPs, the NextSMS
 * authorization header value, or SEND_SMS_HOOK_SECRETS in `fields` —
 * only masked/derived values (masked phone, HTTP status, duration,
 * reference, error message text).
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
