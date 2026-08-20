import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { toNextSmsRecipient } from "./phone.ts";

// The exact real-world number shape reported from a live Send SMS Hook
// invocation, in both the documented +E.164 form and the bare form the
// live hook turned out to actually be receiving.
Deno.test("toNextSmsRecipient(+255713676401) === 255713676401", () => {
  assertEquals(toNextSmsRecipient("+255713676401"), "255713676401");
});

Deno.test("toNextSmsRecipient(255713676401) === 255713676401", () => {
  assertEquals(toNextSmsRecipient("255713676401"), "255713676401");
});

// Harmless outer whitespace is trimmed before validation, for both
// accepted forms.
Deno.test("toNextSmsRecipient trims harmless outer whitespace", () => {
  assertEquals(toNextSmsRecipient(" +255713676401 "), "255713676401");
  assertEquals(toNextSmsRecipient(" 255713676401 "), "255713676401");
});

Deno.test("toNextSmsRecipient accepts other valid 06/07 Tanzania mobile ranges, +255 form", () => {
  assertEquals(toNextSmsRecipient("+255754123456"), "255754123456");
  assertEquals(toNextSmsRecipient("+255621123456"), "255621123456");
  assertEquals(toNextSmsRecipient("+255682123456"), "255682123456");
});

Deno.test("toNextSmsRecipient accepts other valid 06/07 Tanzania mobile ranges, bare 255 form", () => {
  assertEquals(toNextSmsRecipient("255754123456"), "255754123456");
  assertEquals(toNextSmsRecipient("255621123456"), "255621123456");
  assertEquals(toNextSmsRecipient("255682123456"), "255682123456");
});

Deno.test("toNextSmsRecipient rejects a missing phone number", () => {
  assertThrows(() => toNextSmsRecipient(undefined), Error, "Missing phone number");
  assertThrows(() => toNextSmsRecipient(null), Error, "Missing phone number");
  assertThrows(() => toNextSmsRecipient(""), Error, "Missing phone number");
});

// The hook boundary tolerates +255.../255... but not a local 0-prefixed
// or bare national number — those are still rejected.
Deno.test("toNextSmsRecipient rejects local 07.../bare national forms", () => {
  assertThrows(() => toNextSmsRecipient("0713676401"), Error, "Invalid phone number");
  assertThrows(() => toNextSmsRecipient("713676401"), Error, "Invalid phone number");
});

Deno.test("toNextSmsRecipient rejects a national number that is too short or too long", () => {
  assertThrows(() => toNextSmsRecipient("+25571367640"), Error, "Invalid phone number");
  assertThrows(() => toNextSmsRecipient("2571367640"), Error, "Invalid phone number");
  assertThrows(() => toNextSmsRecipient("+2557136764012"), Error, "Invalid phone number");
  assertThrows(() => toNextSmsRecipient("2557136764012"), Error, "Invalid phone number");
});

Deno.test("toNextSmsRecipient rejects a non-Tanzania country code, both forms", () => {
  assertThrows(() => toNextSmsRecipient("+254713676401"), Error, "Invalid phone number");
  assertThrows(() => toNextSmsRecipient("254713676401"), Error, "Invalid phone number");
});

Deno.test("toNextSmsRecipient rejects a Tanzania number outside the 6/7 mobile range, both forms", () => {
  assertThrows(() => toNextSmsRecipient("+255413676401"), Error, "Invalid phone number");
  assertThrows(() => toNextSmsRecipient("255413676401"), Error, "Invalid phone number");
});

Deno.test("toNextSmsRecipient rejects non-digit content", () => {
  assertThrows(() => toNextSmsRecipient("+255abc676401"), Error, "Invalid phone number");
  assertThrows(() => toNextSmsRecipient("255abc676401"), Error, "Invalid phone number");
});
