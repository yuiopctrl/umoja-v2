import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { deriveInternalPassword } from "../_shared/pin_derivation.ts";
import { handleRequest, serveRequest } from "./index.ts";

const PEPPER = "test-only-pepper";
const USER_ID = "11111111-1111-1111-1111-111111111111";
const PHONE = "+255712345678";

function request(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("https://example.test/setup-pin", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

function fakeDeps(overrides: Partial<Parameters<typeof handleRequest>[1]> = {}) {
  const calls = {
    setAuthPassword: [] as { userId: string; password: string }[],
    upsertCredential: [] as {
      userId: string;
      phoneE164: string;
      credentialVersion: number;
    }[],
  };

  const deps = {
    pinPepper: PEPPER,
    resolveCaller: async (authorizationHeader: string) => {
      if (authorizationHeader !== "Bearer valid-token") return null;
      return { userId: USER_ID, phone: PHONE, phoneConfirmed: true };
    },
    setAuthPassword: async (userId: string, password: string) => {
      calls.setAuthPassword.push({ userId, password });
      return { error: null };
    },
    upsertCredential: async (params: {
      userId: string;
      phoneE164: string;
      credentialVersion: number;
    }) => {
      calls.upsertCredential.push(params);
      return { error: null };
    },
    ...overrides,
  };

  return { deps, calls };
}

Deno.test("setup-pin rejects a request with no Authorization header", async () => {
  const { deps } = fakeDeps();
  const res = await handleRequest(request({ pin: "1234" }), deps);
  assertEquals(res.status, 401);
  const body = await res.json();
  assertEquals(body.error.code, "UNAUTHORIZED");
});

Deno.test("setup-pin rejects a request whose bearer token does not resolve to a user", async () => {
  const { deps } = fakeDeps();
  const res = await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer garbage" }),
    deps,
  );
  assertEquals(res.status, 401);
  const body = await res.json();
  assertEquals(body.error.code, "UNAUTHORIZED");
});

Deno.test("setup-pin rejects a non-4-digit PIN", async () => {
  const { deps, calls } = fakeDeps();
  for (const badPin of ["123", "12345", "12a4", "", "abcd"]) {
    const res = await handleRequest(
      request({ pin: badPin }, { Authorization: "Bearer valid-token" }),
      deps,
    );
    assertEquals(res.status, 400, `expected 400 for pin=${badPin}`);
    const body = await res.json();
    assertEquals(body.error.code, "INVALID_PIN");
  }
  assertEquals(calls.setAuthPassword.length, 0);
  assertEquals(calls.upsertCredential.length, 0);
});

Deno.test("setup-pin rejects a caller with no verified phone", async () => {
  const { deps } = fakeDeps({
    resolveCaller: async () => ({
      userId: USER_ID,
      phone: PHONE,
      phoneConfirmed: false,
    }),
  });
  const res = await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );
  assertEquals(res.status, 403);
  const body = await res.json();
  assertEquals(body.error.code, "PHONE_NOT_VERIFIED");
});

Deno.test("setup-pin never has any code path to include the raw PIN in the credential upsert (by construction — upsertCredential's params carry no PIN field at all)", async () => {
  const { deps, calls } = fakeDeps();
  await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );
  assertEquals(calls.upsertCredential.length, 1);
  const params = calls.upsertCredential[0] as Record<string, unknown>;
  // Only these three keys are ever passed — asserted by exact key set
  // rather than substring-searching the serialized value, since the
  // phone number itself legitimately contains digit sequences that can
  // coincidentally overlap with a 4-digit PIN (not a leak — the phone
  // number is not secret).
  assertEquals(Object.keys(params).sort(), [
    "credentialVersion",
    "phoneE164",
    "userId",
  ]);
});

