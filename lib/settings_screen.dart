// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/login_screen.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:animal_warfare/patch_notes_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/services/save_service.dart';
import 'package:animal_warfare/services/haptic_service.dart';
import 'package:animal_warfare/utils/transitions.dart';

class SettingsScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const SettingsScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  double _musicVolume = 1.0;
  double _soundVolume = 1.0;
  String _appVersion = '0.1.1';
  bool _isLoading = true;
  bool _anidexUnlocked = false;
  String _unitSystem = 'metric';
  bool _ignoreBiomeRequirements = false;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _isMusicEnabled = AudioService.instance.isMusicEnabled;
      _isSoundEnabled = AudioService.instance.isSoundEnabled;
      _musicVolume = AudioService.instance.musicVolume;
      _soundVolume = AudioService.instance.soundVolume;
      // Use package_info_plus at runtime; fall back to compile-time constant.
      final pkgVersion = packageInfo.version;
      _appVersion = pkgVersion.isNotEmpty ? pkgVersion : kAppVersion;
      _anidexUnlocked = widget.currentUser.anidexUnlocked;
      _unitSystem = widget.currentUser.unitSystem;
      _ignoreBiomeRequirements = widget.currentUser.ignoreBiomeRequirements;
      _isLoading = false;
    });
  }

  PageRouteBuilder _createFadeRoute(Widget page) => createSlideUpRoute(page);

  void _logoutUser() {
    HapticService.heavy();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'LOG OUT?',
            style: TextStyle(
              color: AppColors.dangerLight,
              fontFamily: 'PressStart2P',
              fontSize: 13,
            ),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await widget.authService.logout();
                if (mounted) {
                  Provider.of<UserState>(
                    context,
                    listen: false,
                  ).setCurrentUser(null);
                  Navigator.of(context).pushAndRemoveUntil(
                    _createFadeRoute(const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Log Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportSaveData() async {
    await SaveService.exportSaveData(context, widget.currentUser, (loading) {
      if (mounted) {
        setState(() => _isLoading = loading);
      }
    });
  }

  Future<void> _importSaveData() async {
    setState(() => _isLoading = true);
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        bool success = await widget.authService.importUser(jsonString);

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Save data imported successfully!')),
            );
            await Provider.of<UserState>(
              context,
              listen: false,
            ).refreshCurrentUser();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                _createFadeRoute(const MainScreen()),
                (route) => false,
              );
            }
          }
        } else {
          throw Exception('Invalid save file format.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmail(String subject, {String? body}) async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: 'crescentslegacy@gmail.com',
      queryParameters: {'subject': subject, 'body': ?body},
    );
    try {
      await launchUrl(params, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showReportDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'REPORT ISSUE',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            color: AppColors.highlight,
            fontSize: 12,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Describe the issue...',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmail('Game Report', body: controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Send',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: <Widget>[
                _buildSectionTitle('Audio'),
                _buildAudioControl(
                  title: 'Music',
                  icon: 'assets/icon/sound.png',
                  isEnabled: _isMusicEnabled,
                  volume: _musicVolume,
                  onToggle: (val) {
                    setState(() => _isMusicEnabled = val);
                    HapticService.medium();
                    AudioService.instance.setMusicEnabled(val);
                  },
                  onVolumeChanged: (val) {
                    setState(() => _musicVolume = val);
                    AudioService.instance.setMusicVolume(val);
                  },
                ),
                _buildAudioControl(
                  title: 'Sound Effects',
                  icon: 'assets/icon/sound.png',
                  isEnabled: _isSoundEnabled,
                  volume: _soundVolume,
                  onToggle: (val) {
                    setState(() => _isSoundEnabled = val);
                    HapticService.medium();
                    AudioService.instance.setSoundEnabled(val);
                  },
                  onVolumeChanged: (val) {
                    setState(() => _soundVolume = val);
                    AudioService.instance.setSoundVolume(val);
                  },
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Game'),
                _buildToggleControl(
                  title: 'Unlock Anidex (View All Data)',
                  icon: 'assets/icon/animal_dex.png',
                  isEnabled: _anidexUnlocked,
                  onToggle: (val) {
                    setState(() => _anidexUnlocked = val);
                    HapticService.medium();
                    Provider.of<UserState>(
                      context,
                      listen: false,
                    ).toggleAnidexUnlocked(val);
                  },
                ),
                _buildToggleControl(
                  title: 'Ignore Biome Requirements',
                  icon: Icons.explore_outlined,
                  isEnabled: _ignoreBiomeRequirements,
                  onToggle: (val) {
                    setState(() => _ignoreBiomeRequirements = val);
                    HapticService.medium();
                    Provider.of<UserState>(
                      context,
                      listen: false,
                    ).toggleIgnoreBiomeRequirements(val);
                  },
                ),
                _buildUnitToggle(),
                _buildActionTile(
                  title: 'Patch Notes',
                  icon: 'assets/icon/quests.png',
                  onTap: () => Navigator.of(
                    context,
                  ).push(_createFadeRoute(const PatchNotesScreen())),
                ),
                _buildActionTile(
                  title: 'Contact & Feedback',
                  icon: Icons.feedback_rounded,
                  onTap: () => _sendEmail('General Feedback'),
                ),
                _buildActionTile(
                  title: 'Report an Issue',
                  icon: 'assets/icon/insect.png',
                  onTap: _showReportDialog,
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Account'),
                _buildActionTile(
                  title: 'Import Save Data',
                  icon: 'assets/icon/inventory.png',
                  onTap: _importSaveData,
                ),
                _buildActionTile(
                  title: 'Export Save Data',
                  icon: 'assets/icon/inventory.png',
                  onTap: _exportSaveData,
                ),
                _buildActionTile(
                  title: 'Log Out',
                  icon: 'assets/icon/clear.png',
                  onTap: _logoutUser,
                  isDanger: true,
                ),
                _buildActionTile(
                  title: 'Unstuck Player',
                  icon: 'assets/icon/electric.png',
                  onTap: () {
                    final userState = Provider.of<UserState>(
                      context,
                      listen: false,
                    );
                    userState.requestUnstuck();
                    Navigator.of(context).pop();
                  },
                ),
                _buildActionTile(
                  title: 'Delete Account',
                  icon: 'assets/icon/clear.png',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Delete Account is not yet implemented.'),
                      ),
                    );
                  },
                  isDanger: true,
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'v$_appVersion',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioControl({
    required String title,
    required dynamic icon,
    required bool isEnabled,
    required double volume,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onVolumeChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                icon is String
                    ? Image.asset(
                        icon,
                        color: AppColors.primary,
                        width: 20,
                        height: 20,
                      )
                    : Icon(
                        icon as IconData,
                        color: AppColors.primary,
                        size: 20,
                      ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(value: isEnabled, onChanged: onToggle),
              ],
            ),
          ),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.volume_down_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  Expanded(
                    child: Slider(value: volume, onChanged: onVolumeChanged),
                  ),
                  const Icon(
                    Icons.volume_up_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleControl({
    required String title,
    required dynamic icon,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            icon is String
                ? Image.asset(icon, width: 20, height: 20)
                : Icon(icon as IconData, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(value: isEnabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required dynamic icon,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? AppColors.dangerLight : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDanger
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                icon is String
                    ? Image.asset(icon, width: 20, height: 20)
                    : Icon(icon as IconData, color: color, size: 20),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isDanger ? AppColors.dangerLight : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.settings_overscan,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit Measurement System',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _unitSystem == 'metric'
                        ? 'Metric (KG, M)'
                        : 'Imperial (LBS, FT)',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _unitSystem == 'imperial',
              onChanged: (val) async {
                setState(() {
                  _unitSystem = val ? 'imperial' : 'metric';
                });
                HapticService.medium();
                await Provider.of<UserState>(
                  context,
                  listen: false,
                ).toggleUnitSystem();
              },
            ),
          ],
        ),
      ),
    );
  }
}
