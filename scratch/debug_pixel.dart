import 'dart:io';
import 'package:image/image.dart' as img;
import 'dart:math' as Math;

void main() {
  final bytes = File('assets/sprites/royal_bengal_tiger.png').readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    print('Failed to decode');
    return;
  }
  
  final size = Math.max(decoded.width, decoded.height);
  final padded = img.Image(width: size, height: size, numChannels: 4);
  img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(padded, decoded, dstX: (size - decoded.width) ~/ 2, dstY: (size - decoded.height) ~/ 2);
  final resized = img.copyResize(padded, width: 64, height: 64);
  
  int objectPixels = 0;
  double totalBrightness = 0;
  for (final p in resized) {
    if (p.a >= 128) {
      objectPixels++;
      // This matches the formula used in extractFeatures
      double rf = p.r / 255.0, gf = p.g / 255.0, bf = p.b / 255.0;
      double maxV = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
      totalBrightness += maxV;
    }
  }
  print('Object Pixels: $objectPixels');
  print('Average Brightness: ${totalBrightness / objectPixels}');
  
  final pixel = resized.getPixel(32, 32);
  print('Center Pixel - R: ${pixel.r}, G: ${pixel.g}, B: ${pixel.b}, A: ${pixel.a}');
}
