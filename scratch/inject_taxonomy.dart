import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/Organisms.json');
  final content = await file.readAsString();
  final List<dynamic> organisms = json.decode(content);

  for (var org in organisms) {
    if (org is Map<String, dynamic>) {
      final name = (org['name'] ?? '').toString().toLowerCase();
      final desc = (org['description'] ?? '').toString().toLowerCase();
      //final cat = (org['category'] ?? '').toString().toLowerCase();

      String animalClass = 'unknown';

      if (name.contains('tiger') ||
          name.contains('cat') ||
          name.contains('dog') ||
          name.contains('bear') ||
          name.contains('wolf') ||
          name.contains('lion') ||
          desc.contains('mammal')) {
        animalClass = 'mammal';
      } else if (name.contains('bird') ||
          name.contains('eagle') ||
          name.contains('hawk') ||
          name.contains('owl') ||
          desc.contains('bird')) {
        animalClass = 'bird';
      } else if (name.contains('fish') ||
          name.contains('shark') ||
          name.contains('tuna') ||
          desc.contains('fish')) {
        animalClass = 'fish';
      } else if (name.contains('toad') ||
          name.contains('frog') ||
          desc.contains('amphibian')) {
        animalClass = 'amphibian';
      } else if (name.contains('snake') ||
          name.contains('lizard') ||
          name.contains('turtle') ||
          desc.contains('reptile')) {
        animalClass = 'reptile';
      } else if (name.contains('bug') ||
          name.contains('beetle') ||
          name.contains('ant') ||
          desc.contains('insect')) {
        animalClass = 'insect';
      }

      org['animal_class'] = animalClass;
    }
  }

  const JsonEncoder encoder = JsonEncoder.withIndent('    ');
  await file.writeAsString(encoder.convert(organisms));
  print('Injected taxonomy into ${organisms.length} organisms.');
}
