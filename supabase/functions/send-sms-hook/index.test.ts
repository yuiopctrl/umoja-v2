import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handleRequest } from "./index.ts";
import type { SendOtpParams, SendOtpResult } from "./nextsms.ts";

// A fixed, valid-base64 test secret — not a real credential. This is
// the base64 encoding of the ASCII string "umoja-test-webhook-secret-not-real".
const TEST_SECRET_B64 = "dW1vamEtdGVzdC13ZWJob29rLXNlY3JldC1ub3QtcmVhbA==";
const TEST_SEND_SMS_HOOK_SECRETS = `v1,whsec_${TEST_SECRET_B64}`;

const NEXTSMS_ENV: Record<string, string> = {
  NEXTSMS_BASE_URL: "https://messaging-service.co.tz",
  NEXTSMS_SINGLE_SMS_PATH: "/api/sms/v1/text/single",
  NEXTSMS_AUTHORIZATION: "test-authorization-value",
  NEXTSMS_DEFAULT_SENDER_ID: "MICHANGO",
  NEXTSMS_ALLOWED_SENDER_IDS: "SHEREHE,MICHANGO,KIKAO",
};

function setTestEnv() {
  Deno.env.set("SEND_SMS_HOOK_SECRETS", TEST_SEND_SMS_HOOK_SECRETS);
  for (const [key, value] of Object.entries(NEXTSMS_ENV)) {
    Deno.env.set(key, value);
  }
}

function clearTestEnv() {
  Deno.env.delete("SEND_SMS_HOOK_SECRETS");
  for (const key of Object.keys(NEXTSMS_ENV)) {
    Deno.env.delete(key);
  }
}

/** Computes a valid Standard Webhooks signature for a test payload,
 * per the public spec: base64-decode the secret, HMAC-SHA256 over
 * `${id}.${timestamp}.${payload}`, base64-encode the result. */
async function signStandardWebhook(
  secretB64: string,
  id: string,
  timestamp: string,
  payload: string,
): Promise<string> {
  const secretBytes = Uint8Array.from(atob(secretB64), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "raw",
    secretBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signedContent = `${id}.${timestamp}.${payload}`;
  const signatureBytes = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signedContent),
  );
  const signatureB64 = btoa(
    String.fromCharCode(...new Uint8Array(signatureBytes)),
  );
  return `v1,${signatureB64}`;
}

async function signedRequest(
  bodyObject: unknown,
  overrides: { id?: string; timestamp?: string; signature?: string } = {},
): Promise<Request> {
  const payload = JSON.stringify(bodyObject);
  const id = overrides.id ?? "msg_test_1";
  const timestamp = overrides.timestamp ?? Math.floor(Date.now() / 1000).toString();
  const signature =
    overrides.signature ?? (await signStandardWebhook(TEST_SECRET_B64, id, timestamp, payload));

  return new Request("http://localhost/send-sms-hook", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "webhook-id": id,
      "webhook-timestamp": timestamp,
      "webhook-signature": signature,
    },
    body: payload,
  });
}

function fakeSendOtp(result: SendOtpResult) {
  const calls: SendOtpParams[] = [];
  const impl = (params: SendOtpParams) => {
    calls.push(params);
    return Promise.resolve(result);
  };
  return { impl, calls };
}

Deno.test({
  name: "a validly signed payload maps user.phone + sms.otp and calls NextSMS with the E.164-stripped recipient",
  fn: async () => {
    setTestEnv();
    try {
      const { impl, calls } = fakeSendOtp({ ok: true, status: 200, bodyText: "{}" });
      const req = await signedRequest({
        user: { phone: "+255713676401" },
        sms: { otp: "654321" },
      });

      const res = await handleRequest(req, { sendOtp: impl });

      assertEquals(res.status, 200);
      assertEquals(await res.json(), {});
      assertEquals(calls.length, 1);
      assertEquals(calls[0].recipient, "255713676401");
      assert(calls[0].message.includes("654321"));
    } finally {
      clearTestEnv();
    }
  },
});

