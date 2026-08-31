/**
 * Shared HTTP response helpers for the PIN auth Edge Functions.
 * Error `code` values are a small, stable, client-mappable set
 * (prompt 05E §40) — never GoTrue internals, SQLSTATEs, stack traces,
 * or secret material.
 *
 * CORS: these functions are called directly from the Flutter web
 * build (Chrome), not only from native platforms — a browser enforces
 * CORS on the response (and preflights any cross-origin POST with a
 * JSON body via an OPTIONS request first), while native HTTP clients
 * do not. Every response must carry these headers, and every
 * function's `Deno.serve` entry point must short-circuit an OPTIONS
 * request before it ever reaches `handleRequest` — see
 * `corsPreflightResponse()`.
 */
export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export function corsPreflightResponse(): Response {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
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
