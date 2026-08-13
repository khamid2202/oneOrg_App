import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:one_org_staff/features/Profile/avatar_cropper.dart';

/// A landscape test image with a distinctly coloured centre, so a crop can be
/// checked by sampling pixels.
Uint8List _sampleJpeg({int width = 800, int height = 400}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(0, 0, 255));
  img.fillRect(
    image,
    x1: width ~/ 2 - 20,
    y1: height ~/ 2 - 20,
    x2: width ~/ 2 + 20,
    y2: height ~/ 2 + 20,
    color: img.ColorRgb8(255, 0, 0),
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  group('coverScale', () {
    test('scales a landscape image to cover the viewport by its height', () {
      // 800x400 into 288: height is the tight dimension.
      expect(
        coverScale(imageWidth: 800, imageHeight: 400),
        closeTo(288 / 400, 1e-9),
      );
    });

    test('scales a portrait image to cover the viewport by its width', () {
      expect(
        coverScale(imageWidth: 400, imageHeight: 800),
        closeTo(288 / 400, 1e-9),
      );
    });

    test('is unaffected by a degenerate image', () {
      expect(coverScale(imageWidth: 0, imageHeight: 0), 1);
    });
  });

  group('clampCropOffset', () {
    test('pins the tight axis to zero so no gap can be revealed', () {
      // At cover scale a 800x400 image is exactly 288 tall: no vertical slack.
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final clamped = clampCropOffset(
        offset: const Offset(0, 200),
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
      );

      expect(clamped.dy, 0);
    });

    test('allows travel along the loose axis only up to the edge', () {
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final limit = (800 * scale - 288) / 2;

      final clamped = clampCropOffset(
        offset: const Offset(10000, 0),
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
      );

      expect(clamped.dx, closeTo(limit, 1e-9));
    });
  });

  group('computeCropRect', () {
    test('centres on the image when it is untouched', () {
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final rect = computeCropRect(
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
        offset: Offset.zero,
      );

      // The full height, and a centred square of the same size horizontally.
      expect(rect.height, closeTo(400, 1e-6));
      expect(rect.width, closeTo(400, 1e-6));
      expect(rect.center.dx, closeTo(400, 1e-6));
      expect(rect.center.dy, closeTo(200, 1e-6));
    });

    test('is always square', () {
      final rect = computeCropRect(
        imageWidth: 800,
        imageHeight: 400,
        scale: coverScale(imageWidth: 800, imageHeight: 400) * 2.4,
        offset: const Offset(-33, 12),
      );

      expect(rect.width, closeTo(rect.height, 1e-9));
    });

    test('zooming in frames a smaller region of the source', () {
      final base = coverScale(imageWidth: 800, imageHeight: 400);
      final wide = computeCropRect(
        imageWidth: 800,
        imageHeight: 400,
        scale: base,
        offset: Offset.zero,
      );
      final zoomed = computeCropRect(
        imageWidth: 800,
        imageHeight: 400,
        scale: base * 2,
        offset: Offset.zero,
      );

      expect(zoomed.width, closeTo(wide.width / 2, 1e-6));
      // Still centred.
      expect(zoomed.center.dx, closeTo(wide.center.dx, 1e-6));
    });

    test('dragging right reveals content further left in the source', () {
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final centred = computeCropRect(
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
        offset: Offset.zero,
      );
      final dragged = computeCropRect(
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
        offset: const Offset(50, 0),
      );

      expect(dragged.left, lessThan(centred.left));
      expect(centred.left - dragged.left, closeTo(50 / scale, 1e-6));
    });

    test('a max drag lands flush against the image edge', () {
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final max = maxCropOffset(
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
      );
      final rect = computeCropRect(
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
        offset: Offset(max.dx, 0),
      );

      expect(rect.left, closeTo(0, 1e-6));
    });
  });

  group('cropToSquareJpeg', () {
    test('exports a square image at the configured size', () async {
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final bytes = await cropToSquareJpeg(
        CropRequest(
          bytes: _sampleJpeg(),
          rect: computeCropRect(
            imageWidth: 800,
            imageHeight: 400,
            scale: scale,
            offset: Offset.zero,
          ),
          outputSize: kCropOutputSize,
        ),
      );

      final decoded = img.decodeImage(bytes)!;
      expect(decoded.width, kCropOutputSize);
      expect(decoded.height, kCropOutputSize);
    });

    test('an untouched crop keeps the centre of the source', () async {
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final bytes = await cropToSquareJpeg(
        CropRequest(
          bytes: _sampleJpeg(),
          rect: computeCropRect(
            imageWidth: 800,
            imageHeight: 400,
            scale: scale,
            offset: Offset.zero,
          ),
          outputSize: kCropOutputSize,
        ),
      );

      // The source is blue with a red centre square.
      final decoded = img.decodeImage(bytes)!;
      final centre = decoded.getPixel(
        kCropOutputSize ~/ 2,
        kCropOutputSize ~/ 2,
      );
      expect(centre.r, greaterThan(200));
      expect(centre.b, lessThan(60));
    });

    test('dragging fully left frames the blue edge, not the red centre',
        () async {
      final scale = coverScale(imageWidth: 800, imageHeight: 400);
      final max = maxCropOffset(
        imageWidth: 800,
        imageHeight: 400,
        scale: scale,
      );
      final bytes = await cropToSquareJpeg(
        CropRequest(
          bytes: _sampleJpeg(),
          rect: computeCropRect(
            imageWidth: 800,
            imageHeight: 400,
            scale: scale,
            offset: Offset(max.dx, 0),
          ),
          outputSize: kCropOutputSize,
        ),
      );

      final decoded = img.decodeImage(bytes)!;
      final centre = decoded.getPixel(
        kCropOutputSize ~/ 2,
        kCropOutputSize ~/ 2,
      );
      expect(centre.b, greaterThan(200));
      expect(centre.r, lessThan(60));
    });

    test('stays inside the source when the rect rounds past an edge', () async {
      // A rect deliberately overhanging both edges must not throw.
      final bytes = await cropToSquareJpeg(
        CropRequest(
          bytes: _sampleJpeg(width: 100, height: 100),
          rect: const Rect.fromLTWH(-5, -5, 130, 130),
          outputSize: 64,
        ),
      );

      final decoded = img.decodeImage(bytes)!;
      expect(decoded.width, 64);
      expect(decoded.height, 64);
    });

    test('rejects bytes that are not an image', () {
      expect(
        () => cropToSquareJpeg(
          CropRequest(
            bytes: Uint8List.fromList(const [1, 2, 3, 4, 5]),
            rect: const Rect.fromLTWH(0, 0, 10, 10),
            outputSize: 64,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
