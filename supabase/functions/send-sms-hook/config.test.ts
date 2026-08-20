import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { EnvReader, loadHookSecret, loadNextSmsConfig } from "./config.ts";

function fakeEnv(values: Record<string, string>): EnvReader {
  return { get: (key: string) => values[key] };
}

const validNextSmsEnv = {
  NEXTSMS_BASE_URL: "https://messaging-service.co.tz",
  NEXTSMS_SINGLE_SMS_PATH: "/api/sms/v1/text/single",
  NEXTSMS_AUTHORIZATION: "test-authorization-value",
  NEXTSMS_DEFAULT_SENDER_ID: "MICHANGO",
  NEXTSMS_ALLOWED_SENDER_IDS: "SHEREHE,MICHANGO,KIKAO",
};

Deno.test("loadNextSmsConfig accepts a valid, allow-listed configuration", () => {
  const config = loadNextSmsConfig(fakeEnv(validNextSmsEnv));
  assertEquals(config.senderId, "MICHANGO");
  assertEquals(config.baseUrl, "https://messaging-service.co.tz");
  assertEquals(config.singleSmsPath, "/api/sms/v1/text/single");
  assertEquals(config.authorization, "test-authorization-value");
});

Deno.test("loadNextSmsConfig rejects a default sender id not in the allowlist", () => {
  assertThrows(
    () =>
      loadNextSmsConfig(
        fakeEnv({ ...validNextSmsEnv, NEXTSMS_DEFAULT_SENDER_ID: "NOT_ALLOWED" }),
      ),
    Error,
    "NEXTSMS_ALLOWED_SENDER_IDS",
  );
});

Deno.test("loadNextSmsConfig rejects a missing required variable", () => {
  const { NEXTSMS_AUTHORIZATION: _omit, ...rest } = validNextSmsEnv;
  assertThrows(
    () => loadNextSmsConfig(fakeEnv(rest)),
    Error,
    "NEXTSMS_AUTHORIZATION",
  );
});

Deno.test("loadHookSecret strips only the leading v1,whsec_ prefix", () => {
  const secret = loadHookSecret(
    fakeEnv({ SEND_SMS_HOOK_SECRETS: "v1,whsec_abc123==" }),
  );
  assertEquals(secret, "abc123==");
});

Deno.test("loadHookSecret rejects a value without the expected prefix", () => {
  assertThrows(
    () => loadHookSecret(fakeEnv({ SEND_SMS_HOOK_SECRETS: "not-the-right-format" })),
    Error,
    "v1,whsec_",
  );
});
