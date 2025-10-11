// lib/user_state.dart

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // 🚨 NEW: Import for the Timer class
import 'local_auth_service.dart'; 

class UserState with ChangeNotifier {
  UserData? _currentUser;
  final LocalAuthService _authService = LocalAuthService();
  
  // 🚨 NEW: Timer to handle periodic regeneration
  Timer? _staminaRegenTimer;

  UserData? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Constructor/Initializer
  UserState() {
    // Start loading data immediately
    loadCurrentUser();
    // Start the regeneration process
    _startStaminaRegeneration();
  }
  
  // ------------------------------------------------------------------
  // 🚨 NEW: Stamina Regeneration Logic
  // ------------------------------------------------------------------
  void _startStaminaRegeneration() {
    // Stop any existing timer before starting a new one
    _staminaRegenTimer?.cancel(); 
    
    // Create a periodic timer that runs every 10 seconds
    _staminaRegenTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentUser != null && _currentUser!.stamina < 100) {
        // Regeneration amount: 10
        _regenerateStamina(10); 
      }
    });
  }
  void setCurrentUser(UserData? user) {
    if (user != _currentUser) {
      _currentUser = user;
      notifyListeners();
    }
  }
  Future<void> _regenerateStamina(int amount) async {
    if (_currentUser == null) return;

    // 1. Update the local model using the UserData method
    _currentUser = _currentUser!.restoreStamina(amount);

    // 2. Persist the change to the file system (optional, but good practice for games)
    await _authService.updateUser(_currentUser!);

    // 3. Notify all listeners (like the StatsModal) to rebuild
    notifyListeners();
  }
  
  // ------------------------------------------------------------------
  // Existing Methods
  // ------------------------------------------------------------------

  Future<void> loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
  }

  Future<void> handleSuccessfulAuth() async {
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
  }

  // Example method to decrease stamina (called from the StatsModal)
  Future<void> decreaseStamina(int amount) async {
    if (_currentUser == null) return;
    
    _currentUser = _currentUser!.decreaseStamina(amount);
    await _authService.updateUser(_currentUser!);
    notifyListeners();
  }
  
  // ------------------------------------------------------------------
  // 🚨 CRITICAL FIX: Dispose the Timer
  // ------------------------------------------------------------------
  @override
  void dispose() {
    _staminaRegenTimer?.cancel(); // Cancel the timer when the state is destroyed
    super.dispose();
  }
}