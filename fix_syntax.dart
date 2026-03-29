import 'dart:io';

void main() {
  final file = File('lib/double_battle_screen.dart');
  String text = file.readAsStringSync();

  // Fix the backslashed single quote
  text = text.replaceAll(r'replaceAll(\"\'\", \"_\")', "replaceAll(\"'\", \"_\")");
  
  // Also we might have backslashed double quotes? The literal string in code was: `replaceAll(\"\'\", \"_\")`
  text = text.replaceAll('replaceAll(\\\\"\\\'\\\\", \\\\"_\\\\")', "replaceAll(\"'\", \"_\")");
  
  // To be super safe, use regex on the literal entire string block
  text = text.replaceAll(
    "assets/sprites/\${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\\\"\\'\\\", \\\"_\\\")}.png",
    "assets/sprites/\${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\"'\", \"_\")}.png"
  );
  
  text = text.replaceAll(
    "assets/sprites/\${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\"\\'\", \"_\")}.png",
    "assets/sprites/\${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\"'\", \"_\")}.png"
  );

  // Provide _getBiomePlatform()
  final biomePlatformHelper = '''
  String _getBiomePlatform() {
    final biomeData = widget.battleManager.battleBiome.data;
    if (biomeData.primaryColor == Colors.blue || biomeData.id.contains('ocean')) return 'water';
    if (biomeData.primaryColor == Colors.grey || widget.isArenaBattle) return 'dirt';
    if (biomeData.primaryColor == Colors.yellow) return 'sand';
    if (biomeData.primaryColor == Colors.cyan || biomeData.primaryColor == Colors.white) return 'ice';
    if (biomeData.primaryColor == Colors.red) return 'magma';
    return 'grass';
  }
''';

  if (!text.contains("_getBiomePlatform() {")) {
    text = text.replaceFirst(
      "String _getAssetPath(String biome) {",
      "\$biomePlatformHelper\\n  String _getAssetPath(String biome) {"
    );
  }

  // Next: curly braces for if statements. The static analyzer complained:
  // "Statements in an if should be enclosed in a block - lib/double_battle_screen.dart"
  // Let's just put curly braces around the returns in _getAssetPath, which generated those errors!
  final newAssetPath = '''  String _getAssetPath(String biome) {
    String name = biome.toLowerCase();
    if (name.contains('swamp')) { return 'assets/biomes/swamp.png'; }
    if (name.contains('desert')) { return 'assets/biomes/desert.png'; }
    if (name.contains('snow')) { return 'assets/biomes/snow.png'; }
    if (name.contains('volcan')) { return 'assets/biomes/volcano.png'; }
    if (name.contains('mountain')) { return 'assets/biomes/mountain.png'; }
    if (name.contains('ocean')) { return 'assets/biomes/ocean.png'; }
    return 'assets/biomes/jungle.png';
  }''';

  final oldAssetPath = '''  String _getAssetPath(String biome) {
    String name = biome.toLowerCase();
    if (name.contains('swamp')) return 'assets/biomes/swamp.png';
    if (name.contains('desert')) return 'assets/biomes/desert.png';
    if (name.contains('snow')) return 'assets/biomes/snow.png';
    if (name.contains('volcan')) return 'assets/biomes/volcano.png';
    if (name.contains('mountain')) return 'assets/biomes/mountain.png';
    if (name.contains('ocean')) return 'assets/biomes/ocean.png';
    return 'assets/biomes/jungle.png';
  }''';

  text = text.replaceFirst(oldAssetPath, newAssetPath);

  // Let's also search for `replaceAll(\\"'\\", \\"_\\")` using manual strings to be absolutely safe
  file.writeAsStringSync(text);
  print(text.contains("_getBiomePlatform()"));
  print("Syntax fix applied.");
}
