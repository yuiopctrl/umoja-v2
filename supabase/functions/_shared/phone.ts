/**
 * Tanzania mobile phone normalization for the setup-pin/pin-login Edge
 * Functions — the server-side mirror of
 * `app/lib/core/utils/tanzania_phone_number.dart`'s `TanzaniaPhoneNumber.parse`.
 * Deliberately the *same* accepted-input rules and canonical output
 * (`+255XXXXXXXXX`) as the Flutter client (prompt 05E §5: "do not
 * create a second incompatible phone normalizer") — this is a
 * reimplementation in TypeScript (Dart code cannot run in Deno), not a
 * different set of rules. Keep both in sync if either changes.
 *
 * Accepts (after stripping spaces/hyphens/parentheses): `0712345678`,
 * `712345678`, `255712345678`, `+255712345678`. Only mobile numbers
 * (subscriber number starting with 6 or 7) are accepted. Returns
 * `null` for anything else — callers must not distinguish "malformed
 * input" from "wrong credentials" in any response (prompt 05E §22).
 */
const COUNTRY_CODE = "255";
const SUBSCRIBER_LENGTH = 9;
const FORMATTING_CHARS_PATTERN = /[\s\-()]/g;
const DIGITS_ONLY_PATTERN = /^\d+$/;

export function normalizeTanzaniaPhone(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;

  const stripped = trimmed.replace(FORMATTING_CHARS_PATTERN, "");
  const hasPlus = stripped.startsWith("+");
  const digits = hasPlus ? stripped.slice(1) : stripped;

  if (digits.length === 0 || !DIGITS_ONLY_PATTERN.test(digits)) {
    return null;
  }

  let subscriberNumber: string;
  if (hasPlus) {
    if (!digits.startsWith(COUNTRY_CODE)) return null;
    subscriberNumber = digits.slice(COUNTRY_CODE.length);
  } else if (
    digits.startsWith(COUNTRY_CODE) &&
    digits.length === COUNTRY_CODE.length + SUBSCRIBER_LENGTH
  ) {
    subscriberNumber = digits.slice(COUNTRY_CODE.length);
  } else if (digits.startsWith("0")) {
    subscriberNumber = digits.slice(1);
  } else {
    subscriberNumber = digits;
  }

  if (subscriberNumber.length !== SUBSCRIBER_LENGTH) return null;
  if (!subscriberNumber.startsWith("6") && !subscriberNumber.startsWith("7")) {
    return null;
  }

  return `+${COUNTRY_CODE}${subscriberNumber}`;
}
