import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/game/move_animations.dart' as anims;
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/widgets/battle_sprite.dart';

class TrainingBattleScreen extends StatefulWidget {
  final List<CapturedOrganism> playerTeam;

  const TrainingBattleScreen({super.key, required this.playerTeam});

  @override
  State<TrainingBattleScreen> createState() => _TrainingBattleScreenState();
}

class _TrainingBattleScreenState extends State<TrainingBattleScreen>
    with TickerProviderStateMixin {
  late BattleManager _battleManager;
  final TextEditingController _searchController = TextEditingController();
  List<Move> _filteredMoves = [];
  String _searchQuery = '';

  // Animation controllers copied from BattleScreen
  late AnimationController _playerShakeController;
  late AnimationController _opponentShakeController;
  late Animation<double> _playerShakeAnimation;
  late Animation<double> _opponentShakeAnimation;

  final LayerLink _playerLink = LayerLink();
  final LayerLink _opponentLink = LayerLink();

  final List<anims.MoveAnimData> _moveAnims = [];
  int _moveAnimIdCounter = 0;

  final List<_IndicatorData> _indicators = [];
  final GlobalKey<BattleSpriteState> _playerSpriteKey =
      GlobalKey<BattleSpriteState>();
  final GlobalKey<BattleSpriteState> _opponentSpriteKey =
      GlobalKey<BattleSpriteState>();

  // Biome for background
  final String _biomeName = _getRandomBiome();

  static String _getRandomBiome() {
    final biomes = [
      'Volcano',
      'Cave',
      'Coastal',
      'Coral Reef',
      'Deep Sea',
      'Frozen Ocean',
      'Kelp Forest',
      'Swamp',
      'Lake',
      'Mangrove',
      'Polar',
      'Rainforest',
      'Taiga',
      'Tundra',
      'Urban',
      'Jungle',
      'Desert',
      'Savanna',
      'River',
      'Ocean',
      'Mountain',
      'Redwoods',
      'Wetlands',
      'Plains',
    ];
    return biomes[Random().nextInt(biomes.length)];
  }

  @override
  void initState() {
    super.initState();
    _filteredMoves = Move.allMoves;

    _playerShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opponentShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final shakeTween = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]);

    _playerShakeAnimation = shakeTween.animate(_playerShakeController);
    _opponentShakeAnimation = shakeTween.animate(_opponentShakeController);

    // Initialize BattleManager for training
    final dummy = CapturedOrganism.spawn(Organism.trainingDummy, level: 100);

    // FALLBACK: If player has no animals (e.g. fresh account), use a dummy for the player too
    // to prevent "Bad state: No element" on widget.playerTeam.first
    final playerAnimal = widget.playerTeam.isNotEmpty
        ? widget.playerTeam.first
        : CapturedOrganism.spawn(Organism.trainingDummy, level: 100);
    final effectiveTeam = widget.playerTeam.isNotEmpty
        ? widget.playerTeam
        : [playerAnimal];

    _battleManager = BattleManager(
      playerAnimal,
      dummy,
      team: effectiveTeam,
      opponentTeam: [dummy],
      isTraining: true,
    );

    _battleManager.onAttack = _onAttack;
    _battleManager.onDamage = _onDamage;
    _battleManager.onHeal = _onHeal;
    _battleManager.onStatChange = _onStatChange;

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filteredMoves = Move.allMoves.where((m) {
          return m.name.toLowerCase().contains(_searchQuery) ||
              m.description.toLowerCase().contains(_searchQuery) ||
              m.type.name.toLowerCase().contains(_searchQuery);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _playerShakeController.dispose();
    _opponentShakeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onAttack(BattleOrganism attacker, Move move) {
    if (!mounted) return;
    final isPlayerAttacking = attacker == _battleManager.player;

    if (isPlayerAttacking) {
      _playerShakeController.forward(from: 0);
    } else {
      _opponentShakeController.forward(from: 0);
    }

    final id = ++_moveAnimIdCounter;
    setState(() {
      _moveAnims.add(
        anims.MoveAnimData(
          id: id,
          move: move,
          isPlayerAttacking: isPlayerAttacking,
        ),
      );
    });

    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        setState(() => _moveAnims.removeWhere((a) => a.id == id));
      }
    });
  }

  void _onDamage(BattleOrganism target, int amount) {
    if (!mounted) return;
    _addIndicator("-$amount", Colors.redAccent, target.isPlayer);
  }

  void _onHeal(BattleOrganism target, int amount) {
    if (!mounted) return;
    _addIndicator("+$amount", Colors.greenAccent, target.isPlayer);
  }

  void _onStatChange(BattleOrganism target, String stat, int value) {
    if (!mounted) return;
    final statLabel = stat.toString();
    final direction = value > 0 ? "↑" : "↓";
    final color = value > 0 ? Colors.cyanAccent : Colors.orangeAccent;
    _addIndicator(
      "${statLabel.toUpperCase()} $direction",
      color,
      target.isPlayer,
    );
  }

  void _addIndicator(String text, Color color, bool isPlayer) {
    final id = DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000);
    setState(() {
      _indicators.add(
        _IndicatorData(id: id, text: text, color: color, isPlayer: isPlayer),
      );
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _indicators.removeWhere((i) => i.id == id));
    });
  }

  Color _getBiomeThemeColor() {
    final name = _biomeName.toLowerCase();
    if (name.contains('forest') ||
        name.contains('jungle') ||
        name.contains('rainforest')) {
      return const Color(0xFF2E7D32);
    }
    if (name.contains('desert') ||
        name.contains('savanna') ||
        name.contains('plains')) {
      return const Color(0xFFF9A825);
    }
    if (name.contains('ocean') ||
        name.contains('sea') ||
        name.contains('river') ||
        name.contains('lake') ||
        name.contains('coastal')) {
      return const Color(0xFF1565C0);
    }
    if (name.contains('polar') ||
        name.contains('frozen') ||
        name.contains('tundra')) {
      return const Color(0xFF0288D1);
    }
    if (name.contains('volcano')) {
      return const Color(0xFFC62828);
    }
    if (name.contains('cave')) {
      return const Color(0xFF424242);
    }
    return Colors.blueGrey;
  }

  Color _getBiomePrimaryColor() {
    return _getBiomeThemeColor().withValues(alpha: 0.8);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _battleManager,
      child: Consumer<BattleManager>(
        builder: (context, bm, child) {
          return OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;
              final isNarrow = MediaQuery.sizeOf(context).width < 600;
              final overlayColor = _getBiomePrimaryColor();

              return Scaffold(
                backgroundColor: Colors.black,
                body: Stack(
                  children: [
                    _buildBackground(context),
                    Positioned.fill(
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            Expanded(
                              child: isLandscape
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: _buildField(
                                            context,
                                            bm,
                                            isNarrow,
                                            overlayColor,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: _buildControlPanel(bm),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Flexible(
                                          fit: FlexFit.loose,
                                          child: SingleChildScrollView(
                                            child: _buildField(
                                              context,
                                              bm,
                                              isNarrow,
                                              overlayColor,
                                            ),
                                          ),
                                        ),
                                        const Divider(
                                          height: 1,
                                          color: Colors.white24,
                                        ),
                                        Expanded(child: _buildControlPanel(bm)),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Animations Overlay Layer
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Stack(
                          children: [
                            ..._moveAnims.map(
                              (anim) => anims.MoveAnimationOverlay(
                                key: ValueKey(anim.id),
                                data: anim,
                                player1Link: _playerLink,
                                player2Link: LayerLink(),
                                opponent1Link: _opponentLink,
                                opponent2Link: LayerLink(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Indicators — must be Positioned.fill so CompositedTransformFollower
                    // never gives the outer Stack an unconstrained size.
                    ..._indicators.map(
                      (indicator) => Positioned.fill(
                        child: _FloatingIndicatorWidget(
                          key: ValueKey(indicator.id),
                          data: indicator,
                          link: indicator.isPlayer
                              ? _playerLink
                              : _opponentLink,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    final fileName = _biomeName.toLowerCase().replaceAll(' ', '_');
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getBiomeThemeColor().withValues(alpha: 0.3),
              Colors.black,
            ],
          ),
        ),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.darken,
          ),
          child: Image.asset(
            'assets/biomes/$fileName-bg.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/biomes/$fileName.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TRAINING MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TEST ANY MOVE VS DUMMY',
                    style: TextStyle(
                      color: Colors.white38,
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

  Widget _buildField(
    BuildContext context,
    BattleManager bm,
    bool isNarrow,
    Color overlayColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _opponentShakeAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(_opponentShakeAnimation.value, 0),
            child: child,
          ),
          child: _buildOpponentStatus(
            context,
            bm.opponent,
            overlayColor,
            isNarrow,
            bm,
            spriteKey: _opponentSpriteKey,
          ),
        ),
        const SizedBox(height: 40),
        AnimatedBuilder(
          animation: _playerShakeAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(_playerShakeAnimation.value, 0),
            child: child,
          ),
          child: _buildPlayerStatus(
            context,
            bm.player,
            overlayColor,
            isNarrow,
            bm,
            spriteKey: _playerSpriteKey,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildControlPanel(BattleManager bm) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        children: [
          // Dummy Settings Panel
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DUMMY SETTINGS',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'MANUAL',
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'PressStart2P',
                            fontSize: 7,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: bm.manualOpponentControl,
                          onChanged: (val) {
                            setState(() {
                              bm.manualOpponentControl = val;
                              bm.notifyListeners();
                            });
                          },
                          activeThumbColor: Colors.cyanAccent,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
                if (bm.manualOpponentControl) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'NEXT MOVE:',
                    style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'PressStart2P',
                      fontSize: 7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _showMovePicker(context, bm);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bm.pendingManualOpponentMove?.name ?? 'SELECT MOVE',
                            style: TextStyle(
                              color: bm.pendingManualOpponentMove != null
                                  ? Colors.white
                                  : Colors.white24,
                              fontFamily: 'PressStart2P',
                              fontSize: 9,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
              decoration: InputDecoration(
                hintText: 'SEARCH MOVE...',
                hintStyle: const TextStyle(
                  color: Colors.white24,
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filteredMoves.length,
              itemBuilder: (context, index) {
                final move = _filteredMoves[index];
                return _MoveRow(
                  move: move,
                  onTap: () async {
                    if (bm.currentState != BattleState.waitingForInput) return;
                    await bm.forceExecuteMove(move);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentStatus(
    BuildContext context,
    BattleOrganism organism,
    Color barColor,
    bool isNarrow,
    BattleManager bm, {
    Key? spriteKey,
  }) {
    final displayLevel = organism.organism.level;
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenW = MediaQuery.sizeOf(context).width;
    final spriteSize = isLandscape
        ? (isNarrow ? 80.0 : (screenW * 0.12).clamp(90.0, 120.0))
        : (isNarrow ? 110.0 : (screenW * 0.32).clamp(120.0, 160.0));

    final statusBox = Container(
      // FIXED: Use constraints instead of hard width for relative sizing
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width * 0.5).clamp(0.0, 260.0),
      ),
      padding: EdgeInsets.all(isNarrow ? 6 : 10),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${organism.organism.displayName} LV.$displayLevel',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isNarrow ? 9 : 11,
                fontFamily: 'PressStart2P',
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              tween: Tween<double>(
                begin: hpRatio.clamp(0.0, 1.0),
                end: hpRatio.clamp(0.0, 1.0),
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                color: value > 0.5
                    ? const Color(0xFF4CAF50)
                    : (value > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[800],
                minHeight: isNarrow ? 6 : 8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HP: ${organism.health.round()}/${organism.maxHealth} (${(hpRatio * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isNarrow ? 7 : 9,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          if (organism.statusEffects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: organism.statusEffects
                    .map(
                      (se) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: se.color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          se.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16, vertical: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(flex: 4, child: statusBox),
            const Flexible(child: SizedBox(width: 8)),
            Flexible(
              flex: 3,
              child: CompositedTransformTarget(
                link: _opponentLink,
                child: BattleSprite(
                  key: spriteKey,
                  organism: organism,
                  size: spriteSize,
                  mirror: false,
                  biomeName: _biomeName,
                  hazards: const [],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStatus(
    BuildContext context,
    BattleOrganism organism,
    Color barColor,
    bool isNarrow,
    BattleManager bm, {
    Key? spriteKey,
  }) {
    final maxHp = organism.maxHealth;
    final hpRatio = maxHp > 0 ? organism.health / maxHp : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenW = MediaQuery.sizeOf(context).width;
    final spriteSize = isLandscape
        ? (isNarrow ? 90.0 : (screenW * 0.14).clamp(100.0, 130.0))
        : (isNarrow ? 120.0 : (screenW * 0.35).clamp(130.0, 170.0));

    final displayLevel = organism.organism.level;

    final statusBox = Container(
      // FIXED: Use constraints instead of hard width for relative sizing
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width * 0.5).clamp(0.0, 260.0),
      ),
      padding: EdgeInsets.all(isNarrow ? 5 : 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${organism.organism.displayName} LV.$displayLevel',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isNarrow ? 10 : 12,
                fontFamily: 'PressStart2P',
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              tween: Tween<double>(
                begin: hpRatio.clamp(0.0, 1.0),
                end: hpRatio.clamp(0.0, 1.0),
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                color: value > 0.5
                    ? const Color(0xFF4CAF50)
                    : (value > 0.2 ? Colors.orange : Colors.red),
                backgroundColor: Colors.grey[800],
                minHeight: isNarrow ? 8 : 10,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HP: ${organism.health.round()}/${organism.maxHealth} (${(hpRatio * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isNarrow ? 8 : 10,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          if (organism.statusEffects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: organism.statusEffects
                    .map(
                      (se) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: se.color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          se.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16, vertical: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              flex: 3,
              child: CompositedTransformTarget(
                link: _playerLink,
                child: BattleSprite(
                  key: spriteKey,
                  organism: organism,
                  size: spriteSize,
                  mirror: true,
                  biomeName: _biomeName,
                  hazards: const [],
                ),
              ),
            ),
            const Flexible(child: SizedBox(width: 12)),
            Flexible(flex: 4, child: statusBox),
          ],
        ),
      ),
    );
  }

  void _showMovePicker(BuildContext context, BattleManager bm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MovePickerSheet(
        onMoveSelected: (move) {
          setState(() {
            bm.pendingManualOpponentMove = move;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Move picker bottom-sheet — owns its own search controller so filtering works
// ---------------------------------------------------------------------------
class _MovePickerSheet extends StatefulWidget {
  final ValueChanged<Move> onMoveSelected;

  const _MovePickerSheet({required this.onMoveSelected});

  @override
  State<_MovePickerSheet> createState() => _MovePickerSheetState();
}

class _MovePickerSheetState extends State<_MovePickerSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Move> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = Move.allMoves;
    _controller.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _controller.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? Move.allMoves
          : Move.allMoves.where((m) {
              return m.name.toLowerCase().contains(q) ||
                  m.description.toLowerCase().contains(q) ||
                  m.type.name.toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearch);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CHOOSE DUMMY MOVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search field — uses its own controller
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              autofocus: false,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
              decoration: InputDecoration(
                hintText: 'FILTER BY NAME / TYPE…',
                hintStyle: const TextStyle(
                  color: Colors.white24,
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white54,
                  size: 18,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filtered.length} MOVES',
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final move = _filtered[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: move.type.color.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      move.type.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    move.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                    ),
                  ),
                  subtitle: Text(
                    move.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    'P:${move.baseDamage}  A:${move.accuracy}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => widget.onMoveSelected(move),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  final Move move;
  final VoidCallback onTap;

  const _MoveRow({required this.move, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        // Column layout — can NEVER overflow horizontally
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Line 1: type chip + move name + stats (all in one Row with Flexible)
            Row(
              children: [
                // Type chip — intrinsic, clips its own text
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: move.type.color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    move.type.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                // Move name — takes all remaining horizontal space
                Expanded(
                  child: Text(
                    move.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                // Stats — right-aligned, no fixed width needed
                Text(
                  'P:${move.baseDamage} A:${move.accuracy}',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Line 2: description (always full width, ellipsized)
            Text(
              move.description,
              style: const TextStyle(color: Colors.white54, fontSize: 7),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorData {
  final int id;
  final String text;
  final Color color;
  final bool isPlayer;
  _IndicatorData({
    required this.id,
    required this.text,
    required this.color,
    required this.isPlayer,
  });
}

class _FloatingIndicatorWidget extends StatefulWidget {
  final _IndicatorData data;
  final LayerLink link;
  const _FloatingIndicatorWidget({
    super.key,
    required this.data,
    required this.link,
  });

  @override
  State<_FloatingIndicatorWidget> createState() =>
      _FloatingIndicatorWidgetState();
}

class _FloatingIndicatorWidgetState extends State<_FloatingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
    _offset = Tween(
      begin: const Offset(0, 0),
      end: const Offset(0, -2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CompositedTransformFollower(
        link: widget.link,
        showWhenUnlinked: false,
        offset: const Offset(40, -20),
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: Text(
              widget.data.text,
              style: TextStyle(
                color: widget.data.color,
                fontFamily: 'PressStart2P',
                fontSize: 12,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
