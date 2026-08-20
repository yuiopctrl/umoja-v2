/**
 * Converts a Tanzania mobile phone identity into the bare-digit
 * recipient format NextSMS expects ("255713676401"). Throws a plain
 * `Error` with a safe message for anything that is not a well-formed
 * Tanzanian mobile number — never throws on/logs the phone value
 * itself beyond what the caller chooses to log.
 *
 * Supabase's own docs illustrate `user.phone` as +E.164
 * ("+255713676401"), but a live hook invocation showed the value can
 * actually arrive without the leading "+" ("255713676401") — both
 * unambiguously identify the same Tanzania number, so this adapter
 * accepts either form at the hook boundary and normalizes both to the
 * bare form NextSMS wants. Local "071..."/bare-national "71..." forms
 * are still rejected here — this hook boundary only tolerates the two
 * country-code-qualified shapes above, not a bare national number.
 * Confirmed correct against a real live Send SMS Hook invocation
 * end to end (OTP delivered, verified, session/context/first-group
 * creation all succeeded) — see docs/product/authentication.md.
 *
 * A Tanzania mobile number is a country code (255) followed by exactly
 * 9 national digits, where the national number starts with 6 or 7 (the
 * mobile destination ranges — 06.../07... nationally). Landline
 * ranges, other country codes, and malformed lengths are all rejected
 * before ever reaching NextSMS.
 *
 * IMPORTANT: these are genuine regex *literals* (`/.../`), not
 * `new RegExp("...")` strings, specifically so `\d` never needs
 * double-escaping. A string-built regex would require `"\\d"`; writing
 * that as `"\d"` in a literal (`/\\d/`) would search for a literal
 * backslash followed by the letter "d" instead of a digit class — a
 * classic and easy-to-introduce escaping bug. Confirmed by inspection
 * that this file does not have that bug (a single backslash before
 * each `d`, not two).
 */
const TANZANIA_MOBILE_E164_PATTERN = /^\+255[67]\d{8}$/;
const TANZANIA_MOBILE_BARE_PATTERN = /^255[67]\d{8}$/;

export function toNextSmsRecipient(phone: string | null | undefined): string {
  if (!phone || phone.trim().length === 0) {
    throw new Error("Missing phone number");
  }

  const normalized = phone.trim();

  if (TANZANIA_MOBILE_E164_PATTERN.test(normalized)) {
    // Only the leading "+" is stripped — the country code is kept,
    // and no leading zero is added.
    return normalized.slice(1);
  }

  if (TANZANIA_MOBILE_BARE_PATTERN.test(normalized)) {
    return normalized;
  }

  throw new Error("Invalid phone number format");
}
