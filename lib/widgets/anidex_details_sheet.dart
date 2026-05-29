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
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';

class AnidexDetailsPage extends StatelessWidget {
  final Organism organism;
  final CapturedOrganism? capturedOverride;
  final bool showScaledStats;

  const AnidexDetailsPage({
    super.key,
    required this.organism,
    this.capturedOverride,
    this.showScaledStats = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isDiscovered = _isDiscovered(context, organism);
    bool isCaptured =
        capturedOverride != null || _isCaptured(context, organism);
    CapturedOrganism? capturedOrg =
        capturedOverride ??
        (isCaptured ? _getCapturedOrganism(context, organism) : null);
    Color rarityColor = _getRarityColor(organism.rarity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context, rarityColor, isDiscovered, isCaptured),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!isDiscovered) ...[_buildClassifiedBanner()],
                if (isDiscovered) ...[
                  _buildMatchupButton(context),
                  const SizedBox(height: 24),
                ],
                _buildFieldIntel(),
                const SizedBox(height: 32),
                if (isDiscovered) ...[
                  _buildClassificationSection(context),
                  const SizedBox(height: 32),
                ],
                _buildMissionBrief(isDiscovered),
                const SizedBox(height: 32),
                if (isCaptured) ...[
                  _buildEnhancedStats(capturedOrg),
                  const SizedBox(height: 32),
                  _buildAbilitySection(),
                  const SizedBox(height: 32),
                  _buildMoveSection(context, isCaptured),
                  const SizedBox(height: 32),
                ],
                if (isDiscovered) ...[
                  _buildDropsSection(context),
                  const SizedBox(height: 32),
                ],
                const SizedBox(height: 68),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(
    BuildContext context,
    Color color,
    bool discovered,
    bool isCaptured,
  ) {
    return SliverAppBar(
      expandedHeight: 400,
      backgroundColor: AppColors.surface,
      pinned: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (discovered)
          IconButton(
            icon: const Icon(
              Icons.volume_up_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () =>
                AudioService.instance.playOrganismCry(organism.cry),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            // Background Image/Gradient
            Container(
              decoration: BoxDecoration(
                image: discovered
                    ? DecorationImage(
                        image: AssetImage(
                          _getRarityBackground(organism.rarity),
                        ),
                        fit: BoxFit.cover,
                        opacity: 0.4,
                      )
                    : null,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.1), AppColors.background],
                ),
              ),
            ),

            // Sprite Display
            Positioned(
              top: 80,
              child: Column(
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Hero(
                      tag: 'anidex_sprite_${organism.name}',
                      child: OrganismSpriteDisplay(
                        organism: organism,
                        isDiscovered: discovered,
                        isCaptured: isCaptured,
                        silhouetteColor: Colors.black,
                        height: 200,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      discovered ? organism.name.toUpperCase() : 'CLASSIFIED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: discovered ? Colors.white : Colors.white24,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    discovered ? organism.scientificName : 'UNKNOWN SPECIMEN',
                    style: GoogleFonts.inter(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRarityTag(discovered, isCaptured, color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRarityTag(bool discovered, bool isCaptured, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: discovered && isCaptured
            ? color.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: discovered && isCaptured
              ? color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        discovered
            ? (isCaptured ? organism.rarity.toUpperCase() : 'UNIDENTIFIED')
            : 'UNIDENTIFIED',
        style: GoogleFonts.orbitron(
          color: discovered && isCaptured ? color : Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildClassifiedBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.redAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'SECURITY CLEARANCE REQUIRED. IDENTIFY THIS SPECIES TO UNLOCK BIOMETRIC ARCHIVE.',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldIntel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('FIELD INTEL'),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: organism.habitat.split(',').map((h) {
              final biome = h.trim();
              final fileName = biome.toLowerCase().replaceAll(' ', '_');
              final assetPath = 'assets/biomes/$fileName.png';
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black45),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            biome.toUpperCase(),
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1,
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
    );
  }

  Widget _buildClassificationSection(BuildContext context) {
    final userState = Provider.of<UserState>(context, listen: false);
    final unitSystem = userState.currentUser?.unitSystem ?? 'metric';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('BIOMETRIC SIGNATURE'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildInfoCard(
              'CLASS',
              organism.animalClass,
              'assets/icon/${organism.animalClass.toLowerCase().replaceAll(' ', '_')}.png',
            ),
            _buildInfoCard(
              'ORDER',
              organism.order,
              null,
              iconData: Icons.account_tree_outlined,
            ),
            _buildInfoCard(
              'FAMILY',
              organism.family,
              null,
              iconData: Icons.hub_outlined,
            ),
            _buildInfoCard(
              'SUBFAMILY',
              organism.subfamily,
              null,
              iconData: Icons.bubble_chart_outlined,
            ),
            _buildInfoCard(
              'DIET',
              organism.diet,
              'assets/icon/${organism.diet.toLowerCase().replaceAll(' ', '_')}.png',
            ),
            _buildInfoCard(
              'SIZE',
              organism.formattedSizeForSystem(unitSystem),
              null,
              iconData: Icons.straighten,
            ),
            _buildInfoCard(
              'WEIGHT',
              organism.formattedWeightForSystem(unitSystem),
              null,
              iconData: Icons.scale,
            ),
            _buildInfoCard(
              'ROBUSTNESS',
              organism.formattedRobustness,
              null,
              iconData: Icons.fitness_center,
            ),
            _buildInfoCard(
              'ACTIVITY',
              organism.activeTime,
              null,
              iconData: Icons.wb_sunny_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    String? iconPath, {
    IconData? iconData,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          if (iconPath != null)
            Image.asset(
              iconPath,
              width: 24,
              height: 24,
              errorBuilder: (_, _, _) => Icon(
                iconData ?? Icons.info_outline,
                color: AppColors.highlightColor,
                size: 20,
              ),
            )
          else
            Icon(
              iconData ?? Icons.info_outline,
              color: AppColors.highlightColor,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

  Widget _buildMissionBrief(bool discovered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MISSION BRIEF'),
        const SizedBox(height: 12),
        Text(
          discovered
              ? organism.description
              : 'DATA ENCRYPTED. FIELD OBSERVATION REQUIRED.',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
            height: 1.6,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedStats(CapturedOrganism? capturedOrg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('COMBAT ANALYSIS'),
        const SizedBox(height: 20),
        _buildStatRow(
          'HEALTH',
          organism.health,
          500,
          AppColors.statHealthColor,
          'health',
        ),
        _buildStatRow(
          'ATTACK',
          organism.attack,
          200,
          AppColors.statAttackColor,
          'attack',
        ),
        _buildStatRow(
          'DEFENSE',
          organism.defense,
          200,
          AppColors.statDefenseColor,
          'defense',
        ),
        _buildStatRow(
          'POWER',
          organism.power,
          200,
          AppColors.statPowerColor,
          'power',
        ),
        _buildStatRow(
          'RESISTANCE',
          organism.resistance,
          200,
          AppColors.statResistanceStatColor,
          'resistance',
        ),
        _buildStatRow(
          'SPEED',
          organism.speed,
          200,
          AppColors.statSpeedColor,
          'speed',
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    int value,
    int max,
    Color color,
    String iconName,
  ) {
    final percent = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icon/$iconName.png',
                width: 16,
                height: 16,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.bolt, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$value',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                height: 6,
                width:
                    percent *
                    300, // Should use LayoutBuilder for better precision
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.5), color],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbilitySection() {
    final abs = organism.abilities
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('CORE SYSTEMS'),
        const SizedBox(height: 16),
        ...abs.map((name) {
          final ab = Ability.findByName(name.trim());
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.settings_input_component,
                      color: AppColors.highlightColor,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      name.trim().toUpperCase(),
                      style: GoogleFonts.orbitron(
                        color: AppColors.highlightColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ab?.description ?? 'UNKNOWN EFFECT.',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
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

  Widget _buildMoveSection(BuildContext context, bool isCaptured) {
    final moves = organism.moves
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('COMBAT ARCHIVE'),
        const SizedBox(height: 16),
        ...moves.map((mName) {
          final move = Move.findByName(mName.trim());
          if (move == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTypeIcon(move.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            move.name.toUpperCase(),
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            move.category.name.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white24,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildMoveStat('ATK', '${move.baseDamage}'),
                    _buildMoveStat('ACC', '${move.accuracy}'),
                    _buildMoveStat('STM', '${move.stamina}'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  move.description,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMoveStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white24,
              fontSize: 7,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(ElementalType type) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: _getTypeColor(type).withValues(alpha: 0.3)),
      ),
      child: Image.asset(type.iconPath, width: 16, height: 16),
    );
  }

  Widget _buildMatchupButton(BuildContext context) {
    return InkWell(
      onTap: () => TypeMatchupSheet.show(context, organism.elementalTypes),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.highlightColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.highlightColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.analytics_outlined,
              color: AppColors.highlightColor,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              'DEFENSIVE ANALYSIS',
              style: GoogleFonts.orbitron(
                color: AppColors.highlightColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white24,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.highlightColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.orbitron(
            fontSize: 10,
            color: AppColors.highlightColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  // --- Helper Methods ---

  static bool _isCaptured(BuildContext context, Organism organism) {
    final userState = Provider.of<UserState>(context, listen: false);
    if (userState.currentUser?.anidexUnlocked == true) return true;
    final stats = userState.currentUser?.speciesStats[organism.name];
    if (stats != null && stats['captured'] == 1) return true;
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

  static String _getRarityBackground(String rarity) {
    final r = rarity.toLowerCase();
    if (r == 'common') return 'assets/icon/common.png';
    if (r == 'uncommon') return 'assets/icon/uncommon.png';
    if (r == 'rare') return 'assets/icon/rare.png';
    if (r == 'epic') return 'assets/icon/epic.png';
    if (r == 'legendary') return 'assets/icon/legendary.png';
    if (r == 'mythical') return 'assets/icon/mythical.png';
    return 'assets/icon/common.png';
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

  Widget _buildDropsSection(BuildContext context) {
    if (organism.drops.isEmpty ||
        organism.drops.trim().toLowerCase() == 'n/a') {
      return const SizedBox.shrink();
    }

    final dropsList = organism.drops
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (dropsList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('🎁 LOOT DROPS'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: dropsList
              .map((dropName) => DropChip(dropName: dropName))
              .toList(),
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
    return _buildImage(context, spritePath, isNetwork);
  }

  Widget _buildImage(BuildContext context, String path, bool isNetwork) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: InteractiveViewer(
              maxScale: 5.0,
              child: buildSilhouetteSprite(
                imageUrl: path,
                silhouetteColor: isDiscovered ? null : Colors.black45,
                outlineColor: isDiscovered ? Colors.black : Colors.white,
                outlineWidth: 2.0,
                height: MediaQuery.of(context).size.height * 0.5,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
      child: buildSilhouetteSprite(
        imageUrl: path,
        silhouetteColor: isDiscovered ? null : Colors.black45,
        outlineColor: isDiscovered ? Colors.black : Colors.white,
        outlineWidth: 2.0,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }

  String _getSpritePath() {
    if (organism.sprite.isNotEmpty &&
        !organism.sprite.startsWith('http') &&
        !organism.sprite.contains(' ')) {
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

class DropChip extends StatefulWidget {
  final String dropName;
  const DropChip({super.key, required this.dropName});

  @override
  State<DropChip> createState() => _DropChipState();
}

class _DropChipState extends State<DropChip> {
  bool _imageError = false;

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final assetName = widget.dropName.toLowerCase().replaceAll(' ', '-');
    final assetPath = 'assets/items/$assetName.png';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_imageError) ...[
            Image.asset(
              assetPath,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _imageError = true;
                    });
                  }
                });
                return const SizedBox.shrink();
              },
            ),
            if (!_imageError) const SizedBox(width: 8),
          ],
          Text(
            _toTitleCase(widget.dropName),
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
