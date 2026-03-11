// lib/replay_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/battle_replay.dart';
import 'package:animal_warfare/replay_viewer_screen.dart';
import 'package:animal_warfare/theme.dart';

class ReplayListScreen extends StatelessWidget {
  const ReplayListScreen({super.key});

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final replays =
        userState.currentUser?.savedReplays
            .map((json) => BattleReplay.fromJson(json))
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BATTLE REPLAYS'),
        backgroundColor: AppColors.surface,
      ),
      body: replays.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: replays.length,
              itemBuilder: (context, index) {
                final replay = replays[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildReplayCard(context, userState, replay),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            'NO REPLAYS YET',
            style: GoogleFonts.pressStart2p(
              fontSize: 12,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save battles from the results screen!',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplayCard(
    BuildContext context,
    UserState userState,
    BattleReplay replay,
  ) {
    final isWin = replay.result == 'win' || replay.result == 'capture';
    final accentColor = isWin ? Colors.greenAccent : Colors.redAccent;

    return Dismissible(
      key: Key(replay.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => userState.deleteReplay(replay.id),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReplayViewerScreen(replay: replay),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          replay.result.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(replay.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTeamSummary(replay.playerTeamNames, true),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'VS',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 8,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                      _buildTeamSummary(replay.opponentTeamNames, false),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  Row(
                    children: [
                      Icon(
                        Icons.query_builder_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${replay.turnCount} TURNS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (replay.biome != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.terrain_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          replay.biome!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSummary(List<String> names, bool isPlayer) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isPlayer
            ? CrossHorizontally.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            names.first,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (names.length > 1)
            Text(
              '+${names.length - 1} OTHERS',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class CrossHorizontally {
  static const start = CrossAxisAlignment.start;
}
