import 'dart:io';
import 'package:animal_warfare/services/biometric_service.dart';

void main() async {
  final bytes = File(
    'assets/sprites/longnose_butterflyfish.png',
  ).readAsBytesSync();
  final svc = BiometricService();
  final f = await svc.extractFeatures(bytes, name: 'input');
  print(
    'Input: aspect=${f.aspectRatio} solidity=${f.solidity} edge=${f.edgeDensity}',
  );
}
