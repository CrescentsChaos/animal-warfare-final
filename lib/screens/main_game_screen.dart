import 'package:flutter/material.dart';

class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key}); 

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  // 🚀 NEW: State variable to track user status
  bool isLoggedIn = false; 

  void _onPlayTapped() {
    // A new game is usually available regardless of login
    print("Play Tapped: Starting new game.");
  }

  void _onContinueTapped() {
    // Only allow continuing if logged in
    if (isLoggedIn) {
      // TODO: Implement logic to load a SAVED game session
      print("Continue Tapped: Loading saved game.");
    } else {
      print("Continue Blocked: Must log in first.");
      // Optional: Show a message to the user
      _showSnackbar("Please log in to continue a saved game.");
    }
  }

  void _onProfileTapped() {
    // Only allow profile access if logged in
    if (isLoggedIn) {
      // TODO: Implement navigation to the user profile screen
      print("Profile Tapped: Showing user profile.");
    } else {
      print("Profile Blocked: Must log in first.");
      _showSnackbar("Please log in to view your profile.");
    }
  }

  void _onLoginLogoutTapped() {
    // 🚀 NEW: Toggle the login status for demonstration
    setState(() {
      isLoggedIn = !isLoggedIn;
    });

    if (isLoggedIn) {
      _showSnackbar("Logged In Successfully! (Simulation)");
    } else {
      _showSnackbar("Logged Out Successfully!");
    }
  }
  
  // Helper to show messages to the user (snackbars are non-retro, but functional)
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine button labels and states based on login status
    final loginButtonText = isLoggedIn ? 'LOGOUT' : 'LOGIN';
    
    // Continue and Profile buttons should only be interactable when logged in
    final isSecondaryButtonsEnabled = isLoggedIn; 

    return Scaffold(
      appBar: AppBar(
        title: const Text( 
          'ANIMAL WARFARE',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18.0,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // --- Menu Buttons ---
            _buildMenuButton('PLAY', _onPlayTapped, isEnabled: true),
            const SizedBox(height: 20),
            
            // ⭐️ Dynamic: Disabled if not logged in
            _buildMenuButton('CONTINUE', _onContinueTapped, isEnabled: isSecondaryButtonsEnabled),
            const SizedBox(height: 20),

            // ⭐️ Dynamic: Disabled if not logged in
            _buildMenuButton('PROFILE', _onProfileTapped, isEnabled: isSecondaryButtonsEnabled),
            const SizedBox(height: 60),

            // --- Login/Logout Option ---
            // ⭐️ Dynamic: Toggles function and text
            _buildMenuButton(loginButtonText, _onLoginLogoutTapped, isPrimary: false, isEnabled: true),
          ],
        ),
      ),
    );
  }

  // ⭐️ Updated Helper method to include 'isEnabled' logic
  Widget _buildMenuButton(String text, VoidCallback onPressed, {bool isPrimary = true, required bool isEnabled}) {
    // Use onPressed: null to disable the button, which greys it out automatically
    final effectiveOnPressed = isEnabled ? onPressed : null;

    return SizedBox(
      width: 200,
      height: 40,
      child: ElevatedButton(
        onPressed: effectiveOnPressed, // Pass null if disabled
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled 
              ? (isPrimary ? Colors.yellowAccent : Colors.blueGrey[800])
              : Colors.grey[700], // Grey color when disabled
          foregroundColor: Colors.black,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: BorderSide(
              color: isEnabled ? (isPrimary ? Colors.redAccent : Colors.grey) : Colors.black, 
              width: 3.0
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: isPrimary ? 16.0 : 12.0,
            color: isEnabled ? (isPrimary ? Colors.black : Colors.white70) : Colors.white38, // Faded text when disabled
          ),
        ),
      ),
    );
  }
}