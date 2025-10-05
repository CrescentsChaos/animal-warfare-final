import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/edit_profile_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

// ------------------------------------------------------------------
// FIX: Define the missing _createFadeRoute function here.
// ------------------------------------------------------------------
PageRouteBuilder _createFadeRoute(Widget page) {
  return PageRouteBuilder(
    // Adjust the transition duration for your desired speed (e.g., 400ms)
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Use a FadeTransition for a smooth screen appearance
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

  late AudioPlayer _audioPlayer; 
  bool _wasPlayingBeforePause = false; 

  // Custom retro/military colors
  static const Color primaryButtonColor = Color(0xFF38761D);
  static const Color secondaryButtonColor = Color(0xFF1E3F2A);
  static const Color highlightColor = Color(0xFFDAA520);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 

    _audioPlayer = AudioPlayer(); 
    _playBackgroundMusic();
    
    _loadUserProfile();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pauseMusic(true);
    } else if (state == AppLifecycleState.resumed) {
      _resumeMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playBackgroundMusic() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/profile.mp3')); 
  }

  void _pauseMusic(bool rememberState) async {
    if (rememberState) {
      _wasPlayingBeforePause = _audioPlayer.state == PlayerState.playing;
    }
    await _audioPlayer.pause();
  }

  void _resumeMusic() async {
    if (_wasPlayingBeforePause) {
      await _audioPlayer.resume();
      _wasPlayingBeforePause = false;
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  void _navigateToEditScreen() async {
    _pauseMusic(false); 

    await Navigator.of(context).push(
      _createFadeRoute(const EditProfileScreen()), 
    );
    _resumeMusic(); 

    _loadUserProfile();
  }

  // --- UI Helpers ---

  Widget _buildThemedButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: primaryButtonColor,
        border: Border.all(color: highlightColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlightColor.withOpacity(0.8),
              fontSize: 12,
              fontFamily: 'PressStart2P',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'PressStart2P',
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PLAYER PROFILE'),
          backgroundColor: secondaryButtonColor,
          foregroundColor: highlightColor,
          titleTextStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 18),
        ),
        body: const Center(child: CircularProgressIndicator(color: highlightColor)),
      );
    }

    final user = _currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Error: User data not found.")));
    }

    ImageProvider? avatarImage;
    if (user.avatar.isNotEmpty && user.avatar != 'default') {
      final file = File(user.avatar);
      if (file.existsSync()) {
        avatarImage = FileImage(file);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PLAYER PROFILE'),
        backgroundColor: secondaryButtonColor,
        foregroundColor: highlightColor,
        titleTextStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 18),
      ),
      // **UPDATED: Added ColorFilter to darken the background image.**
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/profile.png'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken), // Adjust opacity (e.g., black45, black87)
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 1. AVATAR (Display Only)
              CircleAvatar(
                radius: 80,
                backgroundColor: highlightColor.withOpacity(0.2),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? const Icon(Icons.person, size: 50, color: highlightColor)
                    : null,
              ),
              const SizedBox(height: 40),

              // 2. USERNAME (Read-only Detail)
              _buildProfileDetail('USERNAME', user.username),

              // 3. GENDER (Read-only Detail)
              _buildProfileDetail('GENDER', user.gender),

              const SizedBox(height: 40),

              // 4. EDIT PROFILE BUTTON
              _buildThemedButton(
                text: 'EDIT PROFILE',
                onPressed: _navigateToEditScreen,
              ),
              const SizedBox(height: 40),

              // Placeholder for future stats
              Text(
                '--- BATTLE STATS HERE ---',
                style: TextStyle(color: highlightColor.withOpacity(0.5), fontSize: 10, fontFamily: 'PressStart2P'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
