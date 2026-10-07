import 'package:flutter/material.dart';

import '../../../../core/theme/umoja_spacing.dart';

/// A message with a retry action, used inside a loan section. The section
/// keeps everything else on screen, so one failed block never blanks the
/// whole loan.
class MemberLoanRetryNotice extends StatelessWidget {
  const MemberLoanRetryNotice({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: UmojaSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}
