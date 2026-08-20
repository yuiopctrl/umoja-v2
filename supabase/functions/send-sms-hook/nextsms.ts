import type { NextSmsConfig } from "./config.ts";

export interface SendOtpParams {
  recipient: string; // bare digits, e.g. "255713676401"
  message: string;
  reference: string;
  config: NextSmsConfig;
  timeoutMs?: number;
}

export interface SendOtpResult {
  ok: boolean;
  status: number;
  bodyText: string;
}

export type FetchLike = (
  input: string | URL,
  init?: RequestInit,
) => Promise<Response>;

/**
 * Sends a single OTP SMS through NextSMS, synchronously (no queueing).
 * `fetchImpl` defaults to the global `fetch` and exists purely so tests
 * can inject a fake instead of making a real network call.
 *
 * Sends `config.authorization` in the `Authorization` header exactly as
 * configured — never prefixed with "Basic "/"Bearer ", per NextSMS's
 * own contract.
 */
export async function sendNextSmsOtp(
  params: SendOtpParams,
  fetchImpl: FetchLike = fetch,
): Promise<SendOtpResult> {
  const { recipient, message, reference, config, timeoutMs = 4000 } = params;
  const url = `${config.baseUrl}${config.singleSmsPath}`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetchImpl(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": config.authorization,
      },
      body: JSON.stringify({
        from: config.senderId,
        to: recipient,
        text: message,
        reference,
      }),
      signal: controller.signal,
    });

    const bodyText = await response.text();
    return { ok: response.ok, status: response.status, bodyText };
  } finally {
    clearTimeout(timeoutId);
  }
}
