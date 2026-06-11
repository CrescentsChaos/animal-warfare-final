import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/news_config.json');
  final jsonStr = file.readAsStringSync();
  final data = json.decode(jsonStr);
  final templates = data['templates'] as List;
  
  int steve = 0;
  int clint = 0;
  for (var t in templates) {
    if (t['author'] == 'Steve Irwin') steve++;
    if (t['author'] == "Clint's Reptiles") clint++;
  }
  print('Steve templates: \');
  print('Clint templates: \');
}
