import 'package:flutter/material.dart';

/// Opens a profile photo full-screen. Pinch to zoom; tap outside or ✕ closes.
Future<void> showPhotoViewer(
  BuildContext context, {
  required String url,
  String? name,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (context) => _PhotoViewer(url: url, name: name),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url, this.name});

  final String url;
  final String? name;

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop();
    return Stack(
      children: [
        // Taps on the dark area close; taps on the photo don't.
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('photo-viewer-backdrop'),
            onTap: close,
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
                if (name != null && name!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    name!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 8,
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: close,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Wraps a small avatar so tapping it opens the photo full-size.
///
/// Inside a tappable row the avatar's own tap wins, so the row doesn't open.
/// Without a photo it returns [child] untouched and the row keeps the tap.
class ZoomableAvatar extends StatelessWidget {
  const ZoomableAvatar({
    super.key,
    required this.url,
    required this.child,
    this.name,
  });

  final String? url;
  final String? name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final photo = url;
    if (photo == null || photo.isEmpty) {
      return child;
    }
    return Semantics(
      button: true,
      label: name == null ? 'View photo' : 'View $name photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showPhotoViewer(context, url: photo, name: name),
        child: child,
      ),
    );
  }
}