Deno.test({
  name: "an invalid signature is rejected with 401 and NextSMS is never called",
  fn: async () => {
    setTestEnv();
    try {
      const { impl, calls } = fakeSendOtp({ ok: true, status: 200, bodyText: "{}" });
      const req = await signedRequest(
        { user: { phone: "+255713676401" }, sms: { otp: "654321" } },
        { signature: "v1,thisIsNotAValidSignature==" },
      );

      const res = await handleRequest(req, { sendOtp: impl });
      const body = await res.json();

      assertEquals(res.status, 401);
      assertEquals(body.error.http_code, 401);
      assertEquals(calls.length, 0);
    } finally {
      clearTestEnv();
    }
  },
});

Deno.test({
  name: "a missing phone number fails with 400 and NextSMS is never called",
  fn: async () => {
    setTestEnv();
    try {
      const { impl, calls } = fakeSendOtp({ ok: true, status: 200, bodyText: "{}" });
      const req = await signedRequest({ user: {}, sms: { otp: "654321" } });

      const res = await handleRequest(req, { sendOtp: impl });

      assertEquals(res.status, 400);
      assertEquals(calls.length, 0);
    } finally {
      clearTestEnv();
    }
  },
});

Deno.test({
  name: "a missing OTP fails with 400 and NextSMS is never called",
  fn: async () => {
    setTestEnv();
    try {
      const { impl, calls } = fakeSendOtp({ ok: true, status: 200, bodyText: "{}" });
      const req = await signedRequest({ user: { phone: "+255713676401" }, sms: {} });

      const res = await handleRequest(req, { sendOtp: impl });

      assertEquals(res.status, 400);
      assertEquals(calls.length, 0);
    } finally {
      clearTestEnv();
    }
  },
});

Deno.test({
  name: "a non-2xx NextSMS response becomes a 502 hook failure without leaking provider details",
  fn: async () => {
    setTestEnv();
    try {
      const { impl } = fakeSendOtp({
        ok: false,
        status: 400,
        bodyText: '{"error":"invalid sender id","secret_debug":"should-never-appear"}',
      });
      const req = await signedRequest({
        user: { phone: "+255713676401" },
        sms: { otp: "654321" },
      });

      const res = await handleRequest(req, { sendOtp: impl });
      const bodyText = await res.text();

      assertEquals(res.status, 502);
      assert(!bodyText.includes("secret_debug"));
      assert(!bodyText.includes("invalid sender id"));
      assertEquals(JSON.parse(bodyText).error.http_code, 502);
    } finally {
      clearTestEnv();
    }
  },
});

Deno.test({
  name: "provider/webhook secrets never appear in any response body",
  fn: async () => {
    setTestEnv();
    try {
      const { impl } = fakeSendOtp({ ok: true, status: 200, bodyText: "{}" });

      // Success path.
      const okReq = await signedRequest({
        user: { phone: "+255713676401" },
        sms: { otp: "654321" },
      });
      const okRes = await handleRequest(okReq, { sendOtp: impl });
      const okBody = await okRes.text();
      assert(!okBody.includes(NEXTSMS_ENV.NEXTSMS_AUTHORIZATION));
      assert(!okBody.includes(TEST_SECRET_B64));

      // Invalid-signature path.
      const badReq = await signedRequest(
        { user: { phone: "+255713676401" }, sms: { otp: "654321" } },
        { signature: "v1,invalid==" },
      );
      const badRes = await handleRequest(badReq, { sendOtp: impl });
      const badBody = await badRes.text();
      assert(!badBody.includes(NEXTSMS_ENV.NEXTSMS_AUTHORIZATION));
      assert(!badBody.includes(TEST_SECRET_B64));
    } finally {
      clearTestEnv();
    }
  },
});
