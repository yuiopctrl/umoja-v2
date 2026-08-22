import 'package:flutter/widgets.dart';

/// Wires [controller] to call [onComplete] automatically once its text
/// reaches exactly [length] characters — used for OTP/PIN auto-submit
/// (e.g. 6-digit OTP, 4-digit PIN).
///
/// Fires at most once per distinct value reached, so a failed attempt
/// followed by the user re-entering the *same* digits does not
/// auto-resubmit in a loop; editing to a different value (or clearing
/// and retyping) re-arms it normally. The caller's manual submit path
/// (e.g. a fallback button) remains available and is expected to share
/// the same `isSubmitting`-style guard as the auto path so the two can
/// never both be in flight at once — this class only decides *when* to
/// call [onComplete], not how the caller de-duplicates concurrent calls.
class AutoSubmitOnLength {
  AutoSubmitOnLength({
    required this.controller,
    required this.length,
    required this.onComplete,
  }) {
    controller.addListener(_onChanged);
  }

  final TextEditingController controller;
  final int length;
  final VoidCallback onComplete;

  String? _lastTriggeredValue;

  void _onChanged() {
    final text = controller.text;
    if (text.length == length && text != _lastTriggeredValue) {
      _lastTriggeredValue = text;
      onComplete();
    }
  }

  /// Re-arms auto-submit for the *same* value that just triggered it —
  /// needed when one instance is reused across logically-distinct
  /// steps that legitimately expect the same value twice in a row
  /// (e.g. PIN setup's "enter" then "confirm" step: confirming
  /// correctly means retyping the identical PIN, which must still
  /// auto-submit, not be silently treated as an unchanged no-op).
  void reset() {
    _lastTriggeredValue = null;
  }

  void dispose() {
    controller.removeListener(_onChanged);
  }
}
