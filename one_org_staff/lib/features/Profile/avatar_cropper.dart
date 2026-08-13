import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Preview viewport, in logical pixels. Matches the web cropper.
const double kCropViewSize = 288;

/// Exported avatar edge length, in pixels. Matches the web cropper.
const int kCropOutputSize = 512;

const double kMinZoom = 1;
const double kMaxZoom = 3;

/// The scale at which the image just covers a [viewSize] square viewport.
double coverScale({
  required int imageWidth,
  required int imageHeight,
  double viewSize = kCropViewSize,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return 1;
  }
  return (viewSize / imageWidth) > (viewSize / imageHeight)
      ? viewSize / imageWidth
      : viewSize / imageHeight;
}

/// How far the image may be dragged before its edge would enter the viewport.
Offset maxCropOffset({
  required int imageWidth,
  required int imageHeight,
  required double scale,
  double viewSize = kCropViewSize,
}) {
  final maxX = (imageWidth * scale - viewSize) / 2;
  final maxY = (imageHeight * scale - viewSize) / 2;
  return Offset(maxX < 0 ? 0 : maxX, maxY < 0 ? 0 : maxY);
}

/// Keeps [offset] within the bounds that stop the viewport showing past the
/// edge of the image.
Offset clampCropOffset({
  required Offset offset,
  required int imageWidth,
  required int imageHeight,
  required double scale,
  double viewSize = kCropViewSize,
}) {
  final max = maxCropOffset(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    scale: scale,
    viewSize: viewSize,
  );
  return Offset(
    offset.dx.clamp(-max.dx, max.dx),
    offset.dy.clamp(-max.dy, max.dy),
  );
}

/// The region of the source image currently framed by the viewport, in image
/// pixels.
///
/// The image is drawn centred in the viewport, scaled by [scale] and shifted by
/// [offset]; this inverts that mapping.
Rect computeCropRect({
  required int imageWidth,
  required int imageHeight,
  required double scale,
  required Offset offset,
  double viewSize = kCropViewSize,
}) {
  final imageLeft = viewSize / 2 + offset.dx - (imageWidth * scale) / 2;
  final imageTop = viewSize / 2 + offset.dy - (imageHeight * scale) / 2;
  final side = viewSize / scale;

  return Rect.fromLTWH(-imageLeft / scale, -imageTop / scale, side, side);
}

@immutable
class CropRequest {
  const CropRequest({
    required this.bytes,
    required this.rect,
    required this.outputSize,
  });

  final Uint8List bytes;
  final Rect rect;
  final int outputSize;
}

/// Crops [CropRequest.rect] out of the source image and re-encodes it as a
/// square JPEG of [CropRequest.outputSize].
///
/// Pure and synchronous-in-spirit so it can run through [compute] on a
/// background isolate — decoding a camera-sized JPEG and encoding the result is
/// well past a frame budget — and be unit tested without a widget binding.
Future<Uint8List> cropToSquareJpeg(CropRequest request) async {
  // Unreadable bytes surface either as null or as a decoder-specific throw
  // depending on which format sniffer claims them; normalise both.
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(request.bytes);
  } catch (_) {
    throw const FormatException('The selected file is not a readable image.');
  }
  if (decoded == null) {
    throw const FormatException('The selected file is not a readable image.');
  }

  // Rounding can push the rect a pixel past the edge; keep it inside.
  final x = request.rect.left.round().clamp(0, decoded.width - 1);
  final y = request.rect.top.round().clamp(0, decoded.height - 1);
  final width = request.rect.width.round().clamp(1, decoded.width - x);
  final height = request.rect.height.round().clamp(1, decoded.height - y);

  final cropped = img.copyCrop(
    decoded,
    x: x,
    y: y,
    width: width,
    height: height,
  );
  final resized = img.copyResize(
    cropped,
    width: request.outputSize,
    height: request.outputSize,
    interpolation: img.Interpolation.average,
  );

  return img.encodeJpg(resized, quality: 90);
}

