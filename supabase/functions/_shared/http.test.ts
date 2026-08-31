import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  corsPreflightResponse,
  errorResponse,
  jsonResponse,
} from "./http.ts";

// These functions are called directly from the Flutter web build
// (Chrome), which enforces CORS on the response and preflights any
// cross-origin POST-with-JSON-body via OPTIONS first. Before this fix,
// none of these responses carried CORS headers, so the browser
// silently discarded every response — a login/PIN-setup attempt from
// Chrome showed "no response" in devtools even though the function
// ran and returned a real body, while native platforms (Android,
// Linux desktop) were entirely unaffected since they don't enforce
// CORS at all.

Deno.test("jsonResponse includes CORS headers on a normal success body", () => {
  const response = jsonResponse({ ok: true }, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals(
    response.headers.get("Access-Control-Allow-Methods"),
    "POST, OPTIONS",
  );
  assertEquals(response.headers.get("Content-Type"), "application/json");
});

Deno.test("errorResponse includes CORS headers too — a Chrome caller must "
  + "see INVALID_CREDENTIALS/PIN_TEMPORARILY_LOCKED/etc, not a blocked "
  + "response indistinguishable from a network failure", () => {
  const response = errorResponse("INVALID_CREDENTIALS", 401);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals(response.status, 401);
});

Deno.test("corsPreflightResponse answers a browser's OPTIONS preflight "
  + "with 204 and the same CORS headers, and no body", async () => {
  const response = corsPreflightResponse();
  assertEquals(response.status, 204);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals(
    response.headers.get("Access-Control-Allow-Headers"),
    "authorization, x-client-info, apikey, content-type",
  );
  assertEquals(await response.text(), "");
});
