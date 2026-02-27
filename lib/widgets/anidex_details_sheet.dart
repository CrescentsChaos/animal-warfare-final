import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';

class AnidexDetailsSheet {
  static void show(
    BuildContext context,
    Organism organism, {
    CapturedOrganism? capturedOverride,
    bool showScaledStats = false,
  }) {
    bool isDiscovered = _isDiscovered(context, organism);
    bool isCaptured =
        capturedOverride != null || _isCaptured(context, organism);
    CapturedOrganism? capturedOrg =
        capturedOverride ??
        (isCaptured ? _getCapturedOrganism(context, organism) : null);
    Color rarityColor = _getRarityColor(organism.rarity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryButtonColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _buildPremiumHeader(
                  context,
                  organism,
                  rarityColor,
                  isDiscovered,
                  isCaptured,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (!isDiscovered) ...[_buildClassifiedBanner()],
                    _buildFieldIntel(organism),
                    const SizedBox(height: 32),
                    _buildPremiumDescription(organism, isDiscovered),
                    const SizedBox(height: 32),
                    if (isCaptured) ...[
                      _buildEnhancedStats(
                        organism,
                        capturedOrg,
                        showScaledStats,
                      ),
                      const SizedBox(height: 32),
                      _buildAbilitySection(organism),
                      const SizedBox(height: 32),
                      _buildMoveSection(context, organism, isCaptured),
                    ],
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isCaptured(BuildContext context, Organism organism) {
    final userState = Provider.of<UserState>(context, listen: false);
    return userState.currentUser?.capturedOrganisms.any(
          (co) => co.name == organism.name,
        ) ??
        false;
  }

  static CapturedOrganism? _getCapturedOrganism(
    BuildContext context,
    Organism organism,
  ) {
    final userState = Provider.of<UserState>(context, listen: false);
    try {
      return userState.currentUser?.capturedOrganisms.firstWhere(
        (co) => co.name == organism.name,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isDiscovered(BuildContext context, Organism organism) {
    final userState = Provider.of<UserState>(context, listen: false);
    return userState.currentUser?.discoveredOrganisms.contains(organism.name) ??
        false;
  }

  static Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return const Color(0xFF2ECC71);
      case 'rare':
        return Colors.blueAccent;
      case 'epic':
        return Colors.purpleAccent;
      case 'legendary':
        return Colors.orangeAccent;
      case 'mythical':
        return Colors.pinkAccent;
      default:
        return Colors.white;
    }
  }

  static Color _getTypeColor(ElementalType type) {
    switch (type) {
      case ElementalType.basic:
        return Colors.grey;
      case ElementalType.blaze:
        return Colors.orange;
      case ElementalType.aquatic:
        return Colors.blue;
      case ElementalType.grass:
        return Colors.green;
      case ElementalType.electric:
        return Colors.yellow;
      case ElementalType.cryo:
        return Colors.cyan;
      case ElementalType.martial:
        return Colors.redAccent;
      case ElementalType.toxic:
        return Colors.purple;
      case ElementalType.earth:
        return Colors.brown;
      case ElementalType.flying:
        return Colors.lightBlueAccent;
      case ElementalType.mystic:
        return Colors.pinkAccent;
      case ElementalType.arthropod:
        return Colors.lightGreen;
      case ElementalType.rock:
        return Colors.grey;
      case ElementalType.darkness:
        return Colors.indigo;
      case ElementalType.spectral:
        return Colors.deepPurpleAccent;
      case ElementalType.metal:
        return Colors.blueGrey;
      case ElementalType.aura:
        return Colors.teal;
      case ElementalType.sound:
        return Colors.deepOrange;
      case ElementalType.holy:
        return Colors.amber;
      case ElementalType.drake:
        return Colors.deepPurple;
    }
  }

  static Widget _buildPremiumHeader(
    BuildContext context,
    Organism org,
    Color color,
    bool discovered,
    bool isCaptured,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 360,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.2), Colors.transparent],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          ),
        ),
        Positioned(
          top: 40,
          child: Column(
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withOpacity(0.3), Colors.transparent],
                  ),
                ),
                child: Hero(
                  tag: 'anidex_sprite_${org.name}',
                  child: OrganismSpriteDisplay(
                    organism: org,
                    isDiscovered: discovered,
                    isCaptured: isCaptured,
                    silhouetteColor: Colors.black,
                    height: 180,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                discovered ? org.name.toUpperCase() : '???',
                style: AppTextStyles.headline(
                  context,
                  baseSize: 14,
                  color: discovered ? Colors.white : Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                discovered
                    ? org.scientificName.toUpperCase()
                    : 'CODE: [UNKNOWN]',
                style: TextStyle(
                  color: color.withOpacity(0.5),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: discovered
                      ? (isCaptured ? color.withOpacity(0.2) : Colors.white10)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: discovered
                        ? (isCaptured ? color.withOpacity(0.4) : Colors.white24)
                        : Colors.white10,
                  ),
                ),
                child: Text(
                  discovered
                      ? (isCaptured ? org.rarity.toUpperCase() : 'UNIDENTIFIED')
                      : 'UNIDENTIFIED',
                  style: TextStyle(
                    color: discovered
                        ? (isCaptured ? color : Colors.white54)
                        : Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildClassifiedBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_person, color: Colors.redAccent, size: 32),
          SizedBox(width: 20),
          Expanded(
            child: Text(
              'SECURITY CLEARANCE REQUIRED: IDENTIFY THIS SPECIES IN THE FIELD TO UNLOCK BIOMETRIC DATA.',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFieldIntel(Organism org) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('FIELD INTEL'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HABITAT SIGNATURE DETECTED:',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: org.habitat.split(',').map((h) {
                    final biome = h.trim();
                    final fileName = biome.toLowerCase().replaceAll(' ', '_');
                    final assetPath = 'assets/biomes/$fileName.png';
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.highlightColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              color: Colors.black.withOpacity(0.5),
                              colorBlendMode: BlendMode.darken,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.black45,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white10,
                                      size: 24,
                                    ),
                                  ),
                            ),
                            Center(
                              child: Text(
                                biome.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.highlightColor,
                                  fontFamily: 'PressStart2P',
                                  fontSize: 7,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildPremiumDescription(Organism org, bool discovered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MISSION BRIEF'),
        const SizedBox(height: 12),
        Text(
          discovered
              ? org.description
              : 'NO FIELD DATA AVAILABLE FOR THIS SPECIMEN.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
            height: 1.6,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  static Widget _buildEnhancedStats(
    Organism org,
    CapturedOrganism? capturedOrg,
    bool showScaledStats,
  ) {
    return Column(
      children: [
        if (capturedOrg != null && showScaledStats)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'BASE (LV.50)',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontFamily: 'PressStart2P',
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'VS',
                  style: TextStyle(color: Colors.white24, fontSize: 8),
                ),
                const SizedBox(width: 8),
                Text(
                  'CURRENT (LV.${capturedOrg.level})',
                  style: const TextStyle(
                    color: AppColors.highlightColor,
                    fontSize: 8,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ],
            ),
          ),
        _buildStatRow(
          'HEALTH',
          org.health,
          500,
          AppColors.statHealthColor,
          Icons.favorite,
          currentVal: showScaledStats ? capturedOrg?.maxHealth : null,
        ),
        _buildStatRow(
          'ATTACK',
          org.attack,
          200,
          AppColors.statAttackColor,
          Icons.bolt,
          currentVal: showScaledStats ? capturedOrg?.effectiveAttack : null,
        ),
        _buildStatRow(
          'DEFENSE',
          org.defense,
          200,
          AppColors.statDefenseColor,
          Icons.shield,
          currentVal: showScaledStats ? capturedOrg?.effectiveDefense : null,
        ),
        _buildStatRow(
          'POWER',
          org.power,
          200,
          AppColors.statPowerColor,
          Icons.auto_awesome,
          currentVal: showScaledStats ? capturedOrg?.effectivePower : null,
        ),
        _buildStatRow(
          'RESISTANCE',
          org.resistance,
          200,
          AppColors.statResistanceStatColor,
          Icons.psychology,
          currentVal: showScaledStats ? capturedOrg?.effectiveResistance : null,
        ),
        _buildStatRow(
          'SPEED',
          org.speed,
          200,
          AppColors.statSpeedColor,
          Icons.speed,
          currentVal: showScaledStats ? capturedOrg?.effectiveSpeed : null,
        ),
      ],
    );
  }

  static Widget _buildStatRow(
    String label,
    int baseVal,
    int max,
    Color color,
    IconData icon, {
    int? currentVal,
  }) {
    final basePerc = (baseVal / max).clamp(0.0, 1.0);
    // If we have a current value, we want to show it. It might exceed max.
    final currentPerc = currentVal != null
        ? (currentVal / max).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$baseVal',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'PressStart2P',
                ),
              ),
              if (currentVal != null) ...[
                const SizedBox(width: 12),
                Text(
                  '$currentVal',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PressStart2P',
                    shadows: [
                      Shadow(color: color.withOpacity(0.5), blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: basePerc,
                  color: Colors.white38,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  minHeight: 12,
                ),
              ),
              if (currentVal != null && currentVal > baseVal)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: currentPerc,
                    color: color.withOpacity(0.7),
                    backgroundColor: Colors.transparent,
                    minHeight: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildAbilitySection(Organism org) {
    final abs = org.abilities
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SYSTEM CAPABILITIES'),
        const SizedBox(height: 16),
        ...abs.map((name) {
          final ab = Ability.findByName(name.trim());
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.flash_on,
                      color: AppColors.highlightColor,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      name.trim().toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.highlightColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ab?.description ?? 'EFFECTS UNKNOWN FOR THIS SUBSYSTEM.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static Widget _buildMoveSection(
    BuildContext context,
    Organism org,
    bool isCaptured,
  ) {
    final moves = org.moves
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('COMBAT ARCHIVE'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'MOVE',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'PWR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'ACC',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'PP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontFamily: 'PressStart2P',
                        ),
                      ),
                    ),
                    SizedBox(width: 24), // Space for info icon
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              ...moves.map((mName) {
                final move = Move.findByName(mName.trim());
                if (move == null) return const SizedBox.shrink();

                return GestureDetector(
                  onLongPress: () => _showMoveDetails(context, move),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                move.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF2ECC71),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                isCaptured
                                    ? (move.baseDamage > 0
                                          ? '${move.baseDamage}'
                                          : '-')
                                    : '?',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                isCaptured ? '${move.accuracy}' : '?',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                isCaptured ? '${move.stamina}' : '?',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.white38,
                                size: 16,
                              ),
                              onPressed: () => _showMoveDetails(context, move),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        if (isCaptured) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(
                                    move.type,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _getTypeColor(
                                      move.type,
                                    ).withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  move.type.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _getTypeColor(move.type),
                                    fontSize: 8,
                                    fontFamily: 'PressStart2P',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                move.category == MoveCategory.physical
                                    ? Icons.fitness_center
                                    : move.category == MoveCategory.special
                                    ? Icons.auto_awesome
                                    : Icons.shield,
                                size: 12,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                move.category.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                  fontFamily: 'PressStart2P',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  static void _showMoveDetails(BuildContext context, Move move) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.highlightColor, width: 1),
        ),
        title: Text(
          move.name.toUpperCase(),
          style: const TextStyle(
            color: AppColors.highlightColor,
            fontFamily: 'PressStart2P',
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(move.type),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    move.type.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: move.category == MoveCategory.physical
                        ? Colors.redAccent
                        : move.category == MoveCategory.special
                        ? Colors.blueAccent
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    move.category.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              move.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(color: AppColors.highlightColor),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, color: AppColors.highlightColor),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: AppColors.highlightColor,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class OrganismSpriteDisplay extends StatelessWidget {
  final Organism organism;
  final bool isDiscovered;
  final bool isCaptured;
  final Color silhouetteColor;
  final double height;

  const OrganismSpriteDisplay({
    super.key,
    required this.organism,
    required this.isDiscovered,
    this.isCaptured = true,
    required this.silhouetteColor,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDiscovered) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(silhouetteColor, BlendMode.srcIn),
        child: Image.asset(
          _getSpritePath(),
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.question_mark, size: height, color: Colors.white24),
        ),
      );
    }

    if (!isCaptured) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: Image.asset(
          _getSpritePath(),
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.question_mark, size: height, color: Colors.white24),
        ),
      );
    }

    return Image.asset(
      _getSpritePath(),
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.broken_image, size: height, color: Colors.white24),
    );
  }

  String _getSpritePath() {
    final fileName = organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll("-", '_');
    return 'assets/sprites/$fileName.png';
  }
}
