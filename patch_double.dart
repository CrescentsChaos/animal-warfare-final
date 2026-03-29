import 'dart:io';

void main() {
  final file = File('lib/double_battle_screen.dart');
  String text = file.readAsStringSync();

  final oldButtonMatch = RegExp(r'Widget _buildMoveButton.*?^  }', multiLine: true, dotAll: true).firstMatch(text);
  if (oldButtonMatch != null) {
    final oldButtonCode = oldButtonMatch.group(0)!;
    final newButtonCode = '''Widget _buildMoveButton(DoubleBattleManager bm, Move move, bool isNarrow) {
    final org = (bm.currentState == DoubleBattleState.selectingForSlot1)
        ? bm.playerSlot1!
        : bm.playerSlot2!;
    final isLocked =
        org.isChoiceLocked &&
        org.lockedMove != null &&
        move.name != org.lockedMove!.name;

    final typeColor = move.type.color;
    final categoryText = move.category.toString().split('.').last.toUpperCase();
    final pp = org.organism.moveStamina[move.name] ?? move.stamina;

    return ElevatedButton(
      onPressed: isLocked ? null : () => _onMoveSelected(move, bm),
      onLongPress: () { 
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${move.name} - \${move.description}')));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isLocked ? Colors.grey[700] : typeColor,
        foregroundColor: isLocked ? Colors.white24 : Colors.white,
        padding: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isLocked ? Colors.grey.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        elevation: isLocked ? 0 : 2,
        shadowColor: Colors.black,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white10,
                width: 1,
              ),
            ),
            child: Image.asset(
              move.type.iconPath,
              width: isNarrow ? 24 : 32,
              height: isNarrow ? 24 : 32,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    move.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: isNarrow ? 8 : 10,
                      fontFamily: 'PressStart2P',
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(color: Colors.black, offset: Offset(-1, -1)),
                        Shadow(color: Colors.black, offset: Offset(1, -1)),
                        Shadow(color: Colors.black, offset: Offset(1, 1)),
                        Shadow(color: Colors.black, offset: Offset(-1, 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: move.category.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        categoryText.substring(0, 4),
                        style: const TextStyle(
                          fontSize: 6,
                          fontFamily: 'PressStart2P',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '\$pp/\${move.stamina}',
                      style: TextStyle(
                        fontSize: isNarrow ? 6 : 8,
                        fontFamily: 'PressStart2P',
                        color: pp > 0 ? Colors.white : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }''';
    text = text.replaceFirst(oldButtonCode, newButtonCode);
    print("Move Button replaced successfully.");
  }

  // Add terrain pads to _buildParticipantArea
  // Wait, I should locate where Image.asset is called within Stack inside _buildParticipantArea
  // The pattern is: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [ Image.asset(org.organism.baseOrganism.sprite, fit: BoxFit.contain)
  
  text = text.replaceAll(
    "Image.asset(org.organism.baseOrganism.sprite, fit: BoxFit.contain),",
    "Stack(alignment: Alignment.bottomCenter, children: [Padding(padding: const EdgeInsets.only(top: 10), child: Image.asset('assets/ui/platform_\${_getBiomePlatform()}.png', width: 120, errorBuilder: (_,__,___) => const SizedBox.shrink(),)), Image.asset('assets/sprites/\${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\\\"\\'\\\", \\\"_\\\")}.png', fit: BoxFit.contain)]),",
  );
  
  // also handle the single quotes version just in case
  text = text.replaceAll(
    "Image.asset(org.organism.baseOrganism.sprite, fit: BoxFit.contain)",
     "Stack(alignment: Alignment.bottomCenter, children: [Padding(padding: const EdgeInsets.only(top: 10), child: Image.asset('assets/ui/platform_\${_getBiomePlatform()}.png', width: 120, errorBuilder: (_,__,___) => const SizedBox.shrink(),)), Image.asset('assets/sprites/\${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\\\"\\'\\\", \\\"_\\\")}.png', fit: BoxFit.contain)])",
  );
  
  print("Sprite replaced with Terrain Pad.");
  
  // Also we need to inject `String _getBiomePlatform()` helper somewhere if it doesn't exist
  if (!text.contains("_getBiomePlatform()")) {
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
    // insert right before _getBiomeThemeColor
    text = text.replaceFirst('Color _getBiomeThemeColor() {', biomePlatformHelper + '\\n  Color _getBiomeThemeColor() {');
  }

  file.writeAsStringSync(text);
  print("Done");
}
