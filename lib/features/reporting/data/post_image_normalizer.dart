import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_tools;

Future<Uint8List> normalizePostImage(Uint8List input) =>
    compute(_normalizePostImage, input);

Uint8List _normalizePostImage(Uint8List input) {
  const maximumInput = 15 * 1024 * 1024;
  const maximumOutput = 500 * 1024;
  if (input.isEmpty || input.length > maximumInput) {
    throw Exception('Choose a valid photo smaller than 15 MB.');
  }
  final decoded = image_tools.decodeImage(input);
  if (decoded == null || decoded.width < 1 || decoded.height < 1) {
    throw Exception('The selected photo could not be read.');
  }
  final oriented = image_tools.bakeOrientation(decoded);
  var scale = min(1.0, 1600 / max(oriented.width, oriented.height));
  for (var resize = 0; resize < 7; resize++) {
    final width = max(1, (oriented.width * scale).round());
    final height = max(1, (oriented.height * scale).round());
    final normalized = image_tools.copyResize(
      oriented,
      width: width,
      height: height,
      interpolation: image_tools.Interpolation.average,
    );
    for (final quality in const [82, 70, 58]) {
      final bytes = Uint8List.fromList(
        image_tools.encodeJpg(normalized, quality: quality),
      );
      if (bytes.length <= maximumOutput) return bytes;
    }
    scale *= .8;
  }
  throw Exception('The selected photo could not be compressed safely.');
}
