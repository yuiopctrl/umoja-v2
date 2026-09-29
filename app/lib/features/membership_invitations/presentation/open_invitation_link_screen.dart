import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/theme/umoja_spacing.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../domain/invitation_link_parser.dart';

/// `/invite/open` (Prompt 09G-B1-E4 §E/§F): the in-app fallback for a
/// user who received an invitation link via WhatsApp/SMS but is
/// already inside the installed app, with nowhere else to paste it.
/// Purely a client-side parser + internal navigation — no repository
/// call, no group/member/short-code lookup of any kind. The pasted
/// text is never persisted, never logged, and never shown back in any
/// error message (see [parseInvitationToken]).
class OpenInvitationLinkScreen extends StatefulWidget {
  const OpenInvitationLinkScreen({super.key});

  @override
  State<OpenInvitationLinkScreen> createState() =>
      _OpenInvitationLinkScreenState();
}

class _OpenInvitationLinkScreenState extends State<OpenInvitationLinkScreen> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    setState(() {
      _controller.text = text;
      _showError = false;
    });
  }

  void _continue() {
    setState(() => _showError = false);
    try {
      final token = parseInvitationToken(_controller.text);
      context.go(AppRoutes.membershipInvitationAcceptPath(token));
    } on InvalidInvitationLinkException {
      setState(() => _showError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.openInvitationTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UmojaSpacing.lg),
          child: ResponsiveCenter(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.openInvitationInstructions),
                const SizedBox(height: UmojaSpacing.lg),
                TextField(
                  key: const Key('openInvitationLinkField'),
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.openInvitationLinkLabel,
                    errorText: _showError
                        ? l10n.invitationLinkInvalidError
                        : null,
                  ),
                  onChanged: (_) {
                    if (_showError) setState(() => _showError = false);
                  },
                ),
                const SizedBox(height: UmojaSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('pasteFromClipboardAction'),
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste),
                    label: Text(l10n.pasteFromClipboardAction),
                  ),
                ),
                const SizedBox(height: UmojaSpacing.lg),
                UmojaPrimaryButton(
                  key: const Key('openInvitationContinueAction'),
                  expand: true,
                  label: l10n.continueButton,
                  onPressed: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
