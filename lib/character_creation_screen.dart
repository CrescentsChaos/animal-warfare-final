// lib/character_creation_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';

// ─────────────────────────────────────────────
// DATA DEFINITIONS
// ─────────────────────────────────────────────

class _Archetype {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _Archetype({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _Faction {
  final String key;
  final String label;
  final String description;
  final String emoji;
  final Color color;

  const _Faction({
    required this.key,
    required this.label,
    required this.description,
    required this.emoji,
    required this.color,
  });
}

const List<_Archetype> _archetypes = [
  _Archetype(
    key: 'warrior',
    label: 'Warrior',
    description: 'Fearless in battle. Leads from the front.',
    icon: Icons.shield_rounded,
    color: Color(0xFFEF5350),
  ),
  _Archetype(
    key: 'ranger',
    label: 'Ranger',
    description: 'Swift and cunning. Master of the wild.',
    icon: Icons.gps_fixed_rounded,
    color: AppColors.primary,
  ),
  _Archetype(
    key: 'scholar',
    label: 'Scholar',
    description: 'Knowledge is power. Strategist supreme.',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFFAB47BC),
  ),
  _Archetype(
    key: 'rogue',
    label: 'Rogue',
    description: 'Strikes from the shadows. Never predictable.',
    icon: Icons.flash_on_rounded,
    color: Color(0xFFFF7043),
  ),
];

const List<_Faction> _factions = [
  _Faction(
    key: 'Wilderness',
    label: 'Wilderness',
    description: 'Born from the untamed forest.',
    emoji: '🌿',
    color: Color(0xFF66BB6A),
  ),
  _Faction(
    key: 'Ocean',
    label: 'Ocean',
    description: 'Master of tides and deep waters.',
    emoji: '🌊',
    color: Color(0xFF29B6F6),
  ),
  _Faction(
    key: 'Sky',
    label: 'Sky',
    description: 'Commands the winds above.',
    emoji: '🌤',
    color: Color(0xFFFFCA28),
  ),
  _Faction(
    key: 'Shadow',
    label: 'Shadow',
    description: 'Thrives where light cannot reach.',
    emoji: '🌑',
    color: Color(0xFF7E57C2),
  ),
];

const List<String> _titles = [
  'Novice Tamer',
  'Wild Scout',
  'Beast Keeper',
  'Field Commander',
  'Apex Hunter',
  'Nature\'s Guardian',
];

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class CharacterCreationScreen extends StatefulWidget {
  final String username;
  final String password;

  const CharacterCreationScreen({
    super.key,
    required this.username,
    required this.password,
  });

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  final PageController _pageController = PageController();
  final LocalAuthService _authService = LocalAuthService();

  // ── State ──
  int _step = 0;
  String _gender = ''; // 'male' | 'female'
  final TextEditingController _displayNameController = TextEditingController();
  String _selectedArchetype = '';
  String _selectedFaction = '';
  String _selectedTitle = _titles[0];
  final TextEditingController _bioController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.username;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && _gender.isEmpty) {
      _snack('Please choose Male or Female.');
      return;
    }
    if (_step == 1 && _selectedArchetype.isEmpty) {
      _snack('Please choose an archetype.');
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Future<void> _finishCreation() async {
    if (_selectedFaction.isEmpty) {
      _snack('Please choose a faction.');
      return;
    }
    setState(() => _isLoading = true);

    final displayName = _displayNameController.text.trim().isEmpty
        ? widget.username
        : _displayNameController.text.trim();
    final avatarIconKey = '${_gender[0]}_$_selectedArchetype';

    final success = await _authService.register(
      widget.username,
      widget.password,
      displayName: displayName,
      gender: _gender == 'male' ? 'MALE' : 'FEMALE',
      avatarIconKey: avatarIconKey,
      faction: _selectedFaction,
      title: _selectedTitle,
      bio: _bioController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        await context.read<UserState>().handleSuccessfulAuth();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, a, __) => const MainScreen(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
          ),
          (_) => false,
        );
      } else {
        _snack('Username already taken. Please go back and choose another.');
      }
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.8,
                colors: [Color(0xFF0D2D2A), AppColors.background],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStepIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [_buildStep1(), _buildStep2(), _buildStep3()],
                  ),
                ),
                _buildNavButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const titles = ['YOUR IDENTITY', 'YOUR ARCHETYPE', 'YOUR FACTION'];
    const subtitles = [
      'Who are you, Commander?',
      'Choose your fighting style.',
      'Where do you belong?',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          Text(
            'CHARACTER CREATION',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: AppColors.primary.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              titles[_step],
              key: ValueKey(_step),
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 18,
                color: AppColors.highlight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              subtitles[_step],
              key: ValueKey('sub$_step'),
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 3,
              decoration: BoxDecoration(
                color: done || active ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────── STEP 1: Gender + Display Name ─────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Gender cards
          Row(
            children: [
              Expanded(
                child: _buildGenderCard(
                  'male',
                  'Male',
                  Icons.male_rounded,
                  const Color(0xFF42A5F5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderCard(
                  'female',
                  'Female',
                  Icons.female_rounded,
                  const Color(0xFFEC407A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Display name
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'DISPLAY NAME',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _displayNameController,
            maxLength: 20,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.username,
              hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              counterStyle: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              prefixIcon: const Icon(
                Icons.badge_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 180,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: selected ? 0.2 : 0.08),
              ),
              child: Icon(
                icon,
                size: 42,
                color: selected ? color : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 8),
              Icon(Icons.check_circle, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  // ─────── STEP 2: Archetype Selection ─────────

  Widget _buildStep2() {
    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: _archetypes.map((a) => _buildArchetypeCard(a)).toList(),
    );
  }

  Widget _buildArchetypeCard(_Archetype arch) {
    final selected = _selectedArchetype == arch.key;
    return GestureDetector(
      onTap: () => setState(() => _selectedArchetype = arch.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? arch.color.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? arch.color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: arch.color.withValues(alpha: 0.25),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: arch.color.withValues(alpha: selected ? 0.2 : 0.1),
              ),
              child: Icon(arch.icon, size: 30, color: arch.color),
            ),
            const SizedBox(height: 12),
            Text(
              arch.label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: selected ? arch.color : Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                arch.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 8),
              Icon(Icons.check_circle, color: arch.color, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  // ─────── STEP 3: Faction + Title + Bio ─────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Faction grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: _factions.map((f) => _buildFactionCard(f)).toList(),
          ),
          const SizedBox(height: 24),

          // Title picker
          Text(
            'YOUR TITLE',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedTitle,
                dropdownColor: AppColors.surfaceVariant,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                items: _titles
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTitle = v!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bio field
          Text(
            'YOUR BIO  (optional)',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 80,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'A fearless commander who answers only to nature…',
              hintStyle: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
              filled: true,
              fillColor: AppColors.surface,
              counterStyle: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFactionCard(_Faction faction) {
    final selected = _selectedFaction == faction.key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFaction = faction.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? faction.color.withValues(alpha: 0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? faction.color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: faction.color.withValues(alpha: 0.22),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(faction.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      faction.label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: selected ? faction.color : Colors.white,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: faction.color, size: 14),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                faction.description,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────── NAVIGATION ─────────

  Widget _buildNavButtons() {
    final isFirst = _step == 0;
    final isLast = _step == 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Row(
        children: [
          if (!isFirst)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.chevron_left_rounded),
              ),
            ),
          if (!isFirst) const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (isLast ? _finishCreation : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isLast ? 'BEGIN JOURNEY' : 'CONTINUE',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
