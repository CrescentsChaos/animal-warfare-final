import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final imageBytes = File(r'C:\Users\USER\.gemini\antigravity\brain\9e40a678-10f7-4c89-a30a-7b418f7a3012\media__1778094699578.jpg').readAsBytesSync();
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) return;
  
  // Apply exactly what biometric_service does
  img.Image resized;
  if (decoded.width == decoded.height) {
    resized = img.copyResize(decoded, width: 64, height: 64);
  } else {
    final size = decoded.width > decoded.height ? decoded.width : decoded.height;
    final padded = img.Image(width: size, height: size);
    img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0)); 
    final xOffset = (size - decoded.width) ~/ 2;
    final yOffset = (size - decoded.height) ~/ 2;
    img.compositeImage(padded, decoded, dstX: xOffset, dstY: yOffset);
    resized = img.copyResize(padded, width: 64, height: 64);
  }

  // mask
  final mask = List<bool>.filled(resized.width * resized.height, true);
  final List<List<int>> prototypes = [];
  for (int x in [0, resized.width - 1]) {
    for (int y in [0, resized.height - 1]) {
      final p = resized.getPixel(x, y);
      prototypes.add([p.r.toInt(), p.g.toInt(), p.b.toInt()]);
    }
  }
  for (final p in [
    resized.getPixel(resized.width ~/ 2, 0),
    resized.getPixel(resized.width ~/ 2, resized.height - 1),
    resized.getPixel(0, resized.height ~/ 2),
    resized.getPixel(resized.width - 1, resized.height ~/ 2),
  ]) {
    prototypes.add([p.r.toInt(), p.g.toInt(), p.b.toInt()]);
  }

  int unmasked = 0;
  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      final p = resized.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

      double minStatsDist = 1000.0;
      for (final bp in prototypes) {
        final d = (r - bp[0]).abs() + (g - bp[1]).abs() + (b - bp[2]).abs(); // wait, original uses sqrt(pow)
        // I will use exact logic from biometric_service
      }
    }
  }
}
