import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';

class MoveManageScreen extends StatefulWidget {
  final int organismIndex;

  const MoveManageScreen({super.key, required this.organismIndex});

  @override
  State<MoveManageScreen> createState() => _MoveManageScreenState();
}

class _MoveManageScreenState extends State<MoveManageScreen> {
  late List<String> _availableMoves;
  late List<String> _selectedMoves;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userState = Provider.of<UserState>(context, listen: false);
    final rogueState = userState.currentUser?.rogueLikeState;
    if (rogueState != null &&
        widget.organismIndex >= 0 &&
        widget.organismIndex < rogueState.team.length) {
      final org = rogueState.team[widget.organismIndex];
      _availableMoves = org.baseOrganism.moves
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(); // Dedupe and list

      _selectedMoves = List.from(org.selectedMoveNames);
    } else {
      _availableMoves = [];
      _selectedMoves = [];
      Future.microtask(() => Navigator.pop(context));
    }
  }

  void _toggleMove(String moveName) {
    setState(() {
      if (_selectedMoves.contains(moveName)) {
        if (_selectedMoves.length > 1) {
          _selectedMoves.remove(moveName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Must have at least one move!')),
          );
        }
      } else {
        if (_selectedMoves.length < 4) {
          _selectedMoves.add(moveName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot learn more than 4 moves!')),
          );
        }
      }
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    final userState = Provider.of<UserState>(context, listen: false);

    // We need a specific method to update rogue team specifically,
    // OR generalized usage.
    // UserState has updateCapturedOrganismMoves but that targets `capturedOrganisms` (the collection).
    // Rogue team is separate in `rogueLikeState.team`.
    // I need to update the rogue team member.

    // I'll check if I need to add a method to UserState for this.
    // Yes, updateCapturedOrganismMoves uses `u.capturedOrganisms`.
    // I need `updateRogueTeamMemberMoves`.
    // For now, I can manually update the team list and call `updateRogueTeam`.

    final rogueState = userState.currentUser!.rogueLikeState;
    final team = List<CapturedOrganism>.from(rogueState.team);
    final org = team[widget.organismIndex];

    // Update moves and refresh stamina map
    final newStamina = Map<String, int>.from(org.moveStamina);
    // Remove unused
    newStamina.removeWhere((key, _) => !_selectedMoves.contains(key));
    // Add new
    for (final m in _selectedMoves) {
      if (!newStamina.containsKey(m)) {
        final moveData = Move.findByName(m);
        newStamina[m] = moveData?.stamina ?? 20;
      }
    }

    final updatedOrg = org.copyWith(
      selectedMoveNames: _selectedMoves,
      moveStamina: newStamina,
    );

    team[widget.organismIndex] = updatedOrg;
    await userState.updateRogueTeam(team);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'MANAGE MOVES',
          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveChanges,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _availableMoves.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white24),
        itemBuilder: (context, index) {
          final moveName = _availableMoves[index];
          final move = Move.findByName(moveName);
          final isSelected = _selectedMoves.contains(moveName);
          final color = move?.category.color ?? Colors.grey;

          return ListTile(
            onTap: () => _toggleMove(moveName),
            leading: Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? Colors.green : Colors.grey,
            ),
            title: Text(
              moveName,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 12,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        move?.category.name.toUpperCase() ?? '???',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PWR: ${move?.baseDamage ?? '-'} | ACC: ${move?.accuracy ?? '-'}',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        color: Colors.white70,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
                if (move?.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    move!.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
