import 'package:flutter/material.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/theme.dart';

class TypeMatchupSheet {
  static void show(BuildContext context, List<ElementalType> defenderTypes) {
    if (defenderTypes.isEmpty) return;

    final multipliers = _calculateMultipliers(defenderTypes);

    // Group multipliers
    final weaknesses4x = <ElementalType>[];
    final weaknesses2x = <ElementalType>[];
    final neutral1x = <ElementalType>[];
    final resistances05x = <ElementalType>[];
    final resistances025x = <ElementalType>[];
    final immunities0x = <ElementalType>[];

    multipliers.forEach((type, multi) {
      if (multi >= 4.0) {
        weaknesses4x.add(type);
      } else if (multi >= 2.0) {
        weaknesses2x.add(type);
      } else if (multi == 1.0) {
        neutral1x.add(type);
      } else if (multi == 0.5) {
        resistances05x.add(type);
      } else if (multi > 0 && multi <= 0.25) {
        resistances025x.add(type);
      } else if (multi == 0) {
        immunities0x.add(type);
      }
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'DEFENSIVE MATCHUPS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: AppColors.highlightColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: defenderTypes.map((t) => _buildTypeBadge(t)).toList(),
              ),
              const Divider(height: 32, color: Colors.white10),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (weaknesses4x.isNotEmpty)
                      _buildSection(
                        '4.0x WEAKNESS',
                        weaknesses4x,
                        Colors.redAccent,
                      ),
                    if (weaknesses2x.isNotEmpty)
                      _buildSection(
                        '2.0x WEAKNESS',
                        weaknesses2x,
                        Colors.orangeAccent,
                      ),
                    if (immunities0x.isNotEmpty)
                      _buildSection(
                        'IMMUNE (0x)',
                        immunities0x,
                        Colors.cyanAccent,
                      ),
                    if (resistances025x.isNotEmpty)
                      _buildSection(
                        '0.25x RESIST',
                        resistances025x,
                        Colors.greenAccent,
                      ),
                    if (resistances05x.isNotEmpty)
                      _buildSection(
                        '0.5x RESIST',
                        resistances05x,
                        Colors.lightGreenAccent,
                      ),
                    if (neutral1x.isNotEmpty)
                      _buildSection(
                        'NEUTRAL (1.0x)',
                        neutral1x,
                        Colors.white60,
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Map<ElementalType, double> _calculateMultipliers(
    List<ElementalType> defenderTypes,
  ) {
    final results = <ElementalType, double>{};

    // Check effectiveness from EVERY attacking type
    for (final attackerType in ElementalType.values) {
      if (attackerType == ElementalType.basic)
        continue; // Basic moves usually just 1x

      double totalMulti = 1.0;
      for (final defType in defenderTypes) {
        totalMulti *= TypeChart.getEffectiveness(attackerType, defType);
      }
      results[attackerType] = totalMulti;
    }

    return results;
  }

  static Widget _buildSection(
    String title,
    List<ElementalType> types,
    Color labelColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: labelColor,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) => _buildTypeBadge(t, small: true)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static Widget _buildTypeBadge(ElementalType type, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 4 : 6,
      ),
      margin: EdgeInsets.only(right: small ? 0 : 8),
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(small ? 4 : 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 8 : 10,
          fontFamily: 'PressStart2P',
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}
