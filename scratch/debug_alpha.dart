
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/sprites/royal_bengal_tiger.png').readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    print('Failed to decode');
    return;
  }
  
  int alphaGt128 = 0;
  int total = decoded.width * decoded.height;
  for (final p in decoded) {
    if (p.a >= 128) alphaGt128++;
  }
  
  print('Total pixels: $total');
  print('Alpha >= 128: $alphaGt128');
  print('Alpha[0]: ${decoded.getPixel(0, 0).a}');
}
