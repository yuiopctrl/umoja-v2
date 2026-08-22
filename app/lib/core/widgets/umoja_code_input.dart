import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/umoja_colors.dart';
import '../theme/umoja_radius.dart';
import '../theme/umoja_spacing.dart';

/// A boxed, digit-style numeric code entry — one bordered box per
/// digit, filled with an obscured dot as it's typed — replacing a
/// long generic [TextField] for PIN/OTP entry (prompt 05E §5: "prefer
/// a 4-digit PIN input UX (boxed/digit-style)").
///
/// Never reveals the actual digit, matching every other PIN surface in
/// this app (`obscureText`-equivalent) — a filled box shows a dot, not
/// the number. Real keyboard/SMS-autofill input is captured by an
/// invisible [TextField] sized to exactly cover the visible boxes
/// (tap-to-focus anywhere on the row still works), driven by the same
/// external [controller] every existing PIN/OTP screen already owns —
/// so this is a drop-in visual replacement, not a rework of the
/// controller/auto-submit plumbing (`AutoSubmitOnLength` etc.) those
/// screens already use.
class UmojaCodeInput extends StatefulWidget {
  const UmojaCodeInput({
    super.key,
    required this.controller,
    required this.length,
    this.enabled = true,
    this.autofocus = false,
    this.hasError = false,
    this.onSubmitted,
    this.isOneTimeCode = false,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool autofocus;
  final bool hasError;
  final ValueChanged<String>? onSubmitted;

  /// Set only by SMS-OTP screens — never the 4-digit login/setup PIN
  /// (that is never eligible for OS-level autofill; see
  /// `docs/product/authentication.md`, "OTP SMS autofill"). Applies
  /// [AutofillHints.oneTimeCode] to the underlying field so iOS can
  /// offer the code it received above the keyboard — the native,
  /// plugin-free counterpart to Android's `smart_auth`-driven
  /// SMS User Consent listener.
  final bool isOneTimeCode;

  @override
  State<UmojaCodeInput> createState() => _UmojaCodeInputState();
}

class _UmojaCodeInputState extends State<UmojaCodeInput> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = UmojaSpacing.sm;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adaptive box width: fits any [length] within the available
        // width (never overflows on a narrow phone with a 6-digit OTP)
        // while staying at the natural 48px size whenever there's room
        // for it (always true for a 4-digit PIN).
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 440.0;
        final boxWidth =
            (((maxWidth - (widget.length - 1) * gap) / widget.length).clamp(
              32.0,
              48.0,
            )).toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ValueListenableBuilder(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  final filled = value.text.length;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        _CodeBox(
                          width: boxWidth,
                          filled: i < filled,
                          active: widget.enabled && i == filled,
                          hasError: widget.hasError,
                        ),
                      ],
                    ],
                  );
                },
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    showCursor: false,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: widget.length,
                    textAlign: TextAlign.center,
                    autofillHints: widget.isOneTimeCode
                        ? const [AutofillHints.oneTimeCode]
                        : null,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: widget.onSubmitted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.width,
    required this.filled,
    required this.active,
    required this.hasError,
  });

  final double width;
  final bool filled;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? UmojaColors.danger
        : active
        ? UmojaColors.primary
        : UmojaColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? UmojaColors.primarySoft : UmojaColors.surface,
        borderRadius: UmojaRadius.controlAll,
        border: Border.all(
          color: borderColor,
          width: active || hasError ? 2 : 1,
        ),
      ),
      child: filled
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: UmojaColors.primary,
              ),
            )
          : null,
    );
  }
}
