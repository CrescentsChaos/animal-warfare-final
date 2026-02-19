// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For saving settings
import 'package:animal_warfare/local_auth_service.dart'; // For UserData and logout
import 'package:animal_warfare/main_screen.dart'; // For logout navigation
import 'package:animal_warfare/services/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:animal_warfare/patch_notes_screen.dart'; // We will create this next

class SettingsScreen extends StatefulWidget {
  // Required fields based on your existing screen structure
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
  // --- Custom Colors for Theming ---
  static const Color primaryButtonColor = Color(
    0xFF38761D,
  ); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(
    0xFF1E3F2A,
  ); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod

  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  double _musicVolume = 1.0;
  double _soundVolume = 1.0;
  String _appVersion = '0.1.1';
  bool _isLoading = true;

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
      _appVersion = packageInfo.version;
      _isLoading = false;
    });
  }

  // --- Helper Widgets and Functions ---

  // Utility function for navigation (copied from profile_screen.dart)
  PageRouteBuilder _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Widget _buildThemedButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isDanger = false,
  }) {
    // Deep Red/Maroon for danger buttons like Logout/Delete
    Color buttonColor = isDanger ? const Color(0xFF8B0000) : primaryButtonColor;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, color: Colors.white)
          : const SizedBox.shrink(),
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'PressStart2P',
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.0),
          side: const BorderSide(color: highlightColor, width: 2.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  void _logoutUser() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: secondaryButtonColor.withOpacity(0.95),
          title: const Text(
            'CONFIRM LOGOUT',
            style: TextStyle(
              color: highlightColor,
              fontFamily: 'PressStart2P',
              fontSize: 16,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out of the system?',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: highlightColor,
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Dismiss dialog
                await widget.authService.logout(); // Perform logout
                // Navigate back to MainScreen and clear the navigation stack
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    _createFadeRoute(const MainScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text(
                'LOGOUT',
                style: TextStyle(
                  color: Color(0xFFFF0000),
                  fontFamily: 'PressStart2P',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 16,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: highlightColor),
              )
            : ListView(
                children: <Widget>[
                  // 1. MUSIC SETTINGS
                  _buildSectionTitle('AUDIO SETTINGS'),
                  _buildAudioControl(
                    title: 'MUSIC',
                    isEnabled: _isMusicEnabled,
                    volume: _musicVolume,
                    onToggle: (val) {
                      setState(() => _isMusicEnabled = val);
                      AudioService.instance.setMusicEnabled(val);
                    },
                    onVolumeChanged: (val) {
                      setState(() => _musicVolume = val);
                      AudioService.instance.setMusicVolume(val);
                    },
                  ),

                  _buildAudioControl(
                    title: 'SOUND EFFECTS',
                    isEnabled: _isSoundEnabled,
                    volume: _soundVolume,
                    onToggle: (val) {
                      setState(() => _isSoundEnabled = val);
                      AudioService.instance.setSoundEnabled(val);
                    },
                    onVolumeChanged: (val) {
                      setState(() => _soundVolume = val);
                      AudioService.instance.setSoundVolume(val);
                    },
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('GAME'),
                  _buildThemedButton(
                    text: 'PATCH NOTES',
                    icon: Icons.description,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).push(_createFadeRoute(const PatchNotesScreen()));
                    },
                  ),

                  const SizedBox(height: 10),
                  _buildThemedButton(
                    text: 'CONTACT & FEEDBACK',
                    icon: Icons.mail,
                    onPressed: () => _sendEmail('General Feedback'),
                  ),

                  const SizedBox(height: 10),
                  _buildThemedButton(
                    text: 'REPORT AN ISSUE',
                    icon: Icons.bug_report,
                    onPressed: _showReportDialog,
                  ),

                  const SizedBox(height: 40),
                  _buildSectionTitle('ACCOUNT'),
                  _buildThemedButton(
                    text: 'LOGOUT',
                    icon: Icons.exit_to_app,
                    onPressed: _logoutUser,
                    isDanger: true,
                  ),

                  const SizedBox(height: 10),
                  _buildThemedButton(
                    text: 'DELETE ACCOUNT',
                    icon: Icons.delete_forever,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Delete Account is not yet implemented.',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 10,
                            ),
                          ),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    },
                    isDanger: true,
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'VERSION $_appVersion',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAudioControl({
    required String title,
    required bool isEnabled,
    required double volume,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onVolumeChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: primaryButtonColor.withOpacity(0.8),
        border: Border.all(color: highlightColor, width: 2),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: onToggle,
                activeThumbColor: highlightColor,
              ),
            ],
          ),
          if (isEnabled)
            Row(
              children: [
                const Icon(Icons.volume_down, color: Colors.white, size: 16),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: onVolumeChanged,
                    activeColor: highlightColor,
                    inactiveColor: Colors.black45,
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white, size: 16),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _sendEmail(String subject, {String? body}) async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: 'crescentslegacy@gmail.com',
      queryParameters: {'subject': subject, if (body != null) 'body': body},
    );

    try {
      if (await canLaunchUrl(params)) {
        await launchUrl(params, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some devices where canLaunchUrl is unreliable
        await launchUrl(params, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showReportDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryButtonColor,
        title: const Text(
          'REPORT ISSUE',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            color: highlightColor,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Describe the issue...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: highlightColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmail('Game Report', body: controller.text);
            },
            child: const Text('SEND', style: TextStyle(color: highlightColor)),
          ),
        ],
      ),
    );
  }
}
