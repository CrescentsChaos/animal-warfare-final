import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/widgets/type_matchup_sheet.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/services/audio_service.dart';

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
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
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
                    if (isDiscovered) ...[
                      _buildMatchupButton(context, organism),
                      const SizedBox(height: 24),
                    ],
                    _buildFieldIntel(organism),
                    const SizedBox(height: 16),
                    if (isDiscovered) ...[
                      _buildClassificationSection(organism),
                    ],
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
    if (userState.currentUser?.anidexUnlocked == true) return true;
    // Use the persistent 'captured' flag in speciesStats
    final stats = userState.currentUser?.speciesStats[organism.name];
    if (stats != null && stats['captured'] == 1) return true;

    // Fallback to current box
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
    if (organism.habitat == 'Global Registry') return true;
    final userState = Provider.of<UserState>(context, listen: false);
    if (userState.currentUser?.anidexUnlocked == true) return true;
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
        return const Color.fromARGB(255, 168, 168, 130);
      case ElementalType.flying:
        return const Color(0xFFA98FF3);
      case ElementalType.aquatic:
        return const Color.fromARGB(255, 46, 60, 255);
      case ElementalType.earth:
        return const Color(0xFFE2BF65);
      case ElementalType.cryo:
        return const Color.fromARGB(255, 0, 247, 255);
      case ElementalType.toxic:
        return const Color(0xFFA33EA1);
      case ElementalType.rock:
        return const Color.fromARGB(255, 158, 97, 5);
      case ElementalType.arthropod:
        return const Color.fromARGB(255, 111, 207, 0);
      case ElementalType.electric:
        return const Color.fromARGB(255, 255, 251, 27);
      case ElementalType.spectral:
        return const Color.fromARGB(255, 91, 11, 240);
      case ElementalType.martial:
        return const Color.fromARGB(255, 160, 24, 0);
      case ElementalType.blaze:
        return const Color.fromARGB(255, 226, 72, 0);
      case ElementalType.grass:
        return const Color.fromARGB(255, 22, 131, 0);
      case ElementalType.mystic:
        return const Color.fromARGB(255, 255, 81, 162);
      case ElementalType.darkness:
        return const Color.fromARGB(255, 37, 36, 37);
      case ElementalType.drake:
        return const Color.fromARGB(255, 76, 0, 255);
      case ElementalType.metal:
        return const Color.fromARGB(255, 172, 168, 168);
      case ElementalType.aura:
        return const Color.fromARGB(255, 229, 255, 79);
      case ElementalType.sound:
        return const Color.fromARGB(255, 166, 70, 255);
      case ElementalType.holy:
        return const Color.fromARGB(255, 255, 208, 0);
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
              colors: [color.withValues(alpha: 0.2), Colors.transparent],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: discovered
              ? IconButton(
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: 'LISTEN TO CRY',
                  onPressed: () {
                    AudioService.instance.playOrganismCry(org.cry);
                  },
                )
              : const SizedBox.shrink(),
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
                    colors: [color.withValues(alpha: 0.3), Colors.transparent],
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
                  color: color.withValues(alpha: 0.5),
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
                      ? (isCaptured
                            ? color.withValues(alpha: 0.2)
                            : Colors.white10)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: discovered
                        ? (isCaptured
                              ? color.withValues(alpha: 0.4)
                              : Colors.white24)
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
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
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
                          color: AppColors.highlightColor.withValues(
                            alpha: 0.3,
                          ),
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
                              color: Colors.black.withValues(alpha: 0.5),
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    biome.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.highlightColor,
                                      fontFamily: 'PressStart2P',
                                      fontSize: 7,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
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

  static Widget _buildClassificationSection(Organism org) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildClassificationBadge(
              'CLASS',
              org.animalClass,
              'assets/icon/${org.animalClass.toLowerCase().replaceAll(' ', '_')}.png',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildClassificationBadge(
              'DIET',
              org.diet,
              'assets/icon/${org.diet.toLowerCase().replaceAll(' ', '_')}.png',
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildClassificationBadge(
    String label,
    String value,
    String iconPath,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Image.asset(
            iconPath,
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.help_outline,
              color: Colors.white24,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            color: Colors.white.withValues(alpha: 0.6),
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
        const SizedBox(height: 16),
        _buildStatRow(
          'TOTAL (BST)',
          org.bst,
          1000, // Reasonable max for BST display
          AppColors.highlightColor,
          Icons.assessment,
          currentVal: showScaledStats
              ? (capturedOrg != null
                    ? (capturedOrg.maxHealth +
                          capturedOrg.effectiveAttack +
                          capturedOrg.effectiveDefense +
                          capturedOrg.effectivePower +
                          capturedOrg.effectiveResistance +
                          capturedOrg.effectiveSpeed)
                    : null)
              : null,
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
                      Shadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
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
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  minHeight: 12,
                ),
              ),
              if (currentVal != null && currentVal > baseVal)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: currentPerc,
                    color: color.withValues(alpha: 0.7),
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
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    color: Colors.white.withValues(alpha: 0.4),
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
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                          color: Colors.white.withValues(alpha: 0.05),
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
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _getTypeColor(
                                      move.type,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      move.type.iconPath,
                                      width: 14,
                                      height: 14,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox.shrink(),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      move.type.name.toUpperCase(),
                                      style: TextStyle(
                                        color: _getTypeColor(move.type),
                                        fontSize: 8,
                                        fontFamily: 'PressStart2P',
                                      ),
                                    ),
                                  ],
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        move.type.iconPath,
                        width: 16,
                        height: 16,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        move.type.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

  static Widget _buildMatchupButton(BuildContext context, Organism org) {
    return InkWell(
      onTap: () => TypeMatchupSheet.show(context, org.elementalTypes),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.highlightColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: const [
            Icon(
              Icons.shield_outlined,
              color: AppColors.highlightColor,
              size: 20,
            ),
            SizedBox(width: 16),
            Text(
              'VIEW DEFENSIVE MATCHUPS',
              style: TextStyle(
                color: AppColors.highlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
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
    final spritePath = _getSpritePath();
    final isNetwork = spritePath.startsWith('http');

    if (!isDiscovered) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(silhouetteColor, BlendMode.srcIn),
        child: _buildImage(spritePath, isNetwork),
      );
    }

    if (!isCaptured) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: _buildImage(spritePath, isNetwork),
      );
    }

    return _buildImage(spritePath, isNetwork);
  }

  Widget _buildImage(String path, bool isNetwork) {
    if (isNetwork) {
      return Image.network(
        path,
        height: height,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: height,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.broken_image, size: height, color: Colors.white24),
      );
    }
    return Image.asset(
      path,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.question_mark, size: height, color: Colors.white24),
    );
  }

  String _getSpritePath() {
    if (organism.sprite.startsWith('http')) return organism.sprite;
    if (organism.sprite.isNotEmpty && !organism.sprite.contains(' ')) {
      if (organism.sprite.startsWith('assets/')) return organism.sprite;
      return 'assets/sprites/${organism.sprite}';
    }
    
    final fileName = organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll("-", '_');
    return 'assets/sprites/$fileName.png';
  }
}
