/**
 * Builds the OTP SMS body. Intentionally minimal — no user name, group
 * name, or other identifying information beyond the code itself, and
 * no upsell/marketing content. This is an authentication message, not
 * a general notification.
 */
export function buildOtpMessage(otp: string): string {
  return `Umoja: Namba yako ya uthibitisho ni ${otp}. Usimpe mtu mwingine namba hii.`;
}
