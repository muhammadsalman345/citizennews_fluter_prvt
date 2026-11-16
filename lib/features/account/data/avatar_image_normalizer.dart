import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_tools;

Future<Uint8List> normalizeAvatarImage(Uint8List input) =>
    compute(_normalizeAvatarImage, input);

Uint8List _normalizeAvatarImage(Uint8List input) {
  const maximumInput = 10 * 1024 * 1024;
  const maximumOutput = 300 * 1024;
  if (input.isEmpty || input.length > maximumInput) {
    throw Exception('Choose a valid photo smaller than 10 MB.');
  }
  final decoded = image_tools.decodeImage(input);
  if (decoded == null || decoded.width < 1 || decoded.height < 1) {
    throw Exception('The selected photo could not be read.');
  }
  final oriented = image_tools.bakeOrientation(decoded);
  final side = min(oriented.width, oriented.height);
  final square = image_tools.copyCrop(
    oriented,
    x: (oriented.width - side) ~/ 2,
    y: (oriented.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = image_tools.copyResize(
    square,
    width: 512,
    height: 512,
    interpolation: image_tools.Interpolation.average,
  );
  for (final quality in const [84, 74, 64, 54]) {
    final output = Uint8List.fromList(
      image_tools.encodeJpg(resized, quality: quality),
    );
    if (output.length <= maximumOutput) return output;
  }
  throw Exception('The selected photo could not be compressed safely.');
}
