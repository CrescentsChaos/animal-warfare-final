// lib/replay_viewer_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/models/battle_replay.dart';
import 'package:animal_warfare/theme.dart';
import 'dart:ui';

class ReplayViewerScreen extends StatefulWidget {
  final BattleReplay replay;

  const ReplayViewerScreen({super.key, required this.replay});

  @override
  State<ReplayViewerScreen> createState() => _ReplayViewerScreenState();
}

class _ReplayViewerScreenState extends State<ReplayViewerScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _isPlaying = true;
  double _playbackSpeed = 1.0;
  int _turnIndex = 0;
  int _entryIndex = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPlayback() {
    _timer?.cancel();
    if (_isFinished) return;

    _timer = Timer.periodic(
      Duration(milliseconds: (800 ~/ _playbackSpeed).toInt()),
      (timer) {
        if (!_isPlaying) return;
        _nextStep();
      },
    );
  }

  void _nextStep() {
    if (_turnIndex >= widget.replay.turns.length) {
      setState(() {
        _isFinished = true;
        _isPlaying = false;
      });
      _timer?.cancel();
      return;
    }

    final currentTurn = widget.replay.turns[_turnIndex];
    if (_entryIndex < currentTurn.entries.length) {
      setState(() {
        _logs.add(currentTurn.entries[_entryIndex]);
      });
      _entryIndex++;
      _scrollToBottom();
    } else {
      // Move to next turn
      _turnIndex++;
      _entryIndex = 0;
      if (_turnIndex < widget.replay.turns.length) {
        setState(() {
          _logs.add('--- TURN ${_turnIndex + 1} ---');
        });
        _scrollToBottom();
      } else {
        setState(() {
          _isFinished = true;
          _isPlaying = false;
        });
        _timer?.cancel();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _changeSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 2.0;
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 4.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    _startPlayback();
  }

  void _skipToEnd() {
    setState(() {
      _logs.clear();
      for (var turn in widget.replay.turns) {
        _logs.add('--- TURN ${turn.turnNumber} ---');
        _logs.addAll(turn.entries);
      }
      _turnIndex = widget.replay.turns.length;
      _entryIndex = 0;
      _isFinished = true;
      _isPlaying = false;
    });
    _timer?.cancel();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  const Color(0xFF1A1F2B),
                  AppColors.background,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildLogList()),
                _buildControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BATTLE REPLAY',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 12,
                    color: AppColors.highlight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.replay.playerTeamNames.first} vs ${widget.replay.opponentTeamNames.first}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.replay.biome != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                widget.replay.biome!.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final isHeader = log.startsWith('---');

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: isHeader
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      log,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                )
              : Text(
                  log,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlIcon(
                icon: _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: _isFinished ? null : _togglePlay,
                color: _isPlaying ? AppColors.primary : AppColors.highlight,
              ),
              _buildControlIcon(
                icon: Icons.fast_forward_rounded,
                onTap: _isFinished ? null : _changeSpeed,
                label: '${_playbackSpeed.toInt()}X',
              ),
              _buildControlIcon(
                icon: Icons.skip_next_rounded,
                onTap: _isFinished ? null : _skipToEnd,
                label: 'END',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlIcon({
    required IconData icon,
    required VoidCallback? onTap,
    String? label,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: onTap == null ? Colors.white24 : color),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: onTap == null ? Colors.white24 : Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
