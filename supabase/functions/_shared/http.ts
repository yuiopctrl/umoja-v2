/**
 * Shared HTTP response helpers for the PIN auth Edge Functions.
 * Error `code` values are a small, stable, client-mappable set
 * (prompt 05E §40) — never GoTrue internals, SQLSTATEs, stack traces,
 * or secret material.
 */
export function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export type ErrorCode =
  | "UNAUTHORIZED"
  | "INVALID_PIN"
  | "PHONE_NOT_VERIFIED"
  | "INVALID_CREDENTIALS"
  | "PIN_TEMPORARILY_LOCKED"
  | "NETWORK_ERROR"
  | "SERVER_ERROR";

export function errorResponse(code: ErrorCode, status: number): Response {
  return jsonResponse({ error: { code } }, status);
}
