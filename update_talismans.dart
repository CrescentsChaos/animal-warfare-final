import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/talismans.json');
  final String jsonStr = await file.readAsString();
  final List<dynamic> data = jsonDecode(jsonStr);

  for (var item in data) {
    if (item['id'] == 'raw_meat') {
      item['hunger_fulfillment'] = 25;
    } else if (item['id'] == 'beef') {
      item['hunger_fulfillment'] = 50;
    } else if (item['id'] == 'seaweed_salad') {
      item['hunger_fulfillment'] = 30;
      item['thirst_fulfillment'] = 10;
    } else if (item['id'] == 'fish_fillet') {
      item['hunger_fulfillment'] = 40;
    } else if (item['id'] == 'seed_mix') {
      item['hunger_fulfillment'] = 20;
    } else if (item['id'] == 'insect_jelly') {
      item['hunger_fulfillment'] = 15;
      item['thirst_fulfillment'] = 5;
      item['stamina_boost'] = 10;
    } else if (item['id'] == 'royal_honey') {
      item['hunger_fulfillment'] = 40;
      item['stamina_boost'] = 30;
    } else if (item['id'] == 'purified_water') {
      item['thirst_fulfillment'] = 100;
      item['stamina_boost'] = 15;
    }
  }

  // Add Energy Bar
  data.add({
    "id": "energy_bar",
    "name": "Energy Bar",
    "description": "A dense, high-calorie bar that provides a massive stamina boost.",
    "is_food": true,
    "hunger_fulfillment": 15,
    "stamina_boost": 50,
    "effects": []
  });

  await file.writeAsString(JsonEncoder.withIndent('  ').convert(data));
  print('Updated talismans.json');
}
