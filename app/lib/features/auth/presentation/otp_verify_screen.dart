import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../controllers/phone_auth_controller.dart';

/// `/auth/verify`: enter the OTP sent to the phone number submitted on
/// `/auth/phone`. Successful verification transitions the app
/// automatically (via the auth-state stream + router) — no manual
/// "Continue" step is needed.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeController = TextEditingController();

  // Only drives the "Resend in Ns" countdown label; owned and disposed
  // by this widget so it never leaks past screen disposal. The actual
  // cooldown gate (PhoneAuthState.canResend) does not depend on this
  // timer at all.
  Timer? _cooldownTicker;

  @override
  void initState() {
    super.initState();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(phoneAuthControllerProvider.notifier)
        .verifyOtp(_codeController.text);
    // On success the auth-state stream flips and the router redirects
    // away from here automatically; on failure the error shows below.
  }

  Future<void> _resend() async {
    await ref.read(phoneAuthControllerProvider.notifier).resendOtp();
  }

  void _changeNumber() {
    ref.read(phoneAuthControllerProvider.notifier).changeNumber();
    context.go(AppRoutes.authPhone);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final phone = state.phone;

    if (phone == null) {
      // Reached directly (e.g. deep link, hot restart) without a phone
      // number in flight — there is nothing to verify.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.authPhone);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final resendAt = state.resendAvailableAt;
    final secondsRemaining = resendAt == null
        ? 0
        : resendAt.difference(DateTime.now()).inSeconds.clamp(0, 60);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Umoja', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Umoja v2', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Text('Enter the code sent to ${phone.display}'),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                autofocus: true,
                enabled: !state.isSubmitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => _verify(),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.isSubmitting ? null : _verify,
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: state.isSubmitting ? null : _changeNumber,
                    child: const Text('Change Number'),
                  ),
                  TextButton(
                    onPressed: (state.isSubmitting || !state.canResend)
                        ? null
                        : _resend,
                    child: Text(
                      state.canResend
                          ? 'Resend Code'
                          : 'Resend in ${secondsRemaining}s',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
