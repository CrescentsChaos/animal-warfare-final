import re

with open('lib/double_battle_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace Move Button
old_match = re.search(r'Widget _buildMoveButton.*?^  }', text, re.MULTILINE | re.DOTALL)
if old_match:
    old_code = old_match.group(0)
    new_code = '''Widget _buildMoveButton(DoubleBattleManager bm, Move move, bool isNarrow) {
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${move.name} - ${move.description}')));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isLocked ? Colors.grey[700] : typeColor,
        foregroundColor: isLocked ? Colors.white24 : Colors.white,
        padding: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isLocked ? Colors.grey.withAlpha(50) : Colors.white.withAlpha(128),
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
                      '${pp}/${move.stamina}',
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
  }'''
    text = text.replace(old_code, new_code)
    print("Move Button replaced successfully.")

# Replace Image asset logic for orgs
text = re.sub(
    r'Image\.asset\(org\.organism\.baseOrganism\.sprite,\s*fit:\s*BoxFit\.contain\)',
    r"Image.asset('assets/sprites/${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\"'\", \"_\")}.png', fit: BoxFit.contain)",
    text
)
print("Sprite name replaced.")

# To add the terrain platform, in _buildParticipantArea, Find the inner Container
text = re.sub(
    r'padding: const EdgeInsets\.all\(4\.0\),\s*child: IgnorePointer\(\s*child: Column\(\s*mainAxisAlignment: MainAxisAlignment\.end,\s*children: \[\s*Expanded\(\s*child: Stack\(\s*alignment: Alignment\.bottomCenter,\s*clipBehavior: Clip\.none,\s*children: \[\s*Image\.asset.*?fit: BoxFit\.contain\),\s*\]\s*\) \?',
    r"MISSING WRONG REGEX",
    text
)

# A better way: replace the sprite stack in Participant Area
# Original:   child: Image.asset('assets/sprites/${org.organism.baseOrganism.name...', fit: BoxFit.contain)
# we wrap it inside a Stack that has the platform. Wait, `_buildParticipantArea` already has a Image.asset().
text = text.replace(
    r"Image.asset('assets/sprites/${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\"'\", \"_\")}.png', fit: BoxFit.contain)",
    r"Stack(alignment: Alignment.bottomCenter, children: [Padding(padding: const EdgeInsets.only(top: 10), child: Image.asset('assets/ui/platform_${_getBiomePlatform()}.png', width: 120, errorBuilder: (_,__,___) => const SizedBox.shrink(),)), Image.asset('assets/sprites/${org.organism.baseOrganism.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll(\"'\", \"_\")}.png', fit: BoxFit.contain)])",
)
print("Added terrain platform.")

with open('lib/double_battle_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print("Done writing modifications to double_battle_screen.dart")
