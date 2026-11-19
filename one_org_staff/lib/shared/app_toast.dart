import 'package:flutter/material.dart';

/// What a toast is telling the person, which picks its colour and icon.
enum ToastKind { success, info, warning, error }

/// Shows a short message as a tinted card with a coloured icon badge and a
/// close button. It replaces whatever toast is already showing.
void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: AppToast(
          message: message,
          kind: kind,
          onClose: messenger.hideCurrentSnackBar,
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
}

/// The toast card itself.
class AppToast extends StatelessWidget {
  const AppToast({
    super.key,
    required this.message,
    required this.kind,
    this.onClose,
  });

  final String message;
  final ToastKind kind;
  final VoidCallback? onClose;

  static const _hues = {
    ToastKind.success: Color(0xFF16A34A),
    ToastKind.info: Color(0xFF2563EB),
    ToastKind.warning: Color(0xFFF59E0B),
    ToastKind.error: Color(0xFFDC2626),
  };

  static const _icons = {
    ToastKind.success: Icons.check_rounded,
    ToastKind.info: Icons.info_rounded,
    ToastKind.warning: Icons.warning_rounded,
    ToastKind.error: Icons.error_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = _hues[kind]!;
    // Opaque, so nothing behind the toast shows through.
    final base = dark ? const Color(0xFF1E293B) : Colors.white;
    final background = Color.alphaBlend(
      hue.withValues(alpha: dark ? 0.16 : 0.08),
      base,
    );
    final border = hue.withValues(alpha: dark ? 0.4 : 0.25);
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: hue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icons[kind], size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: muted),
              ),
          ],
        ),
      ),
    );
  }
}
