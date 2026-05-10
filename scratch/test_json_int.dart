import 'dart:convert';

void main() {
  try {
    final jsonStr = '{"price": 1e2}';
    final data = json.decode(jsonStr);
    print('Price: ${data['price']}');
    print('Type: ${data['price'].runtimeType}');
    
    // This will fail if price is a double
    final price = data['price'] as int;
    print('As int: $price');
  } catch (e) {
    print('Error: $e');
  }
}