/// Crop / zoom a picked image into a square avatar before upload.
///
/// Returns the encoded JPEG bytes, or null if the user cancels.
class AvatarCropper extends StatefulWidget {
  const AvatarCropper({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<AvatarCropper> createState() => _AvatarCropperState();
}

class _AvatarCropperState extends State<AvatarCropper> {
  ui.Image? _image;
  Object? _decodeError;

  double _zoom = 1;
  Offset _offset = Offset.zero;

  double _zoomAtGestureStart = 1;
  Offset _offsetAtGestureStart = Offset.zero;

  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final image = await decodeImageFromList(widget.bytes);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (error) {
      if (mounted) {
        setState(() => _decodeError = error);
      }
    }
  }

  double get _baseScale {
    final image = _image;
    if (image == null) {
      return 1;
    }
    return coverScale(imageWidth: image.width, imageHeight: image.height);
  }

  double get _scale => _baseScale * _zoom;

  void _setZoom(double next) {
    final image = _image;
    if (image == null) {
      return;
    }
    final zoom = next.clamp(kMinZoom, kMaxZoom);
    setState(() {
      _zoom = zoom;
      _offset = clampCropOffset(
        offset: _offset,
        imageWidth: image.width,
        imageHeight: image.height,
        scale: _baseScale * zoom,
      );
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
    _offsetAtGestureStart = _offset;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final image = _image;
    if (image == null) {
      return;
    }

    final zoom = (_zoomAtGestureStart * details.scale).clamp(
      kMinZoom,
      kMaxZoom,
    );
    setState(() {
      _zoom = zoom;
      _offset = clampCropOffset(
        offset: _offsetAtGestureStart + details.focalPointDelta,
        imageWidth: image.width,
        imageHeight: image.height,
        scale: _baseScale * zoom,
      );
    });
  }

  Future<void> _confirm() async {
    final image = _image;
    if (image == null || _isCropping) {
      return;
    }

    setState(() => _isCropping = true);
    try {
      final rect = computeCropRect(
        imageWidth: image.width,
        imageHeight: image.height,
        scale: _scale,
        offset: _offset,
      );
      final bytes = await compute(
        cropToSquareJpeg,
        CropRequest(
          bytes: widget.bytes,
          rect: rect,
          outputSize: kCropOutputSize,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(bytes);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process that image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return AlertDialog(
      title: const Text('Adjust photo'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: kCropViewSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_decodeError != null)
              const SizedBox(
                height: kCropViewSize,
                child: Center(
                  child: Text('That image could not be opened.'),
                ),
              )
            else if (_image == null)
              const SizedBox(
                height: kCropViewSize,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _CropViewport(
                bytes: widget.bytes,
                imageWidth: _image!.width,
                imageHeight: _image!.height,
                scale: _scale,
                offset: _offset,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () => _setZoom(_zoom - 0.2),
                    icon: const Icon(Icons.zoom_out_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      min: kMinZoom,
                      max: kMaxZoom,
                      onChanged: _setZoom,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () => _setZoom(_zoom + 0.2),
                    icon: const Icon(Icons.zoom_in_rounded),
                  ),
                ],
              ),
              Text(
                'Drag to reposition · pinch or use the slider to zoom',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _image == null || _isCropping ? null : _confirm,
          child: _isCropping
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save photo'),
        ),
      ],
    );
  }
}

class _CropViewport extends StatelessWidget {
  const _CropViewport({
    required this.bytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.scale,
    required this.offset,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final Uint8List bytes;
  final int imageWidth;
  final int imageHeight;
  final double scale;
  final Offset offset;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    final displayWidth = imageWidth * scale;
    final displayHeight = imageHeight * scale;

    return GestureDetector(
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      child: ClipOval(
        child: SizedBox(
          width: kCropViewSize,
          height: kCropViewSize,
          child: ColoredBox(
            color: const Color(0xFFE8EDF3),
            child: Stack(
              children: [
                Positioned(
                  left: kCropViewSize / 2 + offset.dx - displayWidth / 2,
                  top: kCropViewSize / 2 + offset.dy - displayHeight / 2,
                  width: displayWidth,
                  height: displayHeight,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
