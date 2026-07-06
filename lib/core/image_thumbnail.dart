import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Center-crops [bytes] to a square and scales it to [size] px, re-encoded as
/// JPEG. Keeps group photos small enough to sync and open on low bandwidth.
/// Throws [FormatException] when the bytes are not a decodable image.
Uint8List squareJpegThumbnail(
  Uint8List bytes, {
  int size = 512,
  int quality = 80,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported image');
  }
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final cropped = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = img.copyResize(cropped, width: size, height: size);
  return img.encodeJpg(resized, quality: quality);
}
