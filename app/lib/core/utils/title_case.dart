/// Presents a human name in Title Case for display (e.g. "enock
/// godfrey mrema" -> "Enock Godfrey Mrema") — display-only, never
/// applied to the stored value. Splits on whitespace and hyphens,
/// capitalizing the first letter of each word/segment and lowercasing
/// the rest, so already-mixed casing ("fredrick Mrema") normalizes
/// consistently too.
///
/// Never apply this to phone numbers, emails, IDs, member codes, raw
/// enum/API codes, or PIN/OTP/password values — see call sites.
String toTitleCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;

  return trimmed.split(RegExp(r'\s+')).map(_titleCaseWord).join(' ');
}

String _titleCaseWord(String word) {
  return word.split('-').map(_titleCaseSegment).join('-');
}

String _titleCaseSegment(String segment) {
  if (segment.isEmpty) return segment;
  return segment[0].toUpperCase() + segment.substring(1).toLowerCase();
}
