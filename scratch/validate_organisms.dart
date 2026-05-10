import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/Organisms.json');
  final content = await file.readAsString();
  final List<dynamic> data = json.decode(content);
  
  for (int i = 0; i < data.length; i++) {
    final item = data[i];
    try {
      // Replicating Organism.fromJson logic
      var typeList = <String>[];
      if (item['types'] is List) {
        typeList = List<String>.from(item['types']);
      } else if (item['types'] is String) {
        typeList = (item['types'] as String).split(',').map((e) => e.trim()).toList();
      }
      if (typeList.isEmpty && item['category'] is String) {
        typeList = (item['category'] as String).split(',').map((e) => e.trim()).toList();
      }
      if (typeList.isEmpty) typeList = ['basic'];

      final name = (item['name'] ?? 'Unknown') as String;
      final scientificName = (item['scientific_name'] ?? 'Unknown') as String;
      final habitat = (item['habitat'] ?? 'Unknown') as String;
      final drops = (item['drops'] ?? '') as String;
      final attack = (item['attack'] as int? ?? 10);
      final defense = (item['defense'] as int? ?? 10);
      final power = (item['power'] as int? ?? 10);
      final resistance = (item['resistance'] as int? ?? 10);
      final health = (item['health'] as int? ?? 50);
      final speed = (item['speed'] as int? ?? 10);
      final abilities = (item['abilities'] ?? '') as String;
      final category = (item['category'] ?? '') as String;
      final moves = (item['moves'] ?? '') as String;
      final sprite = (item['sprite'] ?? '') as String;
      final rarity = (item['rarity'] as String? ?? 'Common');
      final description = (item['description'] as String? ?? '');
      final weight = (item['weight'] as num? ?? 1.0).toDouble();
      final activeTime = (item['active_time'] as String? ?? 'any');
      final cry = (item['cry'] as String? ?? 'default');
      final spawnTiles = (item['spawn_tiles'] as String? ?? 'any');
      final pheno = (item['pheno'] as String? ?? 'none');
      final animalClass = (item['class'] ?? item['animal_class'] as String? ?? 'unknown');
      final diet = (item['diet'] as String? ?? 'unknown');
      
      // Check if animalClass is actually a String
      if (animalClass is! String) throw 'animalClass is not a String: ${animalClass.runtimeType}';

    } catch (e) {
      print('Error at index $i (Animal: ${item['name']}): $e');
      // break; // Continue to find all errors
    }
  }
  print('Done checking ${data.length} animals.');
}
