import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper model
// ─────────────────────────────────────────────────────────────────────────────
class _SpeciesRecord {
  final String species;
  final int matches;
  final int wins;
  final int losses;
  final int damageDealt;
  final int damageTaken;
  final int kills;
  final double winrate;
  final ({String label, Color color, int order}) tier;

  const _SpeciesRecord({
    required this.species,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.damageDealt,
    required this.damageTaken,
    required this.kills,
    required this.winrate,
    required this.tier,
  });
}

class _RankedEntry {
  final _SpeciesRecord record;
  final int globalRank;
  _RankedEntry(this.record, this.globalRank);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class RankedScreen extends StatefulWidget {
  const RankedScreen({super.key});

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

enum _SortMode { tier, winRate, damage, matches }

class _RankedScreenState extends State<RankedScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.tier;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        _sortMode = _SortMode.values[_tabController.index];
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  ({String label, Color color, int order}) _getRankTier(
    double winrate,
    int matches,
  ) {
    if (matches < 3) return (label: '?', color: Colors.grey, order: 99);
    if (winrate >= 0.70 && matches >= 5) {
      return (label: 'S', color: const Color(0xFFFF4E4E), order: 0);
    }
    if (winrate >= 0.55) {
      return (label: 'A', color: Colors.orangeAccent, order: 1);
    }
    if (winrate >= 0.45) {
      return (label: 'B', color: Colors.yellowAccent, order: 2);
    }
    if (winrate >= 0.30) {
      return (label: 'C', color: Colors.cyanAccent, order: 3);
    }
    return (label: 'D', color: Colors.blueGrey, order: 4);
  }

  List<_SpeciesRecord> _buildRecords(UserData user) {
    final stats = user.speciesStats;
    return stats.entries.map((e) {
      final matches = e.value['matches'] ?? 0;
      final wins = e.value['wins'] ?? 0;
      final losses = matches - wins;
      final damageDealt = e.value['damageDealt'] ?? 0;
      final damageTaken = e.value['damageTaken'] ?? 0;
      final kills = e.value['kills'] ?? 0;
      final winrate = matches > 0 ? wins / matches : 0.0;
      final tier = _getRankTier(winrate, matches);
      return _SpeciesRecord(
        species: e.key,
        matches: matches,
        wins: wins,
        losses: losses,
        damageDealt: damageDealt,
        damageTaken: damageTaken,
        kills: kills,
        winrate: winrate,
        tier: tier,
      );
    }).toList();
  }

  List<_RankedEntry> _sortedFiltered(List<_SpeciesRecord> records) {
    // 1. Sort the full list first to establish global ranks
    final fullList = List<_SpeciesRecord>.from(records);
    switch (_sortMode) {
      case _SortMode.tier:
        fullList.sort((a, b) {
          final t = a.tier.order.compareTo(b.tier.order);
          if (t != 0) return t;
          return b.winrate.compareTo(a.winrate);
        });
      case _SortMode.winRate:
        fullList.sort((a, b) => b.winrate.compareTo(a.winrate));
      case _SortMode.damage:
        fullList.sort((a, b) => b.damageDealt.compareTo(a.damageDealt));
      case _SortMode.matches:
        fullList.sort((a, b) => b.matches.compareTo(a.matches));
    }

    // 2. Map to entry with global rank
    final entries = <_RankedEntry>[];
    for (int i = 0; i < fullList.length; i++) {
      entries.add(_RankedEntry(fullList[i], i + 1));
    }

    // 3. Apply search filter
    if (_searchQuery.isEmpty) return entries;
    return entries
        .where(
          (e) => e.record.species.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final user = userState.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : _buildBody(user, theme),
    );
  }

  Widget _buildBody(UserData user, ThemeData theme) {
    final records = _buildRecords(user);
    final totalMatches = records.fold<int>(0, (s, r) => s + r.matches);
    final totalWins = records.fold<int>(0, (s, r) => s + r.wins);
    final avgWinrate = totalMatches > 0 ? totalWins / totalMatches : 0.0;
    final totalKills = records.fold<int>(0, (s, r) => s + r.kills);

    final filtered = _sortedFiltered(records);

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(records, totalMatches, avgWinrate, totalKills),
        SliverToBoxAdapter(child: _buildSearchAndSort()),
        filtered.isEmpty
            ? SliverFillRemaining(child: _buildEmpty(records.isEmpty))
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildCard(
                    ctx,
                    filtered[i].record,
                    filtered[i].globalRank,
                  ),
                  childCount: filtered.length,
                ),
              ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildSliverAppBar(
    List<_SpeciesRecord> records,
    int totalMatches,
    double avgWr,
    int totalKills,
  ) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D1A),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient bg
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1040), Color(0xFF0D0D1A)],
                ),
              ),
            ),
            // Glow orbs
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: 20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFD700),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'BATTLE ARCHIVE',
                        style: AppTextStyles.headline(
                          context,
                          baseSize: 16,
                          color: Colors.white,
                        ).copyWith(letterSpacing: 2.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _headerStat(
                        'BATTLES',
                        '$totalMatches',
                        Colors.white70,
                        Icons.sports_mma,
                      ),
                      const SizedBox(width: 20),
                      _headerStat(
                        'AVG WIN%',
                        '${(avgWr * 100).toStringAsFixed(1)}%',
                        avgWr >= 0.5 ? Colors.greenAccent : Colors.redAccent,
                        Icons.trending_up,
                      ),
                      const SizedBox(width: 20),
                      _headerStat(
                        'TOTAL KOs',
                        '$totalKills',
                        Colors.amberAccent,
                        Icons.flash_on,
                      ),
                      const SizedBox(width: 20),
                      _headerStat(
                        'SPECIES',
                        '${records.length}',
                        Colors.cyanAccent,
                        Icons.pets,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      title: null, // Removed redundant center title
      centerTitle: true,
    );
  }

  Widget _headerStat(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 6,
                color: Colors.white38,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndSort() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 9,
            ),
            decoration: InputDecoration(
              hintText: 'Search species...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 9),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white38,
                size: 18,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white38,
                        size: 16,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF7C3AED),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        // Sort tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Text(
                'SORT:',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _sortChip('TIER', _SortMode.tier, Icons.military_tech),
                      _sortChip('WIN%', _SortMode.winRate, Icons.trending_up),
                      _sortChip('DAMAGE', _SortMode.damage, Icons.bolt),
                      _sortChip('BATTLES', _SortMode.matches, Icons.history),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _sortChip(String label, _SortMode mode, IconData icon) {
    final active = _sortMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _sortMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFF7C3AED)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 10,
                color: active ? const Color(0xFF7C3AED) : Colors.white38,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: active ? const Color(0xFF7C3AED) : Colors.white38,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _SpeciesRecord r, int globalRank) {
    final tierColor = r.tier.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => _showDetail(context, r),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13132A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tierColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: tierColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Rank badge
                    Text(
                      '#$globalRank',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Species name
                    Expanded(
                      child: Text(
                        r.species.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Tier badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tierColor, width: 1),
                      ),
                      child: Text(
                        r.tier.label,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 16,
                          color: tierColor,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: tierColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Win/loss bar
                _buildWinLossBar(r),
                const SizedBox(height: 14),
                // Stats row
                Row(
                  children: [
                    _miniStat('W', '${r.wins}', Colors.greenAccent),
                    _miniStat('L', '${r.losses}', Colors.redAccent),
                    _miniStat(
                      'WIN%',
                      '${(r.winrate * 100).toStringAsFixed(1)}%',
                      Colors.amberAccent,
                    ),
                    _miniStat('KOs', '${r.kills}', Colors.orangeAccent),
                    _miniStat(
                      'DMG',
                      _formatDmg(r.damageDealt),
                      Colors.cyanAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinLossBar(_SpeciesRecord r) {
    final winFrac = r.matches > 0 ? r.wins / r.matches : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${r.wins}W  ${r.losses}L',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 7,
                color: Colors.white38,
              ),
            ),
            Text(
              '${r.matches} BATTLES',
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
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              // Background (Loss)
              Container(
                height: 8,
                color: Colors.redAccent.withValues(alpha: 0.25),
              ),
              // Win portion
              FractionallySizedBox(
                widthFactor: winFrac.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.greenAccent, Colors.green],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 6,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Detail Sheet ─────────────────────────────────────────────────────────

  void _showDetail(BuildContext context, _SpeciesRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _DetailSheet(record: r),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmpty(bool noData) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noData ? Icons.emoji_events : Icons.search_off,
              size: 56,
              color: Colors.white12,
            ),
            const SizedBox(height: 16),
            Text(
              noData ? 'NO DATA YET' : 'NO RESULTS',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noData
                  ? 'Win Arena battles to build your archive!'
                  : 'Try a different search term.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 7,
                color: Colors.white12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDmg(int dmg) {
    if (dmg >= 1000000) return '${(dmg / 1000000).toStringAsFixed(1)}M';
    if (dmg >= 1000) return '${(dmg / 1000).toStringAsFixed(1)}k';
    return '$dmg';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail bottom sheet with chart
// ─────────────────────────────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final _SpeciesRecord record;
  const _DetailSheet({required this.record});

  String _formatDmg(int dmg) {
    if (dmg >= 1000000) return '${(dmg / 1000000).toStringAsFixed(1)}M';
    if (dmg >= 1000) return '${(dmg / 1000).toStringAsFixed(1)}k';
    return '$dmg';
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    final tierColor = r.tier.color;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF13132A).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: tierColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.species.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r.matches} battles recorded',
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 7,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tierColor, width: 1),
                      ),
                      child: Text(
                        r.tier.label,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 24,
                          color: tierColor,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: tierColor.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Win/Loss Donut ──────────────────────────────────────────
                if (r.matches > 0) ...[
                  _sectionLabel('WIN / LOSS BREAKDOWN'),
                  const SizedBox(height: 12),
                  _buildDonutChart(r, tierColor),
                  const SizedBox(height: 24),
                ],

                // ── Damage Chart ────────────────────────────────────────────
                _sectionLabel('DAMAGE ANALYSIS'),
                const SizedBox(height: 12),
                _buildDamageChart(r),
                const SizedBox(height: 24),

                // ── Stats Grid ─────────────────────────────────────────────
                _sectionLabel('FULL STATS'),
                const SizedBox(height: 12),
                _buildStatsGrid(r, tierColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(_SpeciesRecord r, Color tierColor) {
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: r.wins.toDouble().clamp(0.001, double.infinity),
                    color: Colors.greenAccent,
                    title: '',
                    radius: 28,
                  ),
                  PieChartSectionData(
                    value: r.losses.toDouble().clamp(0.001, double.infinity),
                    color: Colors.redAccent.withValues(alpha: 0.7),
                    title: '',
                    radius: 28,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(r.winrate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20,
                  color: r.winrate >= 0.5
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'WIN RATE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              _legendDot('Wins (${r.wins})', Colors.greenAccent),
              const SizedBox(height: 6),
              _legendDot('Losses (${r.losses})', Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildDamageChart(_SpeciesRecord r) {
    final maxDmg = [
      r.damageDealt,
      r.damageTaken,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxDmg.toDouble() * 1.2,
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: r.damageDealt.toDouble(),
                  color: Colors.cyanAccent,
                  width: 32,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: r.damageTaken.toDouble(),
                  color: Colors.redAccent.withValues(alpha: 0.8),
                  width: 32,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final labels = ['DEALT', 'TAKEN'];
                  final idx = v.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[idx],
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 6,
                        color: Colors.white38,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) {
                  return Text(
                    _formatDmg(v.toInt()),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 5,
                      color: Colors.white24,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(_SpeciesRecord r, Color tierColor) {
    final stats = [
      ('WINS', '${r.wins}', Colors.greenAccent),
      ('LOSSES', '${r.losses}', Colors.redAccent),
      (
        'WIN RATE',
        '${(r.winrate * 100).toStringAsFixed(1)}%',
        Colors.amberAccent,
      ),
      ('TOTAL KOs', '${r.kills}', Colors.orangeAccent),
      ('DMG DEALT', _formatDmg(r.damageDealt), Colors.cyanAccent),
      ('DMG TAKEN', _formatDmg(r.damageTaken), Colors.purpleAccent),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s = stats[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: s.$3.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: s.$3.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                s.$1,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 5.5,
                  color: Colors.white38,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                s.$2,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: s.$3,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
