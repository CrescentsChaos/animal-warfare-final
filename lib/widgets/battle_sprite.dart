import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/game/biome_map_data.dart';

class BattleSprite extends StatefulWidget {
  final BattleOrganism organism;
  final double size;
  final VoidCallback? onTap;
  final bool mirror;
  final String biomeName;
  final List<String> hazards;
  final bool hideAnimal;
  final String? encounterTileId;

  const BattleSprite({
    super.key,
    required this.organism,
    required this.size,
    this.onTap,
    this.mirror = false,
    required this.biomeName,
    required this.hazards,
    this.hideAnimal = false,
    this.encounterTileId,
  });

  @override
  State<BattleSprite> createState() => BattleSpriteState();
}

class BattleSpriteState extends State<BattleSprite>
    with TickerProviderStateMixin {
  String? _imageSourceType;
  late String _imagePath;
  String _platformImagePath = 'assets/platforms/default.png';
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;
  late AnimationController _faintController;
  late Animation<double> _faintOpacity;
  late Animation<double> _faintFlash;
  late AnimationController _statChangeController;
  late Animation<double> _statChangeAnimation;
  bool _isStatBuff = true;

  bool get _shouldHideAnimal {
    final bo = widget.organism;
    BattleManager? bm;
    try {
      bm = Provider.of<BattleManager>(context, listen: false);
    } catch (_) {}
    final isAnimalSent = bm == null || (bo.isPlayer ? bm.playerAnimalSent : bm.opponentAnimalSent);
    if (widget.hideAnimal || !isAnimalSent) return true;

    // Hide opponent animal during trainer intro or mid-battle switch dialogue (only when health > 0)
    if (bm != null &&
        !bo.isPlayer &&
        bm.isTrainerBattle &&
        bm.trainerDialogueActive &&
        bo.health > 0) {
      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _determineImageSource();
    _determinePlatformImage();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );

    _faintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _faintOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _faintController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    _faintFlash = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _faintController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _statChangeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _statChangeAnimation = CurvedAnimation(
      parent: _statChangeController,
      curve: Curves.easeOut,
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    _entryController.dispose();
    _faintController.dispose();
    _statChangeController.dispose();
    super.dispose();
  }

  Future<void> faint() async {
    if (!mounted) return;
    await _faintController.forward();
  }

  void showStatChange(bool isBuff) {
    if (!mounted) return;
    setState(() {
      _isStatBuff = isBuff;
    });
    _statChangeController.forward(from: 0);
  }

  @override
  void didUpdateWidget(BattleSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.organism.displayBaseName != oldWidget.organism.displayBaseName ||
        widget.organism.displaySprite != oldWidget.organism.displaySprite) {
      _determineImageSource();
      _entryController.reset();
      _entryController.forward();
    }
    if (widget.encounterTileId != oldWidget.encounterTileId) {
      _determinePlatformImage();
    }
  }

  String _getLocalPath() {
    final fileName = widget.organism.displayBaseName
        .toString()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll('-', '_');
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _imageSourceType = 'network';
          _imagePath = widget.organism.displaySprite;
        });
      }
    }
  }

  Future<void> _determinePlatformImage() async {
    final tileId = widget.encounterTileId;
    
    // Attempt 1: If we have a tile ID, try that first or handle its category
    if (tileId != null) {
      final tileDef = BiomeDataManager.allTiles[tileId];
      if (tileDef?.category == TileCategory.tallGrass) {
        if (mounted) {
          setState(() => _platformImagePath = 'assets/platforms/forest.webp');
        }
        return;
      }

      try {
        final pPath = 'assets/platforms/$tileId.png';
        await rootBundle.load(pPath);
        if (mounted) {
          setState(() => _platformImagePath = pPath);
          return;
        }
      } catch (_) {
        try {
          final wPath = 'assets/platforms/$tileId.webp';
          await rootBundle.load(wPath);
          if (mounted) {
            setState(() => _platformImagePath = wPath);
            return;
          }
        } catch (_) {}
      }
    }

    // Attempt 2: Use the biomeName to find a platform
    var normalizedBiome = widget.biomeName;
    if (normalizedBiome.contains(',')) {
      normalizedBiome = normalizedBiome.split(',')[0];
    }
    normalizedBiome = normalizedBiome.trim().toLowerCase().replaceAll(' ', '_');
    
    if (normalizedBiome == 'battle_arena') {
      if (mounted) {
        setState(() => _platformImagePath = 'assets/platforms/Ceramic.webp');
      }
      return;
    }

    try {
      final wPath = 'assets/platforms/$normalizedBiome.webp';
      await rootBundle.load(wPath);
      if (mounted) {
        setState(() => _platformImagePath = wPath);
        return;
      }
    } catch (_) {
      try {
        final pPath = 'assets/platforms/$normalizedBiome.png';
        await rootBundle.load(pPath);
        if (mounted) {
          setState(() => _platformImagePath = pPath);
          return;
        }
      } catch (_) {}
    }

    // Fallback
    if (mounted) {
      setState(() => _platformImagePath = 'assets/platforms/default.png');
    }
  }

  Widget _buildHazards() {
    if (widget.hazards.isEmpty) return const SizedBox.shrink();

    final hazardCounts = <String, int>{};
    for (final h in widget.hazards) {
      hazardCounts[h] = (hazardCounts[h] ?? 0) + 1;
    }

    final children = <Widget>[];

    for (final entry in hazardCounts.entries) {
      final hazard = entry.key;
      final count = entry.value;

      String assetPath = '';
      if (hazard == 'stealth_rock') {
        assetPath = 'assets/stealth_rock.png';
      } else if (hazard == 'spikes') {
        assetPath = 'assets/spikes.png';
      } else if (hazard == 'toxic_spikes') {
        assetPath = 'assets/toxic_spikes.png';
      } else if (hazard == 'sticky_web') {
        assetPath = 'assets/sticky_web.png';
      }

      if (assetPath.isEmpty) continue;

      for (int i = 0; i < count; i++) {
        final double offset = i * 4.0;
        children.add(
          Positioned(
            top: -offset,
            left: offset,
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      }

      if (count > 1) {
        children.add(
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Text(
                'x$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ),
        );
      }
    }

    return SizedBox.expand(
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }

  Widget _buildImage(String imagePath, {double? width, double? height}) {
    if (_imageSourceType == 'local') {
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.help,
          color: Colors.white24,
          size: width != null ? width * 0.5 : 50,
        ),
      );
    } else {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Center(
                child: SizedBox(
                  width: width != null ? width * 0.2 : 20,
                  height: height != null ? height * 0.2 : 20,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.pets,
          color: Colors.white54,
          size: width != null ? width * 0.4 : 40,
        ),
      );
    }
  }

  Widget _buildBaseSpriteLayer({
    required BattleOrganism bo,
    required String imagePath,
    required double size,
    required bool isPrismorphed,
    required ElementalType? teraType,
  }) {
    if (bo.isInvulnerable || _shouldHideAnimal) {
      return SizedBox(width: size, height: size);
    }

    final matrix = bo.statusEffects.length > 1
        ? const <double>[
            1,
            0,
            0,
            0,
            0,
            0,
            0.8,
            0,
            0,
            0,
            0,
            0,
            1.2,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]
        : const <double>[
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ];

    final isSubstituteActive = bo.substituteHealth > 0;
    final hasStealth = bo.statusEffects.any(
      (se) => se.type == StatusEffectType.stealth,
    );

    Widget sprite = _buildImage(imagePath, width: size, height: size);
    if (widget.mirror) {
      sprite = Transform.flip(flipX: true, child: sprite);
    }

    sprite = ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: sprite,
    );

    if (isSubstituteActive) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.matrix(const <double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: sprite,
      );
    }

    if (isPrismorphed && teraType != null) {
      final teraColor = teraType.color;
      sprite = Stack(
        children: [
          sprite,
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              Widget effectLayer = _buildImage(
                imagePath,
                width: size,
                height: size,
              );
              if (widget.mirror) {
                effectLayer = Transform.flip(flipX: true, child: effectLayer);
              }
              return ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      teraColor.withValues(alpha: 0.0),
                      teraColor.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0.7),
                      teraColor.withValues(alpha: 0.4),
                      teraColor.withValues(alpha: 0.0),
                    ],
                    stops: [
                      0.0,
                      (_pulseController.value - 0.2).clamp(0.0, 1.0),
                      _pulseController.value,
                      (_pulseController.value + 0.2).clamp(0.0, 1.0),
                      1.0,
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: effectLayer,
              );
            },
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: PrismorphSparklePainter(color: teraColor),
            ),
          ),
        ],
      );
    }

    if (hasStealth) {
      sprite = Opacity(opacity: 0.35, child: sprite);
    }

    return sprite;
  }

  Widget _buildOutlineLayer({
    required BattleOrganism bo,
    required String imagePath,
    required double size,
  }) {
    if (bo.isInvulnerable || _shouldHideAnimal) {
      return const SizedBox.shrink();
    }

    final spriteOutlineColor = Colors.black.withValues(alpha: 0.8);
    final hasStealth = bo.statusEffects.any(
      (se) => se.type == StatusEffectType.stealth,
    );

    Widget outline = _buildImage(imagePath, width: size, height: size);
    if (widget.mirror) {
      outline = Transform.flip(flipX: true, child: outline);
    }

    outline = ColorFiltered(
      colorFilter: ColorFilter.mode(spriteOutlineColor, BlendMode.srcIn),
      child: outline,
    );

    if (hasStealth) {
      outline = Opacity(opacity: 0.35, child: outline);
    }
    return outline;
  }

  @override
  Widget build(BuildContext context) {
    final bo = widget.organism;
    final size = widget.size;
    final isPrismorphed = bo.isPrismorphed;
    final teraType = bo.activeTeraType;

    BattleManager? bm;
    try {
      bm = Provider.of<BattleManager>(context);
    } catch (_) {}

    final showTrainer = bm != null &&
        !bo.isPlayer &&
        bm.isTrainerBattle &&
        bm.trainerDialogueActive &&
        bm.trainerInfo != null;

    if (_imageSourceType == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    const double outlineOffset = 1.0;

    final overlayStatus = bo.statusEffects.isNotEmpty
        ? bo.statusEffects.firstWhere(
            (se) => se.type != StatusEffectType.none,
            orElse: () => const StatusEffect(type: StatusEffectType.none),
          )
        : const StatusEffect(type: StatusEffectType.none);
    final overlayPath = overlayStatus.overlayAssetPath;

    final animalStack = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            _bounceController,
            _entryController,
            _pulseController,
            _faintController,
          ]),
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, _bounceAnimation.value),
              child: Transform.scale(
                scale: _entryAnimation.value,
                alignment: Alignment.bottomCenter,
                child: Stack(
                  children: [
                    // Outlines
                    for (var x in [-outlineOffset, outlineOffset])
                      for (var y in [-outlineOffset, outlineOffset])
                        Transform.translate(
                          offset: Offset(x, y),
                          child: _buildOutlineLayer(
                            bo: bo,
                            imagePath: _imagePath,
                            size: size,
                          ),
                        ),
                    for (var x in [-outlineOffset, outlineOffset])
                      Transform.translate(
                        offset: Offset(x, 0),
                        child: _buildOutlineLayer(
                          bo: bo,
                          imagePath: _imagePath,
                          size: size,
                        ),
                      ),
                    for (var y in [-outlineOffset, outlineOffset])
                      Transform.translate(
                        offset: Offset(0, y),
                        child: _buildOutlineLayer(
                          bo: bo,
                          imagePath: _imagePath,
                          size: size,
                        ),
                      ),

                    // Main sprite
                    Opacity(
                      opacity: _faintOpacity.value,
                      child: Stack(
                        children: [
                          _buildBaseSpriteLayer(
                            bo: bo,
                            imagePath: _imagePath,
                            size: size,
                            isPrismorphed: isPrismorphed,
                            teraType: teraType,
                          ),
                          // Stat Change Animation Overlay
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _statChangeAnimation,
                              builder: (context, _) {
                                if (_statChangeController.isDismissed) {
                                  return const SizedBox.shrink();
                                }
                                final double progress =
                                    _statChangeAnimation.value;
                                final double opacity = progress < 0.2
                                    ? progress / 0.2
                                    : (progress > 0.8
                                          ? (1.0 - progress) / 0.2
                                          : 1.0);

                                final color = _isStatBuff
                                    ? Colors.cyanAccent
                                    : Colors.orangeAccent;
                                final offset = _isStatBuff
                                    ? -20.0 * progress
                                    : 20.0 * progress;

                                return Transform.translate(
                                  offset: Offset(0, offset),
                                  child: Opacity(
                                    opacity: opacity * 0.5,
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              color,
                                              color.withValues(alpha: 0),
                                            ],
                                          ).createShader(bounds),
                                      blendMode: BlendMode.srcATop,
                                      child: _buildBaseSpriteLayer(
                                        bo: bo,
                                        imagePath: _imagePath,
                                        size: size,
                                        isPrismorphed: isPrismorphed,
                                        teraType: teraType,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_faintFlash.value > 0)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: _faintFlash.value,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (!bo.isInvulnerable && overlayPath != null)
          Positioned.fill(
            child: Image.asset(
              overlayPath,
              fit: BoxFit.contain,
              opacity: const AlwaysStoppedAnimation(0.85),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(child: _buildHazards()),
        Positioned.fill(
          child: ScreenShieldOverlay(organism: widget.organism, size: size),
        ),
      ],
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: EdgeInsets.only(
          right: showTrainer ? size * 0.25 : 0.0,
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: -size * 0.05 + 20.0,
                child: Image.asset(
                  _platformImagePath,
                  width: size * 1.5,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              if (showTrainer)
                if (!_shouldHideAnimal)
                  Transform.translate(
                    offset: Offset(-size * 0.22, 0),
                    child: animalStack,
                  )
                else
                  const SizedBox.shrink()
              else if (!_shouldHideAnimal)
                animalStack,
              if (showTrainer)
                Positioned(
                  bottom: -size * 0.05 + 30.0,
                  child: Transform.translate(
                    offset: Offset(_shouldHideAnimal ? 0 : size * 0.28, 0),
                    child: Image.asset(
                      bm.trainerInfo!.spritePath,
                      width: size * 0.9,
                      height: size * 0.9,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: size * 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScreenShieldOverlay extends StatefulWidget {
  final BattleOrganism organism;
  final double size;
  const ScreenShieldOverlay({
    super.key,
    required this.organism,
    required this.size,
  });

  @override
  State<ScreenShieldOverlay> createState() => _ScreenShieldOverlayState();
}

class _ScreenShieldOverlayState extends State<ScreenShieldOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Note: We use the context and provider to check BattleManager for screens.
    // In some cases (like Training mode), satisfy dependencies.
    final bm = Provider.of<BattleManager>(context);
    final isPlayer = widget.organism.isPlayer;

    final hasReflect = isPlayer
        ? bm.playerReflectTurns > 0
        : bm.opponentReflectTurns > 0;
    final hasLightScreen = isPlayer
        ? bm.playerLightScreenTurns > 0
        : bm.opponentLightScreenTurns > 0;
    final hasAuroraVeil = isPlayer
        ? bm.playerAuroraVeilTurns > 0
        : bm.opponentAuroraVeilTurns > 0;
    final hasSafeguard = isPlayer
        ? bm.playerSafeguardTurns > 0
        : bm.opponentSafeguardTurns > 0;

    if (!hasReflect && !hasLightScreen && !hasAuroraVeil && !hasSafeguard) {
      return const SizedBox.shrink();
    }

    final List<String> activeScreens = [];
    if (hasAuroraVeil) activeScreens.add('assets/aurora_veil.png');
    if (hasReflect) activeScreens.add('assets/reflect.png');
    if (hasLightScreen) activeScreens.add('assets/light_screen.png');
    if (hasSafeguard) activeScreens.add('assets/safeguard.png');

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double pulse =
            0.55 + 0.45 * math.sin(_pulseController.value * math.pi);
        final List<Widget> layers = [];

        for (int i = 0; i < activeScreens.length; i++) {
          final double scaleOffset = 1.0 + (i * 0.06);
          layers.add(
            Positioned.fill(
              child: Transform.scale(
                scale: scaleOffset,
                alignment: Alignment.center,
                child: Opacity(
                  opacity: pulse * 0.85,
                  child: Image.asset(
                    activeScreens[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
        }
        return SizedBox.expand(
          child: Stack(clipBehavior: Clip.none, children: layers),
        );
      },
    );
  }
}

class PrismorphSparklePainter extends CustomPainter {
  final Color color;
  PrismorphSparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PrismorphSparklePainter oldDelegate) => false;
}
