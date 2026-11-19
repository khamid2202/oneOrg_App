import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/auth_controller.dart';
import '../data/passkey_service.dart';

/// "Sign in faster next time": shown once per user on this phone, right after
/// a password sign-in, when the account has no passkey yet. Same screen as the
/// parents app and the web.
class PasskeyOfferPage extends StatefulWidget {
  const PasskeyOfferPage({super.key, required this.controller});

  final AuthController controller;

  @override
  State<PasskeyOfferPage> createState() => _PasskeyOfferPageState();
}

class _PasskeyOfferPageState extends State<PasskeyOfferPage> {
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.addPasskey();
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(l.passkeyAdded)));
      }
      await widget.controller.closePasskeyOffer();
    } on PasskeyCancelled {
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (passkeyProblemOf(e) == PasskeyProblem.alreadyOnDevice) {
        await widget.controller.closePasskeyOffer();
        return;
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = passkeyProblemOf(e) == PasskeyProblem.unavailable
              ? l.passkeyUnavailable
              : l.passkeyAddFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.passkeyOfferTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.passkeyOfferBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.mutedText,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Icon(Icons.fingerprint, size: 72, color: colors.accent.solid),
                  const SizedBox(height: 36),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _add,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(l.passkeyAdd),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : widget.controller.closePasskeyOffer,
                    child: Text(l.passkeyNotNow),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
