import 'dart:convert';
import 'dart:typed_data';

/// Detects the image type from magic bytes (web file pickers can return PNG).
class ImageMime {
  const ImageMime._();

  static String detect(Uint8List b) {
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) {
      return 'image/png';
    }
    if (b.length > 11 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[8] == 0x57 &&
        b[9] == 0x45) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static String toDataUrl(Uint8List bytes) =>
      'data:${detect(bytes)};base64,${base64Encode(bytes)}';
}
