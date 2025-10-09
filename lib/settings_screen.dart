// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For saving settings
import 'package:animal_warfare/local_auth_service.dart'; // For UserData and logout
import 'package:animal_warfare/main_screen.dart'; // For logout navigation

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
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  
  bool _isMusicEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  // --- Persistence Logic ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load saved state, default to true (ON) if no setting is found
      _isMusicEnabled = prefs.getBool('isMusicEnabled') ?? true;
      _isLoading = false;
    });
    // NOTE: In your main app, you must read this 'isMusicEnabled' value 
    // in your global AudioService to start/stop the background music.
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMusicEnabled', _isMusicEnabled);
  }
  
  // --- Helper Widgets and Functions ---
  
  // Utility function for navigation (copied from profile_screen.dart)
  PageRouteBuilder _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
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
      icon: icon != null ? Icon(icon, color: Colors.white) : const SizedBox.shrink(),
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
          title: const Text('CONFIRM LOGOUT', style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 16)),
          content: const Text('Are you sure you want to log out of the system?', style: TextStyle(color: Colors.white, fontSize: 14)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('CANCEL', style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P')),
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
              child: const Text('LOGOUT', style: TextStyle(color: Color(0xFFFF0000), fontFamily: 'PressStart2P')),
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
          fontSize: 16
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
            ? const Center(child: CircularProgressIndicator(color: highlightColor))
            : ListView(
                children: <Widget>[
                  // 1. MUSIC TOGGLE SETTING
                  Container(
                    margin: const EdgeInsets.only(bottom: 20.0),
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: primaryButtonColor.withOpacity(0.8),
                      border: Border.all(color: highlightColor, width: 2),
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'BACKGROUND MUSIC',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                        ),
                      ),
                      value: _isMusicEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _isMusicEnabled = value;
                          _saveSettings();
                        });
                      },
                      activeColor: highlightColor,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade600,
                      contentPadding: EdgeInsets.zero, 
                    ),
                  ),

                  // 2. LOGOUT BUTTON
                  const SizedBox(height: 40),
                  _buildThemedButton(
                    text: 'LOGOUT',
                    icon: Icons.exit_to_app,
                    onPressed: _logoutUser,
                    isDanger: true,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 3. DELETE ACCOUNT BUTTON (Placeholder for future feature)
                  _buildThemedButton(
                    text: 'DELETE ACCOUNT',
                    icon: Icons.delete_forever,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delete Account is not yet implemented.', 
                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12)),
                          backgroundColor: Colors.red.shade700,
                        )
                      );
                    },
                    isDanger: true,
                  ),
                ],
              ),
      ),
    );
  }
}