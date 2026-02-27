import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/theme.dart';

class RankedScreen extends StatefulWidget {
  const RankedScreen({super.key});

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends State<RankedScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ({String label, Color color, int order}) _getRankTier(
    double winrate,
    int matches,
  ) {
    if (matches < 3) return (label: '?', color: Colors.grey, order: 99);
    if (winrate >= 0.70 && matches >= 5)
      return (label: 'S', color: const Color(0xFFFF4E4E), order: 0);
    if (winrate >= 0.55)
      return (label: 'A', color: Colors.orangeAccent, order: 1);
    if (winrate >= 0.45)
      return (label: 'B', color: Colors.yellowAccent, order: 2);
    if (winrate >= 0.30)
      return (label: 'C', color: Colors.cyanAccent, order: 3);
    return (label: 'D', color: Colors.blueGrey, order: 4);
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final user = userState.currentUser;

    return Scaffold(
      backgroundColor: AppColors.secondaryButtonColor,
      appBar: AppBar(
        title: const Text(
          'ANIMAL RANKINGS',
          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14),
        ),
        backgroundColor: AppColors.primaryButtonColor,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : Column(
              children: [
                _buildSearchField(),
                Expanded(child: _buildRankedList(user)),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryButtonColor.withOpacity(0.5),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'PressStart2P',
          fontSize: 10,
        ),
        decoration: InputDecoration(
          hintText: 'SEARCH SPECIES...',
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
          prefixIcon: const Icon(Icons.search, color: AppColors.highlightColor),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.highlightColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppColors.highlightColor.withOpacity(0.3),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRankedList(UserData user) {
    final stats = user.speciesStats;

    if (stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text(
                'NO DATA YET',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Participate in battles to see rankings!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build list of records
    var entries = stats.entries.map((e) {
      final matches = e.value['matches'] ?? 0;
      final wins = e.value['wins'] ?? 0;
      final winrate = matches > 0 ? wins / matches : 0.0;
      final tier = _getRankTier(winrate, matches);
      return (
        species: e.key,
        matches: matches,
        wins: wins,
        winrate: winrate,
        tier: tier,
      );
    }).toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      entries = entries
          .where(
            (e) => e.species.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Sort: tier order asc → winrate desc → matches desc
    entries.sort((a, b) {
      final tierCmp = a.tier.order.compareTo(b.tier.order);
      if (tierCmp != 0) return tierCmp;
      final wCmp = b.winrate.compareTo(a.winrate);
      if (wCmp != 0) return wCmp;
      return b.matches.compareTo(a.matches);
    });

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'NO SPECIES FOUND',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: Colors.white24,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final pct = (e.winrate * 100).toStringAsFixed(1);
        final tier = e.tier;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tier.color.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: tier.color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#${i + 1}',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: tier.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            title: Text(
              e.species.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _statItem('WINS', '${e.wins}', Colors.greenAccent),
                  const SizedBox(width: 12),
                  _statItem('MATCHES', '${e.matches}', Colors.white70),
                  const SizedBox(width: 12),
                  _statItem('RATE', '$pct%', Colors.amberAccent),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tier.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tier.color, width: 1),
              ),
              child: Text(
                tier.label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 18,
                  color: tier.color,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: tier.color.withOpacity(0.5), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 6,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: color,
          ),
        ),
      ],
    );
  }
}
