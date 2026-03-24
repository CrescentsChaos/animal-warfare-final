// lib/starter_choice_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/elemental_type.dart';


class StarterChoiceScreen extends StatefulWidget {
  const StarterChoiceScreen({super.key});

  @override
  State<StarterChoiceScreen> createState() => _StarterChoiceScreenState();
}

class _StarterChoiceScreenState extends State<StarterChoiceScreen>
    with TickerProviderStateMixin {
  static const _starterNames = [
    'Calico Cat',
    'Tuxedo Cat',
    'Tabby Cat',
    'Beagle Hound',
    'Pariah Dog',
  ];

  List<Organism> _starters = [];
  int _selectedIndex = -1;
  bool _isLoading = true;
  bool _isConfirming = false;
  bool _showSummary = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseCtrl;

  // NPC dialogue states
  int _dialogueStep = 0;
  static const _dialogueLines = [
    "Welcome, young adventurer! I'm Bear Grylls.",
    "In this world, animals fight alongside their tamers.",
    "But first, you'll need a partner.\nChoose wisely — this animal will be with you from the start.",
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadStarters();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStarters() async {
    final organisms = await LocalAuthService.loadOrganisms();
    final found = <Organism>[];
    for (final name in _starterNames) {
      try {
        found.add(organisms.firstWhere((o) => o.name == name));
      } catch (_) {
        // Skip if not found
      }
    }
    if (mounted) {
      setState(() {
        _starters = found;
        _isLoading = false;
      });
      _fadeCtrl.forward();
    }
  }

  String _getSpritePath(String name) {
    switch (name) {
      case 'Calico Cat':
        return 'assets/sprites/calico_cat.png';
      case 'Tuxedo Cat':
        return 'assets/sprites/tuxedo_cat.png';
      case 'Tabby Cat':
        return 'assets/sprites/tabby_cat.png';
      case 'Beagle Hound':
        return 'assets/sprites/beagle_hound.png';
      case 'Pariah Dog':
        return 'assets/sprites/pariah_dog.png';
      default:
        return 'assets/sprites/placeholder.png';
    }
  }

  CapturedOrganism _createStarter(Organism base) {
    final ivs = <String, int>{
      'health': 15,
      'attack': 15,
      'defense': 15,
      'power': 15,
      'resistance': 15,
      'speed': 15,
    };
    final bashful = Nature.findByName('Bashful');

    return CapturedOrganism(
      baseOrganism: base,
      individualValues: ivs,
      currentHealth: CapturedOrganism.calculateStat('health', base.health, 15, level: 5),
      nature: bashful,
      initialLevel: 5,
      level: 5,
      xp: CapturedOrganism.xpForLevel(5),
      teraType: base.elementalTypes.isNotEmpty
          ? base.elementalTypes.first
          : ElementalType.basic,
    );
  }

  Future<void> _confirmChoice() async {
    if (_selectedIndex < 0 || _isConfirming) return;
    setState(() => _isConfirming = true);

    final org = _starters[_selectedIndex];
    final starter = _createStarter(org);
    final userState = context.read<UserState>();
    await userState.addCapturedOrganism(starter);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: _dialogueStep < _dialogueLines.length
                  ? _buildDialoguePhase()
                  : _buildSelectionPhase(),
            ),
    );
  }

  // ─── DIALOGUE PHASE ───
  Widget _buildDialoguePhase() {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1B2A), Color(0xFF0A0E1A)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Bear Grylls portrait
              Container(
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/npc/bear-grylls.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF1A2332),
                      child: const Icon(Icons.person, color: Colors.white54, size: 80),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'BEAR GRYLLS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12.sp,
                  color: AppColors.highlightColor,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Wilderness Expert',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(flex: 1),
              // Dialogue box
              Container(
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF141C2B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _dialogueLines[_dialogueStep],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) => Opacity(
                        opacity: 0.4 + (_pulseCtrl.value * 0.6),
                        child: Text(
                          'TAP TO CONTINUE ▸',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8.sp,
                            color: AppColors.highlightColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
        // Tap to advance
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _dialogueStep++;
              });
            },
          ),
        ),
      ],
    );
  }

  // ─── SELECTION PHASE ───
  Widget _buildSelectionPhase() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1B2A), Color(0xFF0A0E1A)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              SizedBox(height: 16.h),
              // Header
              Text(
                'CHOOSE YOUR PARTNER',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12.sp,
                  color: AppColors.highlightColor,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'This animal will start your journey',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white38,
                ),
              ),
              SizedBox(height: 16.h),
              // Animal selection carousel
              Expanded(
                child: _showSummary && _selectedIndex >= 0
                    ? _buildAnimalSummary(_starters[_selectedIndex])
                    : _buildAnimalGrid(),
              ),
              // Bottom buttons
              _buildBottomButtons(),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimalGrid() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _starters.length,
      itemBuilder: (context, index) {
        final org = _starters[index];
        final selected = _selectedIndex == index;
        final types = org.elementalTypes;
        final typeColor = types.isNotEmpty
            ? types.first.color
            : Colors.grey;

        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: selected
                  ? typeColor.withValues(alpha: 0.12)
                  : const Color(0xFF141C2B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? typeColor.withValues(alpha: 0.7)
                    : Colors.white10,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: typeColor.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Sprite
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    _getSpritePath(org.name),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.pets,
                      color: typeColor,
                      size: 32,
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                // Name and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10.sp,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: types.map((t) {
                          return Container(
                            margin: EdgeInsets.only(right: 6.w),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: t.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: t.color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              t.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 7.sp,
                                fontFamily: 'PressStart2P',
                                color: t.color,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: typeColor,
                    size: 24.sp,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimalSummary(Organism org) {
    final starter = _createStarter(org);
    final types = org.elementalTypes;
    final typeColor = types.isNotEmpty ? types.first.color : Colors.grey;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          // Sprite
          Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: typeColor.withValues(alpha: 0.08),
              border: Border.all(
                color: typeColor.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: typeColor.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Image.asset(
                  _getSpritePath(org.name),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.pets, color: typeColor, size: 60),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            org.name.toUpperCase(),
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14.sp,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            org.scientificName,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8.h),
          // Type badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: types.map((t) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  t.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontFamily: 'PressStart2P',
                    color: t.color,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12.h),
          // Nature
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Nature: BASHFUL  •  Level: 5',
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.highlightColor,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Description
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFF141C2B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              org.description,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.white60,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Stats
          _buildStatGrid(starter, typeColor),
          SizedBox(height: 16.h),
          // Moves
          _buildMovesSection(starter, typeColor),
          SizedBox(height: 16.h),
          // Abilities
          _buildAbilitySection(org, typeColor),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildStatGrid(CapturedOrganism starter, Color typeColor) {
    final stats = [
      ('HP', starter.maxHealth, Colors.redAccent),
      ('ATK', starter.effectiveAttack, Colors.orangeAccent),
      ('DEF', starter.effectiveDefense, Colors.blueAccent),
      ('PWR', starter.effectivePower, Colors.purpleAccent),
      ('RES', starter.effectiveResistance, Colors.greenAccent),
      ('SPD', starter.effectiveSpeed, Colors.cyanAccent),
    ];

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF141C2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BASE STATS',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8.sp,
              color: Colors.white38,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 10.h),
          ...stats.map((s) {
            final (label, value, color) = s;
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 36.w,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 7.sp,
                        color: color,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  SizedBox(
                    width: 30.w,
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8.sp,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (value / 120).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation(
                          color.withValues(alpha: 0.7),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMovesSection(CapturedOrganism starter, Color typeColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF141C2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STARTING MOVES',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8.sp,
              color: Colors.white38,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: starter.selectedMoveNames.map((moveName) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  moveName.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 7.sp,
                    color: Colors.white70,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAbilitySection(Organism org, Color typeColor) {
    final abilities = org.abilities.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF141C2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABILITY',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8.sp,
              color: Colors.white38,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 8.h),
          ...abilities.map((a) => Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 14.sp, color: typeColor),
                SizedBox(width: 8.w),
                Text(
                  a,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Row(
        children: [
          if (_showSummary)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _showSummary = false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'BACK',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9.sp,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          if (_showSummary) SizedBox(width: 12.w),
          if (!_showSummary && _selectedIndex >= 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _showSummary = true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.highlightColor.withValues(alpha: 0.5),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'SUMMARY',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9.sp,
                    color: AppColors.highlightColor,
                  ),
                ),
              ),
            ),
          if (!_showSummary && _selectedIndex >= 0) SizedBox(width: 12.w),
          if (_selectedIndex >= 0)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isConfirming ? null : _confirmChoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: _isConfirming
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'CHOOSE ${_starters[_selectedIndex].name.toUpperCase()}',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 8.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
