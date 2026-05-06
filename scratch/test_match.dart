import 'dart:convert';
import 'dart:io';

void main() {
  final map = jsonDecode(File('assets/ml/sprite_features.json').readAsStringSync());
  final longnose = map['Longnose Butterflyfish'];
  if (longnose == null) {
    print('Longnose not found');
    return;
  }
  print('Hue Bins for Longnose:');
  (longnose['hueBins'] as Map).forEach((k, v) {
    if (v > 0) print('$k: $v');
  });
}
