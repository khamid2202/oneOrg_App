import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

/// Shows a document in place rather than handing it to another app.
///
/// Images render directly; anything else (PDFs in practice) goes through a
/// web view. Android's web view does not render PDFs inline, so there the
/// sheet offers to open the file externally instead of showing a blank page.
Future<void> showDocumentViewer(
  BuildContext context, {
  required DocumentEntry document,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _DocumentViewer(document: document),
  );
}

bool _looksLikeImage(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return const [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
  ].any(path.endsWith);
}

/// Android's WebView has no built-in PDF renderer.
bool get _canRenderPdfInline {
  if (kIsWeb) {
    return true;
  }
  return Platform.isIOS || Platform.isMacOS;
}

class _DocumentViewer extends StatelessWidget {
  const _DocumentViewer({required this.document});

  final DocumentEntry document;

  Future<void> _openExternally(BuildContext context) async {
    final url = document.documentUrl;
    if (url == null) {
      return;
    }
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the document.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = document.documentUrl;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            _ViewerHeader(
              title: document.documentName,
              subtitle: document.documentType,
              onOpenExternally: url == null
                  ? null
                  : () => _openExternally(context),
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1),
            Expanded(
              child: url == null
                  ? const _ViewerMessage(
                      icon: Icons.description_outlined,
                      message: 'This document has no file attached.',
                    )
                  : _DocumentBody(url: url),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentBody extends StatelessWidget {
  const _DocumentBody({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (_looksLikeImage(url)) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) => const _ViewerMessage(
              icon: Icons.broken_image_outlined,
              message: 'That image could not be loaded.',
            ),
          ),
        ),
      );
    }

    if (!_canRenderPdfInline) {
      return const _ViewerMessage(
        icon: Icons.picture_as_pdf_outlined,
        message:
            'This file type cannot be previewed on Android.\n'
            'Use "Open" to view it.',
      );
    }

    return _WebDocumentView(url: url);
  }
}

class _WebDocumentView extends StatefulWidget {
  const _WebDocumentView({required this.url});

  final String url;

  @override
  State<_WebDocumentView> createState() => _WebDocumentViewState();
}

class _WebDocumentViewState extends State<_WebDocumentView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _failed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const _ViewerMessage(
        icon: Icons.error_outline_rounded,
        message: 'That document could not be loaded.',
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ViewerHeader extends StatelessWidget {
  const _ViewerHeader({
    required this.title,
    required this.subtitle,
    required this.onOpenExternally,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onOpenExternally;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                    ),
                  ),
              ],
            ),
          ),
          if (onOpenExternally != null)
            TextButton.icon(
              onPressed: onOpenExternally,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open'),
            ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: mutedColor),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
