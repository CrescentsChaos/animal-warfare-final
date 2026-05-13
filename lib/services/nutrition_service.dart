import 'dart:async';
import 'dart:math';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:flutter/foundation.dart';

class AnimalMessage {
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isHungryAlert;

  AnimalMessage({
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isHungryAlert = false,
  });

  Map<String, dynamic> toJson() => {
    'senderId': senderId,
    'senderName': senderName,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isHungryAlert': isHungryAlert,
  };

  factory AnimalMessage.fromJson(Map<String, dynamic> json) => AnimalMessage(
    senderId: json['senderId'],
    senderName: json['senderName'],
    message: json['message'],
    timestamp: DateTime.parse(json['timestamp']),
    isHungryAlert: json['isHungryAlert'] ?? false,
  );
}

class NutritionService extends ChangeNotifier {
  static final NutritionService _instance = NutritionService._internal();
  factory NutritionService() => _instance;
  NutritionService._internal();

  final List<AnimalMessage> _messages = [];
  List<AnimalMessage> get messages => List.unmodifiable(_messages);

  Timer? _decayTimer;
  UserState? _userState;

  void initialize(UserState userState) {
    _userState = userState;
    _syncHunger(); // NEW: Catch up on decay since last session
    _startDecayTimer();
  }

  void _startDecayTimer() {
    _decayTimer?.cancel();
    // Check every minute (real time)
    _decayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _processHungerDecay();
    });
  }

  void _syncHunger() {
    if (_userState == null || _userState!.currentUser == null) return;

    final now = DateTime.now();
    bool changed = false;
    final allAnimals = _userState!.currentUser!.capturedOrganisms;

    for (var animal in allAnimals) {
      // If we don't have a checkpoint, set it to now or capture time
      if (animal.lastHungerUpdateReal == null) {
        animal.lastHungerUpdateReal = animal.capturedAtReal ?? now;
      }

      final diff = now.difference(animal.lastHungerUpdateReal!);
      final minutesPassed = diff.inMinutes;

      if (minutesPassed > 0) {
        // Decay hunger: 1 point per minute
        final int decay = minutesPassed;
        int oldHunger = animal.hungerLevel;
        animal.hungerLevel = max(0, animal.hungerLevel - decay);
        animal.lastHungerUpdateReal = now;
        
        if (animal.hungerLevel != oldHunger) {
          changed = true;
          // Note: Alerts are NOT triggered during sync to avoid notification spam on boot
        }
      }
    }

    if (changed) {
      _userState!.notifyListeners();
      notifyListeners();
    }
  }

  void _processHungerDecay() {
    if (_userState == null || _userState!.currentUser == null) return;

    bool changed = false;
    final allAnimals = _userState!.currentUser!.capturedOrganisms;

    for (var animal in allAnimals) {
      // Decay hunger: 1 point per minute of real time
      // (Approximately 100 points in 1.6 hours)
      if (animal.hungerLevel > 0) {
        animal.hungerLevel = max(0, animal.hungerLevel - 1);
        animal.lastHungerUpdateReal = DateTime.now();
        changed = true;

        // Trigger notification if hunger drops below threshold
        if (animal.hungerLevel == 20) {
          _sendAnimalMessage(animal, _getHungerMessage(animal, isCritical: true), isAlert: true);
        } else if (animal.hungerLevel == 50) {
          _sendAnimalMessage(animal, _getHungerMessage(animal, isCritical: false));
        }
      }
    }

    if (changed) {
      _userState!.notifyListeners();
      notifyListeners();
    }
  }

  void _sendAnimalMessage(CapturedOrganism animal, String text, {bool isAlert = false}) {
    final msg = AnimalMessage(
      senderId: animal.id,
      senderName: animal.displayName,
      message: text,
      timestamp: DateTime.now(),
      isHungryAlert: isAlert,
    );
    _messages.insert(0, msg);
    if (_messages.length > 50) _messages.removeLast();
    
    // If it's an alert, we might want to trigger a system notification too
    if (isAlert) {
      // Future: integrate with a global notification system
    }
    
    notifyListeners();
  }

  String _getHungerMessage(CapturedOrganism animal, {bool isCritical = false}) {
    final rng = Random();
    
    final casualMessages = [
      "Hey, my stomach is growling. Got any ${animal.baseOrganism.diet} food?",
      "I'm starting to feel a bit lightheaded... Is it lunchtime yet?",
      "Thinking about those delicious treats in your bag. Mind sharing one?",
      "I'm getting hungry. My internal clock says it's feeding time!",
    ];

    final criticalMessages = [
      "I'm starving! Please feed me soon or I won't be able to fight!",
      "Everything is starting to look like a ${animal.baseOrganism.diet == 'herbivore' ? 'leaf' : 'steak'}...",
      "Emergency! Hunger levels are critical! Send help (and food)!",
      "I can't take it anymore! I need food NOW!",
    ];

    final pool = isCritical ? criticalMessages : casualMessages;
    return pool[rng.nextInt(pool.length)];
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
