/// Restrained, masked display of a phone number (e.g. `+255 •••• 678`)
/// — enough for a user to recognize which account they're looking at,
/// without showing the full number. Used on the PIN unlock and PIN
/// recovery screens (prompt 05C §5/§18).
String? maskedPhone(String? e164) {
  if (e164 == null || e164.length < 4) return e164;
  final visible = e164.substring(e164.length - 3);
  final prefix = e164.length > 7 ? e164.substring(0, e164.length - 7) : '';
  return '$prefix •••• $visible';
}
