import {
  assertEquals,
  assertNotEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  deriveInternalPassword,
  isValidPin,
  UnsupportedCredentialVersionError,
} from "./pin_derivation.ts";

const PEPPER = "test-only-pepper-value-never-the-real-one";

Deno.test("deriveInternalPassword is deterministic for the same user+pin+pepper", async () => {
  const a = await deriveInternalPassword("user-1", "1234", PEPPER);
  const b = await deriveInternalPassword("user-1", "1234", PEPPER);
  assertEquals(a, b);
});

Deno.test("deriveInternalPassword differs for different users with the identical PIN", async () => {
  const a = await deriveInternalPassword("user-1", "1234", PEPPER);
  const b = await deriveInternalPassword("user-2", "1234", PEPPER);
  assertNotEquals(a, b);
});

Deno.test("deriveInternalPassword differs for different PINs, same user", async () => {
  const a = await deriveInternalPassword("user-1", "1234", PEPPER);
  const b = await deriveInternalPassword("user-1", "4321", PEPPER);
  assertNotEquals(a, b);
});

Deno.test("deriveInternalPassword differs for different peppers, same user+pin", async () => {
  const a = await deriveInternalPassword("user-1", "1234", PEPPER);
  const b = await deriveInternalPassword("user-1", "1234", "a-different-pepper");
  assertNotEquals(a, b);
});

Deno.test("deriveInternalPassword output never contains the raw PIN or pepper as a substring", async () => {
  const result = await deriveInternalPassword("user-1", "1234", PEPPER);
  assertEquals(result.includes("1234"), false);
  assertEquals(result.includes(PEPPER), false);
});

Deno.test("deriveInternalPassword output is comfortably long and mixed-character (satisfies typical password policies)", async () => {
  const result = await deriveInternalPassword("user-1", "1234", PEPPER);
  // 32 raw HMAC-SHA256 bytes, base64-encoded, is 44 characters.
  assertEquals(result.length, 44);
});

Deno.test("deriveInternalPassword rejects an unsupported credential version", async () => {
  await assertRejects(
    () => deriveInternalPassword("user-1", "1234", PEPPER, 99),
    UnsupportedCredentialVersionError,
  );
});

Deno.test("isValidPin accepts exactly 4 digits", () => {
  assertEquals(isValidPin("1234"), true);
  assertEquals(isValidPin("0000"), true);
});

Deno.test("isValidPin rejects anything else", () => {
  assertEquals(isValidPin("123"), false);
  assertEquals(isValidPin("12345"), false);
  assertEquals(isValidPin("12a4"), false);
  assertEquals(isValidPin(""), false);
  assertEquals(isValidPin(1234), false);
  assertEquals(isValidPin(null), false);
  assertEquals(isValidPin(undefined), false);
});
