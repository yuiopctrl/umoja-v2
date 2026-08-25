import 'package:intl/intl.dart';

/// Display-only amount formatting (e.g. `12000` -> "12,000",
/// `12000.5` -> "12,000.5") — grouped thousands, no currency symbol
/// (no currency concept exists yet in the data model). Never used for
/// any authoritative calculation; amounts are always computed/validated
/// server-side and simply passed through here for display or as a
/// direct RPC parameter.
final _wholeFormat = NumberFormat('#,##0');
final _decimalFormat = NumberFormat('#,##0.##');

String formatAmount(num value) {
  return value == value.roundToDouble()
      ? _wholeFormat.format(value)
      : _decimalFormat.format(value);
}
