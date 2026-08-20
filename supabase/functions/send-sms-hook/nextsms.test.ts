import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { NextSmsConfig } from "./config.ts";
import { sendNextSmsOtp } from "./nextsms.ts";

const config: NextSmsConfig = {
  baseUrl: "https://messaging-service.co.tz",
  singleSmsPath: "/api/sms/v1/text/single",
  authorization: "exact-configured-authorization-value",
  senderId: "MICHANGO",
};

Deno.test("sendNextSmsOtp posts from/to/text/reference to the configured NextSMS URL", async () => {
  let capturedUrl: string | undefined;
  let capturedInit: RequestInit | undefined;

  const fakeFetch = (input: string | URL, init?: RequestInit) => {
    capturedUrl = input.toString();
    capturedInit = init;
    return Promise.resolve(new Response("{}", { status: 200 }));
  };

  await sendNextSmsOtp(
    {
      recipient: "255713676401",
      message: "Umoja: Namba yako ya uthibitisho ni 123456. Usimpe mtu mwingine namba hii.",
      reference: "UMOJA-OTP-test-ref",
      config,
    },
    fakeFetch,
  );

  assertEquals(capturedUrl, "https://messaging-service.co.tz/api/sms/v1/text/single");

  const body = JSON.parse(capturedInit?.body as string);
  assertEquals(body, {
    from: "MICHANGO",
    to: "255713676401",
    text: "Umoja: Namba yako ya uthibitisho ni 123456. Usimpe mtu mwingine namba hii.",
    reference: "UMOJA-OTP-test-ref",
  });
});

Deno.test("sendNextSmsOtp sends the configured Authorization header exactly, with no Basic/Bearer prefix", async () => {
  let capturedHeaders: HeadersInit | undefined;

  const fakeFetch = (_input: string | URL, init?: RequestInit) => {
    capturedHeaders = init?.headers;
    return Promise.resolve(new Response("{}", { status: 200 }));
  };

  await sendNextSmsOtp(
    { recipient: "255713676401", message: "x", reference: "r", config },
    fakeFetch,
  );

  const headers = capturedHeaders as Record<string, string>;
  assertEquals(headers["Authorization"], "exact-configured-authorization-value");
  assertFalse(headers["Authorization"].startsWith("Basic "));
  assertFalse(headers["Authorization"].startsWith("Bearer "));
});

Deno.test("sendNextSmsOtp reports ok=true for a 2xx provider response", async () => {
  const fakeFetch = () => Promise.resolve(new Response("{}", { status: 200 }));

  const result = await sendNextSmsOtp(
    { recipient: "255713676401", message: "x", reference: "r", config },
    fakeFetch,
  );

  assertEquals(result.ok, true);
  assertEquals(result.status, 200);
});

Deno.test("sendNextSmsOtp reports ok=false for a non-2xx provider response", async () => {
  const fakeFetch = () =>
    Promise.resolve(new Response('{"error":"invalid sender"}', { status: 400 }));

  const result = await sendNextSmsOtp(
    { recipient: "255713676401", message: "x", reference: "r", config },
    fakeFetch,
  );

  assertEquals(result.ok, false);
  assertEquals(result.status, 400);
});
