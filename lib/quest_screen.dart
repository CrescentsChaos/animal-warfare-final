// lib/quest_screen.dart

import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'package:animal_warfare/widgets/animal_summary_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  List<Organism> _allOrganisms = [];
  bool _isLoadingOrganisms = true;
  String _currentDialogue = "";

  // Dialogue pools for Jeremy Wade
  final List<String> _greetings = [
    "The water holds secrets most people never see. To find a monster, you have to think like one.",
    "Listen carefully... the ripples in the dark water tell a story. A story of things that should not exist.",
    "I've traveled the world's most dangerous rivers, but these waters... they have a different kind of hunger.",
    "You look like you've got the stomach for this. Most turn back at the first sign of a silhouette beneath the surface.",
  ];

  final List<String> _questFullQuotes = [
    "You're already tracking two legends. Stay focused. One monster at a time.",
    "Your log is full. Finish what you started before we go chasing more shadows.",
    "Too many lines in the water will only lead to a tangle. Clear your active hunts first.",
  ];

  final List<String> _questAcceptedQuotes = [
    "Good. The hunt is on. Don't let it out of your sight.",
    "Keep your eyes on the horizon. These creatures won't wait for you to be ready.",
    "A bold choice. That monster has been terrorizing these docks for weeks.",
  ];

  final Map<String, List<String>> _habitatQuestTemplates = {
    'Ocean': [
      "The deep blue is hiding something massive. A group of {target} has been seen patrolling the outer reefs. Take out {count} of them.",
      "The local fishermen are terrified of a 'shadow from the abyss'. It's just {count} {target} getting too close to the surface. Deal with them.",
      "A rogue current has brought a frenzy of {target} to the bay. Clear out {count} before they disrupt the local trade.",
    ],
    'River': [
      "The rapids are churned up by something fierce. Reports say {count} {target} are blocking the upstream migration. Clear the path.",
      "A massive {target} was seen near the old stone bridge. I need you to thin the pack. Bag {count} of them.",
      "The murky depths of the river are home to ancient predators. {count} {target} have been targeting local livestock. Stop them.",
    ],
    'Swamp': [
      "The mist-covered marshes are hiding a silent killer. {count} {target} are lurking in the stagnant pools. Find and cull them.",
      "The mangrove roots are thick with {target}. They're outcompeting everything else in the swamp. Remove {count} of them.",
      "The locals speak of spirits in the swamp, but it's just the glowing eyes of {target}. Go and clear out {count}.",
    ],
    'Lake': [
      "The tranquil surface of the lake belies the danger below. {count} {target} have taken over the northern reeds. Deal with them.",
      "A massive {target} has been seen near the town pier. It's only a matter of time before someone gets hurt. Thin the pack by {count}.",
      "The dark depths of the lake are home to a legend. To understand it, I need data from {count} {target} specimens.",
    ],
  };

  final List<String> _generalQuestTemplates = [
    "Reports of a 'demon fish' have been coming in from the local village. We need to clear out {count} {target} to restore order.",
    "The ecosystem is out of balance. Too many {target} are depleting the smaller fry. Cull {count} of them.",
    "I'm tracking a migratory pattern. To understand it, I need data from {count} {target} specimens.",
    "The water is turning red near the estuary. The {target} are in a feeding frenzy. Go and stop {count} of them.",
  ];

  @override
  void initState() {
    super.initState();
    _loadOrganisms();
    _currentDialogue = _greetings[Random().nextInt(_greetings.length)];
  }

  Future<void> _loadOrganisms() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      final List<dynamic> data = json.decode(response);
      setState(() {
        _allOrganisms = data.map((json) => Organism.fromJson(json)).toList();
        _isLoadingOrganisms = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingOrganisms = false);
    }
  }

  void _updateDialogue(String message) {
    setState(() {
      _currentDialogue = message;
    });
  }

  void _generateNewQuest() {
    final userState = Provider.of<UserState>(context, listen: false);

    // Check limit
    final activeQuests =
        userState.currentUser?.activeQuests
            .where((q) => q.npcId == 'jeremy_wade')
            .toList() ??
        [];

    if (activeQuests.length >= 2) {
      _updateDialogue(
        _questFullQuotes[Random().nextInt(_questFullQuotes.length)],
      );
      return;
    }

    if (_isLoadingOrganisms || _allOrganisms.isEmpty) return;

    final random = Random();

    // Refined Fish Detection based on drops
    final fishDrops = [
      'fillet',
      'shark fin',
      'fish scales',
      'stingray tail',
      'roe',
      'fish bone',
      'caviar',
    ];
    final fishOptions = _allOrganisms.where((o) {
      final drops = o.drops.toLowerCase();
      return fishDrops.any((drop) => drops.contains(drop));
    }).toList();

    // Fallback if no specific drops found (shouldn't happen with large DB)
    final options = fishOptions.isNotEmpty ? fishOptions : _allOrganisms;

    final targetOrg = options[random.nextInt(options.length)];
    final target = targetOrg.name;
    final count = random.nextInt(2) + 1; // 1 to 3
    final baseReward = count * 100;
    final rarityBonus =
        (targetOrg.rarity.toLowerCase() == 'uncommon' ? 50 : 0) +
        (targetOrg.rarity.toLowerCase() == 'rare' ? 100 : 0) +
        (targetOrg.rarity.toLowerCase() == 'epic' ? 200 : 0) +
        (targetOrg.rarity.toLowerCase() == 'legendary' ? 300 : 0);
    final reward = baseReward + rarityBonus + random.nextInt(50);

    final templatePool = _habitatQuestTemplates.entries
        .firstWhere(
          (e) => targetOrg.habitat.contains(e.key),
          orElse: () => MapEntry('General', _generalQuestTemplates),
        )
        .value;

    final template = templatePool[random.nextInt(templatePool.length)];
    final flavoredDescription = template
        .replaceAll('{count}', count.toString())
        .replaceAll('{target}', target);

    final newQuest = Quest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: flavoredDescription,
      targetOrganismName: target,
      targetCount: count,
      rewardMoney: reward,
      npcId: 'jeremy_wade',
      category: 'River Monsters',
    );

    userState.acceptQuest(newQuest);
    _updateDialogue(
      _questAcceptedQuotes[random.nextInt(_questAcceptedQuotes.length)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();

    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'QUEST LOG',
            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14),
          ),
          backgroundColor: AppColors.secondaryButtonColor,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.highlightColor,
            labelStyle: TextStyle(fontFamily: 'PressStart2P', fontSize: 9),
            tabs: [Tab(text: 'River Monsters')],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(color: Color(0xFF1a1a2e)),
          child: TabBarView(children: [_buildRiverMonstersTab(userState)]),
        ),
      ),
    );
  }

  Widget _buildRiverMonstersTab(UserState userState) {
    final activeQuests =
        userState.currentUser?.activeQuests
            .where((q) => q.npcId == 'jeremy_wade')
            .toList() ??
        [];

    return Column(
      children: [
        const SizedBox(height: 10),
        // NPC Header Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Speech Bubble
              SpeechBubble(
                title: 'Jeremy Wade',
                message: _currentDialogue,
                key: ValueKey(_currentDialogue), // Force rebuild for typewriter
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
                child: Text(
                  'Jeremy Wade NPC',
                  style: TextStyle(color: Colors.white54),
                ),
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
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
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
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blueAccent,
                            size: 30,
                          ),
                          onPressed: _generateNewQuest,
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.lock,
                            color: Colors.white24,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: activeQuests.isEmpty
                      ? const Center(
                          child: Text(
                            'Click the + to start a new hunt!',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
      onLongPress: () =>
          _showOrganismDetails(context, quest.targetOrganismName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondaryButtonColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.highlightColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
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
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              quest.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.3,
              ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    userState.claimQuestReward(quest.id);
                    _updateDialogue(
                      "Excellent work. That's one less monster to worry about.",
                    );
                  },
                  child: const Text(
                    'CLAIM REWARD',
                    style: TextStyle(fontFamily: 'PressStart2P', fontSize: 8),
                  ),
                ),
              ),
            ] else if (quest.category == 'River Monsters') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () =>
                      _showSubmissionDialog(context, quest, userState),
                  child: const Text(
                    'SUBMIT ANIMAL',
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

  void _showSubmissionDialog(
    BuildContext context,
    Quest quest,
    UserState userState,
  ) {
    final targetSpecies = quest.targetOrganismName;
    final userOrganisms =
        userState.currentUser?.capturedOrganisms
            .where((o) => o.baseOrganism.name == targetSpecies)
            .toList() ??
        [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.secondaryButtonColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Colors.blueAccent, width: 2),
              ),
              title: Text(
                'SUBMIT $targetSpecies',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select an animal to give to Jeremy. \n(This will release the animal!)',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (userOrganisms.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'You have no animals of this species.',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: userOrganisms.length,
                          itemBuilder: (context, index) {
                            final org = userOrganisms[index];
                            return Card(
                              color: Colors.black26,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: _OrganismSpriteDisplay(
                                  organism: org.baseOrganism,
                                  isDiscovered: true,
                                  silhouetteColor: Colors.black,
                                  height: 40,
                                  width: 40,
                                ),
                                title: Text(
                                  org.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  'Lv.${org.level}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: Colors.cyan,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AnimalSummaryScreen(captured: org),
                                      ),
                                    );
                                  },
                                ),
                                onTap: () {
                                  _confirmSubmission(
                                    context,
                                    quest,
                                    org,
                                    userState,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmSubmission(
    BuildContext context,
    Quest quest,
    CapturedOrganism org,
    UserState userState,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'ARE YOU SURE?',
          style: TextStyle(
            color: Colors.redAccent,
            fontFamily: 'PressStart2P',
            fontSize: 10,
          ),
        ),
        content: Text(
          'Submit ${org.name} to Jeremy?\nYou will lose this animal forever.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              // Close both dialogs
              Navigator.pop(context); // Close confirm
              Navigator.pop(context); // Close selection list

              userState.submitQuestAnimal(quest.id, org);
              _updateDialogue(
                "A fine specimen. I'll make sure it's handled with care.",
              );
            },
            child: const Text(
              'YES, SUBMIT',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrganismDetails(BuildContext context, String name) {
    if (_isLoadingOrganisms) return;

    final userState = Provider.of<UserState>(context, listen: false);
    final isDiscovered =
        userState.currentUser?.discoveredOrganisms.contains(name) ?? false;

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
        power: 0,
        resistance: 0,
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
          isDiscovered ? organism.name.toUpperCase() : "UNDISCOVERED MONSTER",
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: AppColors.highlightColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _OrganismSpriteDisplay(
                  organism: organism,
                  isDiscovered: isDiscovered,
                  silhouetteColor: Colors.black,
                  height: 100,
                  width: 100,
                ),
              ),
            ),
            _buildDetailInfo(
              'Scientific',
              isDiscovered ? organism.scientificName : "???",
            ),
            const SizedBox(height: 8),
            const Text(
              'Habitat:',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: organism.habitat
                  .split(',')
                  .map(
                    (h) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        h.trim().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _buildDetailInfo('Rarity', isDiscovered ? organism.rarity : "???"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                isDiscovered
                    ? organism.description
                    : "You haven't encountered this monster in battle yet. Identify it to unlock more data.",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
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
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
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

class _OrganismSpriteDisplay extends StatefulWidget {
  final Organism organism;
  final bool isDiscovered;
  final Color silhouetteColor;
  final double height;
  final double width;

  const _OrganismSpriteDisplay({
    required this.organism,
    required this.isDiscovered,
    required this.silhouetteColor,
    this.height = 200,
    this.width = 400,
  });

  @override
  __OrganismSpriteDisplayState createState() => __OrganismSpriteDisplayState();
}

class __OrganismSpriteDisplayState extends State<_OrganismSpriteDisplay> {
  String? _imageSourceType;
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
  }

  String _getLocalPath() {
    final fileName = widget.organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll("-", '_');
    return 'assets/sprites/$fileName.png';
  }

  Future<void> _determineImageSource() async {
    final localPath = _getLocalPath();
    try {
      await rootBundle.load(localPath);
      if (mounted) {
        setState(() {
          _imageSourceType = 'local';
          _imagePath = localPath;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String spriteUrl = widget.organism.sprite;
          _imageSourceType = 'network';

          // 🚨 FIX: Remove 'file:///' prefix if present
          if (spriteUrl.startsWith('file:///')) {
            spriteUrl = spriteUrl.replaceFirst('file:///', '');
            if (spriteUrl.startsWith('assets/')) {
              _imageSourceType = 'local';
            }
          }
          _imagePath = spriteUrl;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSourceType == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.highlightColor),
        ),
      );
    }

    if (widget.isDiscovered) {
      if (_imageSourceType == 'local') {
        return Image.asset(
          _imagePath,
          height: widget.height,
          width: widget.width,
          fit: BoxFit.contain,
        );
      } else {
        return Image.network(
          _imagePath,
          height: widget.height,
          width: widget.width,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              height: widget.height,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.highlightColor,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.red, size: 40),
        );
      }
    } else {
      return buildSilhouetteSprite(
        imageUrl: _imagePath,
        silhouetteColor: widget.silhouetteColor,
        outlineColor: Colors.white,
        outlineWidth: 1.5,
        organismName: widget.organism.name,
        height: widget.height,
        width: widget.width,
        fit: BoxFit.contain,
      );
    }
  }
}

class SpeechBubble extends StatefulWidget {
  final String title;
  final String message;

  const SpeechBubble({super.key, required this.title, required this.message});

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> {
  String _displayText = "";
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  @override
  void didUpdateWidget(SpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _startTypewriter();
    }
  }

  void _startTypewriter() {
    _timer?.cancel();
    _displayText = "";
    _currentIndex = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_currentIndex < widget.message.length) {
        setState(() {
          _displayText += widget.message[_currentIndex];
          _currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'PressStart2P',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _displayText,
            textAlign: TextAlign.center,
            style: GoogleFonts.robotoMono(
              color: Colors.black,
              fontSize: 11.sp,
              height: 1.4,
              fontWeight: FontWeight.w500,
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