Deno.test("setup-pin sets the Supabase Auth password to the deterministic derived value, never the raw PIN", async () => {
  const { deps, calls } = fakeDeps();
  await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );

  const expected = await deriveInternalPassword(USER_ID, "1234", PEPPER, 1);
  assertEquals(calls.setAuthPassword.length, 1);
  assertEquals(calls.setAuthPassword[0].userId, USER_ID);
  assertEquals(calls.setAuthPassword[0].password, expected);
  assertNotEquals(calls.setAuthPassword[0].password, "1234");
});

Deno.test("setup-pin upserts credential metadata for the authenticated user with the normalized phone and current version", async () => {
  const { deps, calls } = fakeDeps();
  await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );

  assertEquals(calls.upsertCredential, [
    { userId: USER_ID, phoneE164: PHONE, credentialVersion: 1 },
  ]);
});

Deno.test("setup-pin succeeds with a generic ok body — never the PIN or the derived password", async () => {
  const { deps } = fakeDeps();
  const res = await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body, { ok: true });
});

Deno.test("setup-pin reports SERVER_ERROR (not a raw internals leak) when the Auth password update fails", async () => {
  const { deps } = fakeDeps({
    setAuthPassword: async () => ({ error: "gotrue: some internal detail" }),
  });
  const res = await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error.code, "SERVER_ERROR");
  assertEquals(JSON.stringify(body).includes("gotrue"), false);
});

Deno.test("setup-pin reports SERVER_ERROR when the credential upsert keeps failing after retries", async () => {
  let attempts = 0;
  const { deps } = fakeDeps({
    upsertCredential: async () => {
      attempts++;
      return { error: "some db error" };
    },
  });
  const res = await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error.code, "SERVER_ERROR");
  assertEquals(attempts, 3, "gives up only after 3 attempts, not on the first failure");
});

Deno.test("setup-pin retries a transient credential-upsert failure and succeeds without re-deriving/re-setting the password", async () => {
  let attempts = 0;
  const { deps, calls } = fakeDeps({
    upsertCredential: async (params) => {
      attempts++;
      if (attempts < 3) return { error: "transient db error" };
      calls.upsertCredential.push(params);
      return { error: null };
    },
  });
  const res = await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
    deps,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body, { ok: true });
  assertEquals(attempts, 3);
  // setAuthPassword itself is not retried by this loop — it already
  // succeeded once, and only the metadata write is retried.
  assertEquals(calls.setAuthPassword.length, 1);
});

Deno.test("setup-pin returns SERVER_ERROR (never an unhandled crash) when required server configuration — e.g. PIN_PEPPER — is missing, since it was never set via `supabase secrets set`", async () => {
  // No deps injected at all: forces the real buildDefaultDeps() path,
  // which reads Deno.env — unset in the test environment, so this
  // reproduces exactly the failure mode a not-yet-configured deployment
  // hits (prompt 05E-A root cause).
  const res = await handleRequest(
    request({ pin: "1234" }, { Authorization: "Bearer valid-token" }),
  );
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error.code, "SERVER_ERROR");
  assertEquals(JSON.stringify(body).includes("PIN_PEPPER"), false);
});

Deno.test("setup-pin rejects malformed JSON bodies safely", async () => {
  const { deps } = fakeDeps();
  const req = new Request("https://example.test/setup-pin", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer valid-token" },
    body: "{not json",
  });
  const res = await handleRequest(req, deps);
  assertEquals(res.status, 400);
});

Deno.test("serveRequest answers an OPTIONS preflight with 204 and CORS headers, without ever reaching handleRequest (no Authorization header is required)", async () => {
  const req = new Request("https://example.test/setup-pin", {
    method: "OPTIONS",
  });
  const res = await serveRequest(req);
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("serveRequest forwards a real POST to handleRequest, and the "
  + "response — whatever it is — still carries CORS headers a browser "
  + "needs in order to read it at all", async () => {
  const req = request({ pin: "1234" }, { Authorization: "Bearer valid-token" });
  const res = await serveRequest(req);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});
