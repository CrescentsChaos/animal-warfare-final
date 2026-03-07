// lib/widgets/animal_summary_screen.dart
// A full-page, premium mobile-first Pokémon-Summary style screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/theme.dart';

class AnimalSummaryScreen extends StatefulWidget {
  final CapturedOrganism captured;
  final List<CapturedOrganism>? party;
  final int partyIndex;

  const AnimalSummaryScreen({
    super.key,
    required this.captured,
    this.party,
    this.partyIndex = 0,
  });

  @override
  State<AnimalSummaryScreen> createState() => _AnimalSummaryScreenState();
}

class _AnimalSummaryScreenState extends State<AnimalSummaryScreen>
    with TickerProviderStateMixin {
  late CapturedOrganism _current;
  late int _partyIndex;
  late TabController _tabController;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _tabs = [
    ('INFO', Icons.person_outline),
    ('STATS', Icons.bar_chart),
    ('KV', Icons.fitness_center),
    ('DNA', Icons.biotech_outlined),
    ('MOVES', Icons.flash_on_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _current = widget.captured;
    _partyIndex = widget.partyIndex;
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _switchTo(int idx) {
    final party = widget.party;
    if (party == null || idx < 0 || idx >= party.length) return;
    _fadeCtrl.reverse().then((_) {
      setState(() {
        _current = party[idx];
        _partyIndex = idx;
      });
      _fadeCtrl.forward();
    });
  }

  Color get _primaryTypeColor {
    final types = _current.baseOrganism.elementalTypes;
    return types.isNotEmpty ? _typeColor(types.first) : const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    final base = _current.baseOrganism;
    final primaryColor = _primaryTypeColor;
    final screenH = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Column(
          children: [
            // ── Hero Header ──────────────────────────────────────────────
            _buildHeroHeader(context, base, primaryColor, screenH),
            // ── Party Scroll (if provided) ────────────────────────────────
            if (widget.party != null && widget.party!.length > 1)
              _buildPartyScroll(primaryColor),
            // ── Tab Bar ───────────────────────────────────────────────────
            _buildTabBar(primaryColor),
            // ── Tab Content ───────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInfoTab(base),
                    _buildStatsTab(),
                    _buildKVTab(),
                    _buildDNATab(),
                    _buildMovesTab(base),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HERO HEADER ─────────────────────────────────────────────────────────────

  Widget _buildHeroHeader(
    BuildContext context,
    Organism base,
    Color primaryColor,
    double screenH,
  ) {
    final types = base.elementalTypes;
    final xpProgress = _xpProgress();

    return Container(
      height: screenH * 0.32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.85),
            primaryColor.withValues(alpha: 0.3),
            const Color(0xFF0D0D1A),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Background hex pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(painter: _HexPatternPainter(primaryColor)),
              ),
            ),
            // Back button top-left
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Nav arrows top-right
            if (widget.party != null && widget.party!.length > 1)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    _navBtn(
                      Icons.chevron_left,
                      _partyIndex > 0 ? () => _switchTo(_partyIndex - 1) : null,
                      primaryColor,
                    ),
                    const SizedBox(width: 4),
                    _navBtn(
                      Icons.chevron_right,
                      _partyIndex < widget.party!.length - 1
                          ? () => _switchTo(_partyIndex + 1)
                          : null,
                      primaryColor,
                    ),
                  ],
                ),
              ),
            // Content row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT: name, level, types, XP
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            base.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              fontFamily: 'PressStart2P',
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          base.scientificName,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _levelBadge(primaryColor),
                            const SizedBox(width: 8),
                            ...types.map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _typeChip(t),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // XP bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'EXP',
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 7,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                Text(
                                  _current.level >= 100
                                      ? 'MAX'
                                      : '${_current.xp} / ${CapturedOrganism.xpForLevel(_current.level + 1)}',
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 6,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: xpProgress,
                                minHeight: 5,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                                color: primaryColor.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                        if (_current.equippedTalisman != null) ...[
                          const SizedBox(height: 8),
                          _itemBadge(_current.equippedTalisman!.name),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // RIGHT: Sprite
                  _SummarySprite(organism: base, size: 110),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onPressed, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed != null
                ? color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: onPressed != null
                  ? color.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed != null ? Colors.white : Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _levelBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: Text(
        'LV.${_current.level}',
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _itemBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 10, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 7,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PARTY SCROLL ─────────────────────────────────────────────────────────

  Widget _buildPartyScroll(Color primaryColor) {
    final party = widget.party!;
    return Container(
      height: 60,
      color: Colors.black.withValues(alpha: 0.5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: party.length,
        itemBuilder: (context, i) {
          final isSelected = i == _partyIndex;
          return GestureDetector(
            onTap: () => _switchTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _SummarySprite(
                  organism: party[i].baseOrganism,
                  size: 42,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── TAB BAR ──────────────────────────────────────────────────────────────

  Widget _buildTabBar(Color primaryColor) {
    return Container(
      color: const Color(0xFF12121E),
      child: TabBar(
        controller: _tabController,
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 8),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
        ),
        tabs: _tabs
            .map(
              (t) => Tab(
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.$2, size: 16),
                    const SizedBox(height: 3),
                    Text(t.$1),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── INFO TAB ─────────────────────────────────────────────────────────────

  Widget _buildInfoTab(Organism base) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('TRAINER INFO'),
        const SizedBox(height: 12),
        _infoGrid([
          ('NAME', base.name),
          ('NATURE', _current.nature.name),
          ('PRISM TYPE', _current.teraType?.name.toUpperCase() ?? 'NONE'),
          ('LEVEL', '${_current.level}'),
          ('XP', '${_current.xp}'),
          ('NEXT LV.', _current.level >= 100 ? '-' : '${_xpToNext()} XP'),
          ('RARITY', base.rarity),
        ]),
        const SizedBox(height: 24),
        _sectionHeader('SATISFACTION'),
        const SizedBox(height: 12),
        _buildSatisfactionMeter(),
        const SizedBox(height: 24),
        _sectionHeader('HABITAT'),
        const SizedBox(height: 10),
        _descCard(
          base.habitat.isNotEmpty ? base.habitat : '-',
          icon: Icons.terrain_outlined,
        ),
        const SizedBox(height: 20),
        _sectionHeader('FIELD DATA'),
        const SizedBox(height: 10),
        _descCard(
          base.description.isNotEmpty
              ? base.description
              : 'No field data on file.',
          icon: Icons.description_outlined,
        ),
      ],
    );
  }

  Widget _infoGrid(List<(String, String)> data) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.2,
      children: data.map((entry) => _infoGridCell(entry.$1, entry.$2)).toList(),
    );
  }

  Widget _infoGridCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 6,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: label == 'TERA TYPE' && value != 'NONE'
                  ? ElementalTypeX.fromString(value).color
                  : Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _descCard(String text, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryTypeColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS TAB ────────────────────────────────────────────────────────────

  Widget _buildStatsTab() {
    final primaryColor = _primaryTypeColor;
    final nature = _current.nature;
    final lv = _current.level;

    // Current level stats
    final curHp = _current.maxHealth;
    final curAtk = _current.effectiveAttack;
    final curDef = _current.effectiveDefense;
    final curPwr = _current.effectivePower;
    final curRes = _current.effectiveResistance;
    final curSpd = _current.effectiveSpeed;

    // Lv50 stats
    final l50Hp = _current.getMaxHealth(atLevel: 50);
    final l50Atk = _current.getAttack(atLevel: 50);
    final l50Def = _current.getDefense(atLevel: 50);
    final l50Pwr = _current.getPower(atLevel: 50);
    final l50Res = _current.getResistance(atLevel: 50);
    final l50Spd = _current.getSpeed(atLevel: 50);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _legendDot(primaryColor, 'LV.$lv'),
            const SizedBox(width: 14),
            _legendDot(Colors.white24, 'LV.50'),
          ],
        ),
        const SizedBox(height: 16),
        _statRow(
          'HP',
          '${_current.currentHealth}/$curHp',
          curHp,
          l50Hp,
          AppColors.statHealthColor,
          nature.getMultiplier('health'),
        ),
        _statRow(
          'ATTACK',
          '$curAtk',
          curAtk,
          l50Atk,
          AppColors.statAttackColor,
          nature.getMultiplier('attack'),
        ),
        _statRow(
          'DEFENSE',
          '$curDef',
          curDef,
          l50Def,
          AppColors.statDefenseColor,
          nature.getMultiplier('defense'),
        ),
        _statRow(
          'POWER',
          '$curPwr',
          curPwr,
          l50Pwr,
          AppColors.statPowerColor,
          nature.getMultiplier('power'),
        ),
        _statRow(
          'RESISTANCE',
          '$curRes',
          curRes,
          l50Res,
          AppColors.statResistanceStatColor,
          nature.getMultiplier('resistance'),
        ),
        _statRow(
          'SPEED',
          '$curSpd',
          curSpd,
          l50Spd,
          AppColors.statSpeedColor,
          nature.getMultiplier('speed'),
        ),
        const SizedBox(height: 20),
        _natureBanner(
          nature.name,
          nature.increasedStat.name,
          nature.decreasedStat.name,
          primaryColor,
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _statRow(
    String label,
    String displayVal,
    int curVal,
    int l50Val,
    Color color,
    double natureMult,
  ) {
    const maxBar = 600.0;
    final curPerc = (curVal / maxBar).clamp(0.0, 1.0);
    final l50Perc = (l50Val / maxBar).clamp(0.0, 1.0);
    Color valColor = Colors.white;
    if (natureMult > 1.0) valColor = Colors.orange;
    if (natureMult < 1.0) valColor = Colors.lightBlueAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                    color: Colors.white54,
                  ),
                ),
              ),
              Text(
                displayVal,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: valColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (label == 'HEALTH')
                Text(
                  ' (${((curVal / _current.maxHealth) * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Colors.white54,
                  ),
                ),
              const Spacer(),
              Text(
                '$l50Val',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // l50 bar (background)
                LinearProgressIndicator(
                  value: l50Perc,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                // current level bar
                LinearProgressIndicator(
                  value: curPerc,
                  minHeight: 10,
                  backgroundColor: Colors.transparent,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _natureBanner(
    String name,
    String up,
    String down,
    Color primaryColor,
  ) {
    if (up == down) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.balance, color: primaryColor, size: 16),
            const SizedBox(width: 10),
            Text(
              'Nature: $name (Neutral)',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology, color: primaryColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nature: $name',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.orange,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      up.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 7,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.arrow_downward,
                      color: Colors.lightBlueAccent,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      down.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 7,
                        color: Colors.lightBlueAccent,
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
  }

  // ─── DNA / IV TAB ─────────────────────────────────────────────────────────

  Widget _buildDNATab() {
    final ivs = _current.individualValues;
    final data = [
      ('HP', ivs['health'] ?? 0, AppColors.statHealthColor),
      ('Attack', ivs['attack'] ?? 0, AppColors.statAttackColor),
      ('Defense', ivs['defense'] ?? 0, AppColors.statDefenseColor),
      ('Power', ivs['power'] ?? 0, AppColors.statPowerColor),
      ('Resistance', ivs['resistance'] ?? 0, AppColors.statResistanceStatColor),
      ('Speed', ivs['speed'] ?? 0, AppColors.statSpeedColor),
    ];
    final total = data.fold(0, (s, e) => s + e.$2);
    final maxTotal = 6 * 31;
    final quality = total >= 155
        ? ('PERFECT', Colors.orange)
        : total >= 124
        ? ('GREAT', Colors.greenAccent)
        : total >= 93
        ? ('GOOD', Colors.lightBlueAccent)
        : ('AVERAGE', Colors.grey);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('GENETIC VALUES'),
        const SizedBox(height: 14),
        ...data.map((e) => _ivRow(e.$1, e.$2, e.$3)),
        const SizedBox(height: 16),
        // Total row
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                quality.$2.withValues(alpha: 0.15),
                quality.$2.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: quality.$2.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.star, color: quality.$2, size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL GV SCORE',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 7,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$total / $maxTotal',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 13,
                      color: quality.$2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: quality.$2.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quality.$1,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: quality.$2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _descCard(
          'GV (Genetic Values) represent this specimen\'s unique genetic potential. Perfect GVs (31) in each stat are extremely rare.',
          icon: Icons.info_outline,
        ),
      ],
    );
  }

  Widget _ivRow(String label, int iv, Color color) {
    Color ivColor;
    if (iv >= 31) {
      ivColor = Colors.orange;
    } else if (iv >= 25) {
      ivColor = Colors.greenAccent;
    } else if (iv >= 15) {
      ivColor = Colors.lightBlueAccent;
    } else {
      ivColor = Colors.white38;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 7,
                color: Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: iv / 31.0,
                minHeight: 8,
                color: ivColor,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$iv',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: ivColor,
                fontWeight: iv >= 31 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MOVES TAB ────────────────────────────────────────────────────────────

  Widget _buildMovesTab(Organism base) {
    final moveNames = _current.selectedMoveNames;
    final abilityNames = base.abilities
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('COMBAT MOVES'),
        const SizedBox(height: 12),
        ...moveNames.map((mn) {
          final move = Move.findByName(mn);
          final stamina = _current.moveStamina[mn] ?? (move?.stamina ?? 0);
          final maxStamina = move?.stamina ?? 1;
          final ppPerc = maxStamina > 0 ? stamina / maxStamina : 0.0;
          Color ppColor = Colors.greenAccent;
          if (ppPerc <= 0.25)
            ppColor = Colors.redAccent;
          else if (ppPerc <= 0.5)
            ppColor = Colors.orange;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      if (move != null)
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _typeColor(move.type),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mn,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (move != null) _typeChip(move.type),
                    ],
                  ),
                ),
                if (move != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Row(
                      children: [
                        _moveStatPill('PWR', '${move.baseDamage}'),
                        const SizedBox(width: 8),
                        _moveStatPill('ACC', '${move.accuracy}%'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'PP $stamina / $maxStamina',
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 7,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: ppPerc.clamp(0.0, 1.0),
                                  minHeight: 5,
                                  color: ppColor,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _sectionHeader('ABILITY'),
        const SizedBox(height: 12),
        ...abilityNames.map((abilityName) {
          final ab = Ability.findByName(abilityName.trim());
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primaryTypeColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _primaryTypeColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, color: _primaryTypeColor, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      abilityName.trim().toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: _primaryTypeColor,
                      ),
                    ),
                  ],
                ),
                if (ab?.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ab!.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _moveStatPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 6,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── KV TAB ───────────────────────────────────────────────────────────────

  Widget _buildKVTab() {
    final kvs = _current.killValues;
    final statData = [
      ('HP', 'health', AppColors.statHealthColor),
      ('Attack', 'attack', AppColors.statAttackColor),
      ('Defense', 'defense', AppColors.statDefenseColor),
      ('Power', 'power', AppColors.statPowerColor),
      ('Resistance', 'resistance', AppColors.statResistanceStatColor),
      ('Speed', 'speed', AppColors.statSpeedColor),
    ];

    final total = _current.totalKV;
    const maxTotal = CapturedOrganism.maxTotalKV;
    const maxStat = CapturedOrganism.maxStatKV;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('KILL VALUES (KV)'),
        const SizedBox(height: 8),
        _descCard(
          'Defeat animals to earn KV (Kill Values). Each 4 KV = +1 effective stat point. Max 252 per stat, 510 total.',
          icon: Icons.info_outline,
        ),
        const SizedBox(height: 16),
        ...statData.map((entry) {
          final label = entry.$1;
          final key = entry.$2;
          final color = entry.$3;
          final kv = kvs[key] ?? 0;
          final bonus = (kv / 4).floor();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 7,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    Text(
                      '$kv / $maxStat',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: kv >= maxStat
                            ? Colors.amberAccent
                            : Colors.white,
                        fontWeight: kv >= maxStat
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '+$bonus stat',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 6,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (kv / maxStat).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: kv >= maxStat ? Colors.amberAccent : color,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        // Total KV bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryTypeColor.withValues(alpha: 0.12),
                _primaryTypeColor.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _primaryTypeColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: _primaryTypeColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOTAL KV',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: Colors.white54,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$total / $maxTotal',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: _primaryTypeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (total / maxTotal).clamp(0.0, 1.0),
                  minHeight: 10,
                  color: _primaryTypeColor,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSatisfactionMeter() {
    final s = _current.satisfaction;
    final perc = (s / 255).clamp(0.0, 1.0);
    Color color = Colors.redAccent;
    String label = 'Disobedient';
    if (s >= 200) {
      color = Colors.greenAccent;
      label = 'Loyal';
    } else if (s >= 150) {
      color = Colors.blueAccent;
      label = 'Friendly';
    } else if (s >= 100) {
      color = Colors.yellowAccent;
      label = 'Neutral';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'SATISFACTION',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: perc,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$s / 255',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 7,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _primaryTypeColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: _primaryTypeColor,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _typeChip(ElementalType type) {
    final c = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 6, color: c),
      ),
    );
  }

  // ─── XP HELPERS ───────────────────────────────────────────────────────────

  double _xpProgress() {
    if (_current.level >= 100) return 1.0;
    final curLvXp = CapturedOrganism.xpForLevel(_current.level);
    final nxtLvXp = CapturedOrganism.xpForLevel(_current.level + 1);
    if (nxtLvXp <= curLvXp) return 1.0;
    return ((_current.xp - curLvXp) / (nxtLvXp - curLvXp)).clamp(0.0, 1.0);
  }

  int _xpToNext() {
    if (_current.level >= 100) return 0;
    return CapturedOrganism.xpForLevel(_current.level + 1) - _current.xp;
  }

  // ─── TYPE COLORS ──────────────────────────────────────────────────────────

  Color _typeColor(ElementalType type) => type.color;
}

// ── SPRITE WIDGET ──────────────────────────────────────────────────────────────

class _SummarySprite extends StatefulWidget {
  final Organism organism;
  final double size;

  const _SummarySprite({required this.organism, required this.size});

  @override
  State<_SummarySprite> createState() => _SummarySpriteState();
}

class _SummarySpriteState extends State<_SummarySprite> {
  String? _src;
  String _path = '';

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_SummarySprite old) {
    super.didUpdateWidget(old);
    if (old.organism.name != widget.organism.name) _resolve();
  }

  String _local() {
    final n = widget.organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll('-', '_');
    return 'assets/sprites/$n.png';
  }

  Future<void> _resolve() async {
    final lp = _local();
    try {
      await rootBundle.load(lp);
      if (mounted)
        setState(() {
          _src = 'local';
          _path = lp;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _src = 'network';
          _path = widget.organism.sprite;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_src == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white24,
          ),
        ),
      );
    }
    return _src == 'local'
        ? Image.asset(
            _path,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, __, ___) => Icon(
              Icons.pets,
              size: widget.size * 0.5,
              color: Colors.white24,
            ),
          )
        : Image.network(
            _path,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.pets,
              size: widget.size * 0.5,
              color: Colors.white24,
            ),
          );
  }
}

// ── HEX PATTERN PAINTER ────────────────────────────────────────────────────────

class _HexPatternPainter extends CustomPainter {
  final Color color;
  const _HexPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const r = 20.0;
    final w = r * 2;
    final h = r * 1.732;
    for (double y = 0; y < size.height + h; y += h) {
      for (double x = 0; x < size.width + w; x += w * 1.5) {
        final offset = ((y / h).floor() % 2 == 0) ? 0.0 : w * 0.75;
        _hexPath(canvas, paint, Offset(x + offset, y), r);
      }
    }
  }

  void _hexPath(Canvas canvas, Paint paint, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final p = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0)
        path.moveTo(p.dx, p.dy);
      else
        path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexPatternPainter old) => old.color != color;
}
