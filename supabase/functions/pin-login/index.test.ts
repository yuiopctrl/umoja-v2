import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handleRequest } from "./index.ts";

const PEPPER = "test-only-pepper";
const USER_ID = "22222222-2222-2222-2222-222222222222";
const PHONE_RAW = "0712345678";
const PHONE_E164 = "+255712345678";
const FAKE_SESSION = {
  accessToken: "access-token-value",
  refreshToken: "refresh-token-value",
  expiresIn: 3600,
  expiresAt: 1893456000,
  tokenType: "bearer",
};

function request(body: unknown): Request {
  return new Request("https://example.test/pin-login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function fakeDeps(overrides: Partial<Parameters<typeof handleRequest>[1]> = {}) {
  const calls = {
    recordFailure: [] as string[],
    resetFailures: [] as string[],
    signInWithPassword: [] as { phoneE164: string; password: string }[],
  };

  const deps = {
    pinPepper: PEPPER,
    lookupCredential: async (phoneE164: string) => {
      if (phoneE164 !== PHONE_E164) return null;
      return { userId: USER_ID, lockedUntil: null };
    },
    signInWithPassword: async (phoneE164: string, password: string) => {
      calls.signInWithPassword.push({ phoneE164, password });
      // The one and only "correct" PIN for these tests is "1234" —
      // the fake stands in for Supabase Auth's own password check.
      return { session: FAKE_SESSION, error: null };
    },
    recordFailure: async (userId: string) => {
      calls.recordFailure.push(userId);
    },
    resetFailures: async (userId: string) => {
      calls.resetFailures.push(userId);
    },
    ...overrides,
  };

  return { deps, calls };
}

Deno.test("pin-login authenticates with the correct phone + PIN and returns a session", async () => {
  const { deps } = fakeDeps();
  const res = await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }), deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.session.access_token, FAKE_SESSION.accessToken);
  assertEquals(body.session.refresh_token, FAKE_SESSION.refreshToken);
});

Deno.test("pin-login accepts any of the accepted phone input shapes, normalizing before lookup", async () => {
  const { deps } = fakeDeps();
  const res = await handleRequest(request({ phone: "+255712345678", pin: "1234" }), deps);
  assertEquals(res.status, 200);
});

Deno.test("pin-login resets the failure counter on a successful login", async () => {
  const { deps, calls } = fakeDeps();
  await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }), deps);
  assertEquals(calls.resetFailures, [USER_ID]);
  assertEquals(calls.recordFailure, []);
});

Deno.test("pin-login never sends the raw PIN to Supabase Auth — only the derived password", async () => {
  const { deps, calls } = fakeDeps();
  await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }), deps);
  assertEquals(calls.signInWithPassword.length, 1);
  assertEquals(calls.signInWithPassword[0].phoneE164, PHONE_E164);
  assertEquals(calls.signInWithPassword[0].password === "1234", false);
  assertEquals(calls.signInWithPassword[0].password.length > 20, true);
});

Deno.test("pin-login rejects the wrong PIN with a generic error and records the failure", async () => {
  const { deps, calls } = fakeDeps({
    signInWithPassword: async () => ({ session: null, error: "Invalid login credentials" }),
  });
  const res = await handleRequest(request({ phone: PHONE_RAW, pin: "9999" }), deps);
  assertEquals(res.status, 401);
  const body = await res.json();
  assertEquals(body.error.code, "INVALID_CREDENTIALS");
  assertEquals(calls.recordFailure, [USER_ID]);
  assertEquals(calls.resetFailures, []);
});

Deno.test("pin-login returns the identical public failure shape for an unknown phone as for a wrong PIN", async () => {
  const { deps: wrongPinDeps } = fakeDeps({
    signInWithPassword: async () => ({ session: null, error: "Invalid login credentials" }),
  });
  const wrongPinRes = await handleRequest(
    request({ phone: PHONE_RAW, pin: "9999" }),
    wrongPinDeps,
  );

  const { deps: unknownPhoneDeps } = fakeDeps({
    lookupCredential: async () => null,
  });
  const unknownPhoneRes = await handleRequest(
    request({ phone: "0799999999", pin: "1234" }),
    unknownPhoneDeps,
  );

  assertEquals(wrongPinRes.status, unknownPhoneRes.status);
  const wrongPinBody = await wrongPinRes.json();
  const unknownPhoneBody = await unknownPhoneRes.json();
  assertEquals(wrongPinBody, unknownPhoneBody);
});

Deno.test("pin-login returns the same generic failure for a malformed phone or PIN — never revealing which was wrong", async () => {
  const { deps } = fakeDeps();

  const badPhone = await handleRequest(request({ phone: "not a phone", pin: "1234" }), deps);
  const badPin = await handleRequest(request({ phone: PHONE_RAW, pin: "12" }), deps);

  assertEquals(badPhone.status, 401);
  assertEquals(badPin.status, 401);
  assertEquals(await badPhone.json(), await badPin.json());
});

Deno.test("pin-login does not attempt sign-in or increment failures against a locked credential", async () => {
  const future = new Date(Date.now() + 5 * 60_000).toISOString();
  const { deps, calls } = fakeDeps({
    lookupCredential: async () => ({ userId: USER_ID, lockedUntil: future }),
  });

  const res = await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }), deps);

  assertEquals(res.status, 429);
  const body = await res.json();
  assertEquals(body.error.code, "PIN_TEMPORARILY_LOCKED");
  assertEquals(calls.signInWithPassword.length, 0);
  assertEquals(calls.recordFailure.length, 0);
});

Deno.test("pin-login proceeds normally once a lock's expiry has passed", async () => {
  const past = new Date(Date.now() - 60_000).toISOString();
  const { deps } = fakeDeps({
    lookupCredential: async () => ({ userId: USER_ID, lockedUntil: past }),
  });

  const res = await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }), deps);
  assertEquals(res.status, 200);
});

Deno.test("pin-login reports NETWORK_ERROR (not raw internals) when the sign-in call itself throws", async () => {
  const { deps } = fakeDeps({
    signInWithPassword: async () => {
      throw new Error("fetch failed: connection refused");
    },
  });
  const res = await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }), deps);
  assertEquals(res.status, 502);
  const body = await res.json();
  assertEquals(body.error.code, "NETWORK_ERROR");
  assertEquals(JSON.stringify(body).includes("connection refused"), false);
});

Deno.test("pin-login reports SERVER_ERROR when the credential lookup itself fails", async () => {
  const { deps } = fakeDeps({
    lookupCredential: async () => {
      throw new Error("db unavailable");
    },
  });
  const res = await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }), deps);
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error.code, "SERVER_ERROR");
});

Deno.test("pin-login returns SERVER_ERROR (never an unhandled crash) when required server configuration — e.g. PIN_PEPPER — is missing", async () => {
  // No deps injected: forces the real buildDefaultDeps() path, which
  // reads Deno.env — unset in the test environment.
  const res = await handleRequest(request({ phone: PHONE_RAW, pin: "1234" }));
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error.code, "SERVER_ERROR");
  assertEquals(JSON.stringify(body).includes("PIN_PEPPER"), false);
});

Deno.test("pin-login rejects malformed JSON bodies with the same generic response", async () => {
  const req = new Request("https://example.test/pin-login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{not json",
  });
  const { deps } = fakeDeps();
  const res = await handleRequest(req, deps);
  assertEquals(res.status, 401);
  const body = await res.json();
  assertEquals(body.error.code, "INVALID_CREDENTIALS");
});
