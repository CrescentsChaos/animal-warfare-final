// lib/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/edit_profile_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

// NEW IMPORT
import 'package:animal_warfare/settings_screen.dart'; 
// ADDED
import 'package:animal_warfare/achievement_screen.dart'; 
// END NEW IMPORT

// START NEW IMPORTS for Anidex Stat
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle; 
// END NEW IMPORTS

// ------------------------------------------------------------------
// FIX: Define the missing _createFadeRoute function here.
// ------------------------------------------------------------------
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
// ------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final LocalAuthService _authService = LocalAuthService();

  UserData? _currentUser;
  bool _isLoading = true;
  
  // START NEW: Organism list for total count
  List<dynamic> _allOrganisms = [];
  // END NEW
  
  late AudioPlayer _audioPlayer; 
  bool _wasPlayingBeforePause = false; 

  // Custom retro/military colors (Copied from other screens for consistency)
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    
    _audioPlayer = AudioPlayer(); 
    _loadUserProfile();
    _loadOrganisms();
  }
  
  // ADDED: Utility function for responsive font size
  double _responsiveFontSize(BuildContext context, double baseSize) {
    // Get the screen width
    final screenWidth = MediaQuery.of(context).size.width;
    // Define a reference width (e.g., 400 pixels for a typical phone)
    const double referenceWidth = 400.0;
    // Calculate a scaling factor
    final double scaleFactor = screenWidth / referenceWidth;
    // Apply the scaling factor to the base size
    return baseSize * scaleFactor;
  }
  // END ADDED

  // Override to handle app lifecycle changes
  @override
  didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Pause audio when app goes to background
      final playerState = await _audioPlayer.state;
      if (playerState == PlayerState.playing) {
        _wasPlayingBeforePause = true;
        await _audioPlayer.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume audio when app returns to foreground if it was playing
      if (_wasPlayingBeforePause) {
        await _audioPlayer.resume();
        _wasPlayingBeforePause = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      setState(() {
        _allOrganisms = json.decode(response);
      });
    } catch (e) {
      debugPrint('Error loading Organisms.json: $e');
      setState(() {
        _allOrganisms = [];
      });
    }
  }

  Future<void> _loadUserProfile() async {
    UserData? user = await _authService.getCurrentUser();
    
    // START NEW: Check for an existing avatar file
    if (user != null && user.avatar.isNotEmpty && user.avatar != 'default') {
      // Attempt to load the file to ensure it exists
      File avatarFile = File(user.avatar);
      if (await avatarFile.exists()) {
        // Avatar file exists, update user object with the path
        user = user.copyWith(avatar: avatarFile.path);
      } else {
        // File not found, reset to default
        user = user.copyWith(avatar: 'default');
      }
    }
    // END NEW
    
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  // Reusable button widget for consistency
  Widget _buildThemedButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryButtonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.0),
          side: const BorderSide(color: highlightColor, width: 2.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Text(
        text,
        style: TextStyle( // MODIFIED: Use TextStyle instead of const TextStyle
          color: Colors.white,
          fontFamily: 'PressStart2P',
          fontSize: _responsiveFontSize(context, 14), // MODIFIED: Responsive font size
        ),
      ),
    );
  }

  void _navigateToEditScreen() {
    if (_currentUser != null) {
      Navigator.of(context).push(_createFadeRoute(const EditProfileScreen())).then((_) {
        // Reload profile when returning from the edit screen
        _loadUserProfile();
      });
    }
  }
  
  // NEW: Navigation function for the Settings Screen
  void _navigateToSettingsScreen() {
    if (_currentUser != null) {
      Navigator.of(context).push(_createFadeRoute(SettingsScreen(
        currentUser: _currentUser!, 
        authService: _authService,
      )));
    }
  }
  
  // ADDED: Navigation function for the Achievements Screen
  void _navigateToAchievementsScreen() {
    if (_currentUser != null) {
      Navigator.of(context).push(_createFadeRoute(AchievementsScreen(
        currentUser: _currentUser!,
        allOrganisms: _allOrganisms, 
        authService: _authService, // ADDED: Pass the auth service
      )));
    }
  }
  // END NEW

  Widget _buildProfileDetail(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: secondaryButtonColor.withOpacity(0.8),
        border: Border.all(color: highlightColor, width: 1.0),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            '$label:',
            style: TextStyle( // MODIFIED: Use TextStyle instead of const TextStyle
              color: highlightColor,
              fontFamily: 'PressStart2P',
              fontSize: _responsiveFontSize(context, 12), // MODIFIED: Responsive font size
            ),
          ),
          Text(
            value.toUpperCase(),
            style: TextStyle( // MODIFIED: Use TextStyle instead of const TextStyle
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: _responsiveFontSize(context, 12), // MODIFIED: Responsive font size
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStatBlock(String quizName, Map<String, dynamic> stats) {
    final attempts = stats['attempts'] as int? ?? 0;
    final correct = stats['correct'] as int? ?? 0;
    final accuracy = attempts > 0 ? ((correct / attempts) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: primaryButtonColor.withOpacity(0.8),
        border: Border.all(color: highlightColor, width: 1.0),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quizName.toUpperCase(),
            style: TextStyle( // MODIFIED: Use TextStyle instead of const TextStyle
              color: highlightColor,
              fontFamily: 'PressStart2P',
              fontSize: _responsiveFontSize(context, 12), // MODIFIED: Responsive font size
            ),
          ),
          const SizedBox(height: 10),
          _buildDetailRow('ATTEMPTS', attempts.toString(), Colors.white),
          _buildDetailRow('CORRECT', correct.toString(), Colors.white),
          _buildDetailRow('ACCURACY', '$accuracy%', highlightColor),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle( // MODIFIED: Use TextStyle instead of const TextStyle
              color: Colors.white70,
              fontFamily: 'PressStart2P',
              fontSize: _responsiveFontSize(context, 10), // MODIFIED: Responsive font size
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'PressStart2P',
              fontSize: _responsiveFontSize(context, 10), // MODIFIED: Responsive font size
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    // MODIFIED: Added for the AppBar title
    final appBarTextStyle = TextStyle(
        color: highlightColor, 
        fontFamily: 'PressStart2P', 
        fontSize: _responsiveFontSize(context, 16)
    );
    // END MODIFIED
    
    if (_isLoading || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PROFILE'),
          backgroundColor: secondaryButtonColor,
          titleTextStyle: appBarTextStyle, // MODIFIED: Use responsive style
        ),
        body: Container(
          color: secondaryButtonColor,
          child: const Center(child: CircularProgressIndicator(color: highlightColor)),
        ),
      );
    }
    
    final user = _currentUser!;
    final totalCount = _allOrganisms.length;
    final discoveredCount = user.discoveredOrganisms.length;
    final anidexStat = totalCount > 0 ? '$discoveredCount / $totalCount' : '0 / 0';


    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: appBarTextStyle, // MODIFIED: Use responsive style
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. AVATAR (Same logic as edit_profile_screen)
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: primaryButtonColor.withOpacity(0.9),
                    border: Border.all(color: highlightColor, width: 4.0),
                    borderRadius: BorderRadius.circular(60.0),
                    image: user.avatar.isNotEmpty && user.avatar != 'default'
                        ? DecorationImage(
                            image: FileImage(File(user.avatar)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.avatar.isEmpty || user.avatar == 'default'
                      ? const Center(
                          child: Icon(
                            Icons.person,
                            color: highlightColor,
                            size: 60,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // 2. PROFILE DETAILS
              _buildProfileDetail('USERNAME', user.username),
              _buildProfileDetail('GENDER', user.gender),

              // START NEW: Anidex Stat
              if (totalCount > 0)
                _buildProfileDetail('ANIMALS IDENTIFIED', anidexStat),
              // END NEW

              const SizedBox(height: 40),

              // 4. EDIT PROFILE BUTTON
              _buildThemedButton(
                text: 'EDIT PROFILE',
                onPressed: _navigateToEditScreen,
              ),
              
              // NEW: SETTINGS BUTTON
              const SizedBox(height: 20), 
              _buildThemedButton(
                text: 'SETTINGS',
                onPressed: _navigateToSettingsScreen,
              ),
              // END NEW
              
              // ADDED: ACHIEVEMENTS BUTTON
              const SizedBox(height: 20), 
              _buildThemedButton(
                text: 'ACHIEVEMENTS',
                onPressed: _navigateToAchievementsScreen,
              ),
              // END ADDED
              
              const SizedBox(height: 40),

              // START: QUIZ STATS SECTION
              Text(
                '--- BATTLE QUIZ STATS ---',
                style: TextStyle(
                  color: highlightColor.withOpacity(0.8), 
                  fontSize: _responsiveFontSize(context, 10), // MODIFIED: Responsive font size
                  fontFamily: 'PressStart2P'
                ),
              ),
              const SizedBox(height: 20),
              
              // Dynamically build stat blocks for each quiz
              ...user.quizStats.entries.map((entry) {
                return _buildQuizStatBlock(entry.key, entry.value);
              }).toList(),

              // Display message if no stats are available
              if (user.quizStats.isEmpty)
                Text(
                  'No quiz data found. Go play!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: _responsiveFontSize(context, 12), // MODIFIED: Responsive font size
                    fontFamily: 'PressStart2P',
                  ),
                ),
              // END: QUIZ STATS SECTION
              
              const SizedBox(height: 40), 
            ],
          ),
        ),
      ),
    );
  }
}