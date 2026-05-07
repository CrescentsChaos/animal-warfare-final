
import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 64, height: 64);
  print('Default numChannels: ${image.numChannels}');
  
  final color = img.ColorRgba8(0, 0, 0, 0);
  image.setPixel(0, 0, color);
  final p = image.getPixel(0, 0);
  print('Pixel(0,0) Alpha: ${p.a}');
}
