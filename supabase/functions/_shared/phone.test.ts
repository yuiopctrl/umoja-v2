import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { normalizeTanzaniaPhone } from "./phone.ts";

Deno.test("normalizeTanzaniaPhone accepts a leading-zero local number", () => {
  assertEquals(normalizeTanzaniaPhone("0712345678"), "+255712345678");
});

Deno.test("normalizeTanzaniaPhone accepts a bare national number", () => {
  assertEquals(normalizeTanzaniaPhone("712345678"), "+255712345678");
});

Deno.test("normalizeTanzaniaPhone accepts a bare 255-prefixed number", () => {
  assertEquals(normalizeTanzaniaPhone("255712345678"), "+255712345678");
});

Deno.test("normalizeTanzaniaPhone accepts +255 E.164 form", () => {
  assertEquals(normalizeTanzaniaPhone("+255712345678"), "+255712345678");
});

Deno.test("normalizeTanzaniaPhone strips benign spaces/hyphens/parentheses", () => {
  assertEquals(normalizeTanzaniaPhone("+255 712 345 678"), "+255712345678");
  assertEquals(normalizeTanzaniaPhone("0712-345-678"), "+255712345678");
  assertEquals(normalizeTanzaniaPhone("(0712) 345678"), "+255712345678");
});

Deno.test("normalizeTanzaniaPhone accepts the 6-prefixed mobile range too", () => {
  assertEquals(normalizeTanzaniaPhone("0612345678"), "+255612345678");
});

Deno.test("normalizeTanzaniaPhone rejects empty/whitespace-only input", () => {
  assertEquals(normalizeTanzaniaPhone(""), null);
  assertEquals(normalizeTanzaniaPhone("   "), null);
  assertEquals(normalizeTanzaniaPhone(null), null);
  assertEquals(normalizeTanzaniaPhone(undefined), null);
});

Deno.test("normalizeTanzaniaPhone rejects non-digit content", () => {
  assertEquals(normalizeTanzaniaPhone("071234abcd"), null);
});

Deno.test("normalizeTanzaniaPhone rejects a landline range (not 6/7)", () => {
  assertEquals(normalizeTanzaniaPhone("0812345678"), null);
});

Deno.test("normalizeTanzaniaPhone rejects the wrong subscriber length", () => {
  assertEquals(normalizeTanzaniaPhone("07123456"), null);
  assertEquals(normalizeTanzaniaPhone("071234567890"), null);
});

Deno.test("normalizeTanzaniaPhone rejects a non-Tanzania country code in +E.164 form", () => {
  assertEquals(normalizeTanzaniaPhone("+254712345678"), null);
});

Deno.test("normalizeTanzaniaPhone output is always the canonical +255XXXXXXXXX shape", () => {
  const result = normalizeTanzaniaPhone("0712345678")!;
  assertEquals(/^\+255[67]\d{8}$/.test(result), true);
});
