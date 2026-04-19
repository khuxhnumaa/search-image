import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'clip_assets.dart';

/// Converts encoded image bytes (jpeg/png) into a flattened float32 tensor
/// normalized for CLIP, matching the provided TFLite input shape.
///
/// Supports common layouts:
/// - NHWC: [1, H, W, 3]
/// - NCHW: [1, 3, H, W]
Float32List preprocessImageToFloat32(Uint8List encodedBytes, {required List<int> inputShape}) {
  final decoded0 = img.decodeImage(encodedBytes);
  if (decoded0 == null) {
    throw StateError('Unable to decode image bytes');
  }
  // Apply EXIF orientation when present.
  final decoded = img.bakeOrientation(decoded0);

  if (inputShape.length != 4 || inputShape[0] != 1) {
    throw StateError('Unsupported image input shape: $inputShape');
  }

  final isNhwc = inputShape[3] == 3;
  final isNchw = inputShape[1] == 3;
  if (!isNhwc && !isNchw) {
    throw StateError('Unsupported image input layout (expected channel dim=3): $inputShape');
  }

  final h = isNhwc ? inputShape[1] : inputShape[2];
  final w = isNhwc ? inputShape[2] : inputShape[3];

  // Standard CLIP-style preprocessing: resize to cover then center-crop.
  img.Image processed;
  if (decoded.width == w && decoded.height == h) {
    processed = decoded;
  } else {
    final scale = math.max(w / decoded.width, h / decoded.height);
    final newW = math.max(1, (decoded.width * scale).round());
    final newH = math.max(1, (decoded.height * scale).round());

    final resized = img.copyResize(
      decoded,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear,
    );

    final maxX = math.max(0, newW - w);
    final maxY = math.max(0, newH - h);
    final x = math.min(maxX, math.max(0, ((newW - w) / 2).round()));
    final y = math.min(maxY, math.max(0, ((newH - h) / 2).round()));

    processed = img.copyCrop(
      resized,
      x: x,
      y: y,
      width: w,
      height: h,
    );
  }

  final mean = ClipAssets.imageMean;
  final std = ClipAssets.imageStd;

  final out = Float32List(inputShape.reduce((a, b) => a * b));

  // Iterate RGB bytes directly for speed.
  final rgb = processed.getBytes(order: img.ChannelOrder.rgb);

  if (isNhwc) {
    var idx = 0;
    final n = h * w;
    for (var i = 0; i < n; i++) {
      final r = rgb[i * 3 + 0] / 255.0;
      final g = rgb[i * 3 + 1] / 255.0;
      final b = rgb[i * 3 + 2] / 255.0;

      out[idx++] = ((r - mean[0]) / std[0]).toDouble();
      out[idx++] = ((g - mean[1]) / std[1]).toDouble();
      out[idx++] = ((b - mean[2]) / std[2]).toDouble();
    }
    return out;
  }

  // NCHW
  final hw = h * w;
  for (var i = 0; i < hw; i++) {
    final r = rgb[i * 3 + 0] / 255.0;
    final g = rgb[i * 3 + 1] / 255.0;
    final b = rgb[i * 3 + 2] / 255.0;

    out[0 * hw + i] = ((r - mean[0]) / std[0]).toDouble();
    out[1 * hw + i] = ((g - mean[1]) / std[1]).toDouble();
    out[2 * hw + i] = ((b - mean[2]) / std[2]).toDouble();
  }

  return out;
}
