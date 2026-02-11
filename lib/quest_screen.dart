// lib/quest_screen.dart

import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/theme.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  List<Organism> _allOrganisms = [];
  bool _isLoadingOrganisms = true;

  final List<String> _fishTargets = [
    'Alligator Gar',
    'Arapaima',
    'Nile Perch',
    'Giant Snakehead',
    'Atlantic Bluefin Tuna',
    'Giant Grouper',
    'Atlantic Goliath Grouper',
    'Giant Oarfish',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrganisms();
  }

  Future<void> _loadOrganisms() async {
    try {
      final String response = await rootBundle.loadString('assets/Organisms.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _allOrganisms = data.map((json) => Organism.fromJson(json)).toList();
        _isLoadingOrganisms = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingOrganisms = false);
    }
  }

  void _generateNewQuest() {
    final userState = Provider.of<UserState>(context, listen: false);
    final random = Random();
    final target = _fishTargets[random.nextInt(_fishTargets.length)];
    final count = random.nextInt(5) + 3; // 3 to 7
    final reward = count * 50 + random.nextInt(100); // 150 to 450 approx

    final newQuest = Quest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: 'Hunt down $count $target to help Jeremy Wade!',
      targetOrganismName: target,
      targetCount: count,
      rewardMoney: reward,
      npcId: 'jeremy_wade',
      category: 'River Monsters',
    );

    userState.acceptQuest(newQuest);
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QUEST LOG', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14)),
          backgroundColor: AppColors.secondaryButtonColor,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.highlightColor,
            labelStyle: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
            tabs: [
              Tab(text: 'River Monsters'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
          ),
          child: TabBarView(
            children: [
              _buildRiverMonstersTab(userState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiverMonstersTab(UserState userState) {
    final activeQuests = userState.currentUser?.activeQuests
            .where((q) => q.npcId == 'jeremy_wade')
            .toList() ?? [];

    return Column(
      children: [
        const SizedBox(height: 10),
        // NPC Header Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Column(
            children: [
              // Speech Bubble
              SpeechBubble(
                title: 'Jeremy Wade',
                message: "The water holds secrets most people never see. To find a monster, you have to think like one. Are you ready for another hunt?",
              ),
            ],
          ),
        ),
        
        // Jeremy Wade Image - Enlarged
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: Image.asset(
              'assets/npc/jeremy-wade.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text('Jeremy Wade NPC', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ),
        ),

        // Quest List Area
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVE HUNTS (${activeQuests.length}/2)',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          color: Colors.amber,
                        ),
                      ),
                      if (activeQuests.length < 2)
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 30),
                          onPressed: _generateNewQuest,
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.lock, color: Colors.white24, size: 24),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: activeQuests.isEmpty
                    ? const Center(
                        child: Text(
                          'Click the + to start a new hunt!',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: activeQuests.length,
                        itemBuilder: (context, index) {
                          final quest = activeQuests[index];
                          return _buildQuestCard(quest, userState);
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).safeArea();
  }

  Widget _buildQuestCard(Quest quest, UserState userState) {
    final progress = quest.currentCount / quest.targetCount;
    return GestureDetector(
      onLongPress: () => _showOrganismDetails(quest.targetOrganismName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondaryButtonColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.highlightColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(2, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quest.targetOrganismName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: Colors.cyan,
                  ),
                ),
                Text(
                  '\$${quest.rewardMoney}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              quest.description,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: ${quest.currentCount}/${quest.targetCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (quest.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: quest.isCompleted ? Colors.green : Colors.blue,
            ),
            if (quest.isCompleted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => userState.claimQuestReward(quest.id),
                  child: const Text(
                    'CLAIM REWARD',
                    style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOrganismDetails(String name) {
    if (_isLoadingOrganisms) return;
    
    final organism = _allOrganisms.firstWhere(
      (o) => o.name.toLowerCase() == name.toLowerCase(),
      orElse: () => Organism(
        name: name,
        scientificName: 'Unknown',
        description: 'No data available.',
        rarity: 'Common',
        health: 0,
        attack: 0,
        defense: 0,
        speed: 0,
        abilities: 'Unknown',
        moves: 'Unknown',
        drops: 'Unknown',
        category: 'Unknown',
        habitat: 'Unknown',
        sprite: '',
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryButtonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: AppColors.highlightColor, width: 2),
        ),
        title: Text(
          organism.name.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: AppColors.highlightColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailInfo('Scientific', organism.scientificName),
            _buildDetailInfo('Habitat', organism.habitat),
            _buildDetailInfo('Category', organism.category),
            _buildDetailInfo('Rarity', organism.rarity),
            const SizedBox(height: 10),
            Text(
              organism.description,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class SpeechBubble extends StatelessWidget {
  final String title;
  final String message;

  const SpeechBubble({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 3),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

extension SafeWidget on Widget {
  Widget safeArea() => SafeArea(child: this);
}
