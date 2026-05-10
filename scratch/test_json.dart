import 'dart:convert';

void main() {
  try {
    final jsonStr = '{"weight": 2e-12}';
    final data = json.decode(jsonStr);
    print('Weight: ${data['weight']}');
    print('Type: ${data['weight'].runtimeType}');
    
    final weight = (data['weight'] as num).toDouble();
    print('As double: $weight');
  } catch (e) {
    print('Error: $e');
  }
}
