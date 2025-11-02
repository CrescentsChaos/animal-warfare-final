// lib/user_state.dart

import 'package:flutter/foundation.dart';
import 'dart:async'; 
import 'package:animal_warfare/models/captured_organism.dart'; // <-- 🚨 NEW: Import the required model
import 'local_auth_service.dart'; 

class UserState with ChangeNotifier {
  // Assuming UserData is defined elsewhere and LocalAuthService handles persistence.
  UserData? _currentUser;
  // NOTE: You must ensure LocalAuthService is initialized with the necessary data
  // to deserialize UserData if needed, but we'll stick to the provided constructor.
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
  // Stamina Regeneration Logic
  // ------------------------------------------------------------------
  void _startStaminaRegeneration() {
    // Stop any existing timer before starting a new one
    _staminaRegenTimer?.cancel(); 
    
    // Create a periodic timer that runs every 10 seconds
    _staminaRegenTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentUser != null && _currentUser!.stamina < 100) {
        // Regeneration amount: 10
        _regenerateStamina(20); 
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
  // 🚨 NEW: Battle/Capture Logic
  // ------------------------------------------------------------------
  Future<void> addCapturedOrganism(CapturedOrganism newCapture) async {
    if (_currentUser == null) {
      if (kDebugMode) print('Cannot add organism: User not logged in.');
      return;
    }

    // 1. Update the in-memory list
    final updatedList = List<CapturedOrganism>.from(_currentUser!.capturedOrganisms)
      ..add(newCapture);
      
    // 2. Create an updated UserData object using copyWith 
    // (Assuming UserData has a copyWith method for capturedOrganisms)
    _currentUser = _currentUser!.copyWith(capturedOrganisms: updatedList);

    // 3. Persist the change to the file system
    // NOTE: You must ensure LocalAuthService has the updateUser method 
    // to handle saving the updated list.
    await _authService.updateUser(_currentUser!);
    
    // 4. Notify UI listeners
    notifyListeners();
    
    if (kDebugMode) {
      print('UserState updated: ${newCapture.name} captured and saved.');
    }
  }
  
  // ------------------------------------------------------------------
  // Existing User Management
  // ------------------------------------------------------------------

  Future<void> refreshCurrentUser() async {
    await loadCurrentUser();
  }
  
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
    
    // 1. Update local state
    _currentUser = _currentUser!.decreaseStamina(amount);
    
    await _authService.updateUser(_currentUser!);
    
    notifyListeners();
  }

  @override
  void dispose() {
    // 🚨 FIX: Cancel the timer to prevent memory leaks or runtime errors 
    // if the UserState object is ever removed from the widget tree.
    _staminaRegenTimer?.cancel(); 
    super.dispose();
  }
}