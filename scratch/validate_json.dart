import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final file = File('assets/news_config.json');
    final content = file.readAsStringSync();
    final data = json.decode(content);
    print('JSON successfully decoded!');
    print('Usernames count: ${data['usernames']?.length}');
    print('Templates count: ${data['templates']?.length}');
    print('Categories count: ${data['categories']?.length}');
    print('Authors count: ${data['authors']?.length}');
    print('Channels count: ${data['channels']?.length}');
  } catch (e) {
    print('JSON Error: $e');
  }
}
