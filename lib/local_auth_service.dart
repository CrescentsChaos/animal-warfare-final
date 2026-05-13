// lib/local_auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/models/rogue_like_state.dart';
import 'package:animal_warfare/models/farm_slot.dart';
import 'package:animal_warfare/models/saved_map_state.dart'; // NEW import
import 'package:animal_warfare/models/event_flags.dart';

import 'local_auth_storage_io.dart'
    if (dart.library.html) 'local_auth_storage_web.dart'
    as user_storage;

// Model to represent a user
class UserData {
  final String username;
  final String password;
  final String avatar;
  final String gender;

  // --- Character Customization Fields ---
  /// Player's chosen display name (can differ from login username)
  final String displayName;

  /// Built-in character portrait key, e.g. 'm_warrior', 'f_ranger'
  final String avatarIconKey;

  /// Player's chosen faction: 'Wilderness', 'Ocean', 'Sky', 'Shadow'
  final String faction;

  /// Starting title / rank label, e.g. 'Novice Tamer'
  final String title;

  /// Short player bio (max 80 chars)
  final String bio;

  final int money; // Currency
  final int stamina;
  final Map<String, dynamic> quizStats;
  final List<String> discoveredOrganisms;
  final List<String> completedAchievements;
  final List<CapturedOrganism> capturedOrganisms;

  /// Inventory: map from loot_id to quantity
  final Map<String, int> inventory;

  /// Crafted talismans (owned but not equipped)
  final List<String> craftedTalismans; // List of talisman IDs
  final List<Quest> activeQuests;

  /// Indices into [capturedOrganisms] for the 5-animal team
  final List<int> battleTeam;

  /// State of the current rogue-like run
  final RogueLikeState rogueLikeState;

  /// Best records for Rogue-like
  final int bestRogueFloor;
  final List<CapturedOrganism> bestRogueTeam;
  final int accountLevel;
  final int accountXP;
  final Map<String, Map<String, int>> speciesStats;
  final Map<String, CapturedOrganism?>
  explorationEncounters; // biome -> encounter
  final Map<String, dynamic> weatherData; // biome -> weather info
  final List<String>
  displayedAchievements; // NEW: 3 selected achievement titles

  /// Farming slots
  final List<FarmSlot> farmSlots;

  /// Map state persistence
  final Map<String, SavedMapState> savedMapStates;

  /// Persistent world event state
  final EventFlags eventFlags;

  // --- Banking & Secret Auth Fields ---
  final int bankTaka;
  final int bankGold;
  final int bankDiamond;
  final bool isBlackMarketUnlocked;
  final String phoneWallpaper;
  final List<Map<String, dynamic>> savedReplays;

  // --- White Out / Respawn Fields ---
  final String? lastMedicalCenterMapId;
  final int? lastMedicalCenterRow;
  final int? lastMedicalCenterCol;
  
  /// Global toggle to unlock all entries in the Anidex
  final bool anidexUnlocked;

  /// Preferred unit system: 'metric' or 'imperial'
  final String unitSystem;

  // --- Profile Customization ---
  final String avatarFrame;
  final String profileBackground;
  final List<String> unlockedFrames;
  final List<String> unlockedBackgrounds;

  UserData({
    required this.username,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
    this.displayName = '',
    this.avatarIconKey = '',
    this.faction = '',
    this.title = '',
    this.bio = '',
    this.money = 1000,
    this.stamina = 100,
    this.bankTaka = 0,
    this.bankGold = 0,
    this.bankDiamond = 0,
    this.isBlackMarketUnlocked = false,
    this.phoneWallpaper = 'plains-bg.png',
    this.anidexUnlocked = false,
    this.unitSystem = 'metric',
    this.avatarFrame = '',
    this.profileBackground = '',
    List<String>? unlockedFrames,
    List<String>? unlockedBackgrounds,
    List<Map<String, dynamic>>? savedReplays,
    this.lastMedicalCenterMapId,
    this.lastMedicalCenterRow,
    this.lastMedicalCenterCol,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements,
    List<CapturedOrganism>? capturedOrganisms,
    Map<String, int>? inventory,
    List<String>? craftedTalismans,
    List<Quest>? activeQuests,
    List<int>? battleTeam,
    RogueLikeState? rogueLikeState,
    this.bestRogueFloor = 0,
    this.bestRogueTeam = const [],
    this.accountLevel = 1,
    this.accountXP = 0,
    Map<String, Map<String, int>>? speciesStats,
    Map<String, CapturedOrganism?>? explorationEncounters,
    Map<String, dynamic>? weatherData,
    List<String>? displayedAchievements,
    List<FarmSlot>? farmSlots,
    Map<String, SavedMapState>? savedMapStates,
    EventFlags? eventFlags,
  }) : quizStats = quizStats ?? {},
       discoveredOrganisms = discoveredOrganisms ?? [],
       completedAchievements = completedAchievements ?? [],
       capturedOrganisms = capturedOrganisms ?? [],
       inventory = inventory ?? {},
       craftedTalismans = craftedTalismans ?? [],
       activeQuests = activeQuests ?? [],
       battleTeam = battleTeam ?? [],
       rogueLikeState = rogueLikeState ?? const RogueLikeState(),
       speciesStats = speciesStats ?? {},
       explorationEncounters = explorationEncounters ?? {},
       weatherData = weatherData ?? {},
       displayedAchievements = (displayedAchievements ?? []).take(3).toList(),
       farmSlots = farmSlots ?? List.generate(10, (i) => FarmSlot.empty(i)),
       savedMapStates = savedMapStates ?? {},
       eventFlags = eventFlags ?? const EventFlags(),
       unlockedFrames = unlockedFrames ?? [],
       unlockedBackgrounds = unlockedBackgrounds ?? [],
       savedReplays = savedReplays ?? [];

  /// Returns displayName if set, otherwise falls back to username
  String get effectiveDisplayName =>
      displayName.isNotEmpty ? displayName : username;

  UserData copyWith({
    String? username,
    String? password,
    String? avatar,
    String? gender,
    String? displayName,
    String? avatarIconKey,
    String? faction,
    String? title,
    String? bio,
    int? money,
    int? stamina,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements,
    List<CapturedOrganism>? capturedOrganisms,
    Map<String, int>? inventory,
    List<String>? craftedTalismans,
    List<Quest>? activeQuests,
    List<int>? battleTeam,
    RogueLikeState? rogueLikeState,
    int? bestRogueFloor,
    List<CapturedOrganism>? bestRogueTeam,
    int? accountLevel,
    int? accountXP,
    Map<String, Map<String, int>>? speciesStats,
    Map<String, CapturedOrganism?>? explorationEncounters,
    Map<String, dynamic>? weatherData,
    List<String>? displayedAchievements,
    List<FarmSlot>? farmSlots,
    int? bankTaka,
    int? bankGold,
    int? bankDiamond,
    bool? isBlackMarketUnlocked,
    String? phoneWallpaper,
    List<Map<String, dynamic>>? savedReplays,
    Map<String, SavedMapState>? savedMapStates,
    EventFlags? eventFlags,
    String? lastMedicalCenterMapId,
    int? lastMedicalCenterRow,
    int? lastMedicalCenterCol,
    bool? anidexUnlocked,
    String? unitSystem,
    String? avatarFrame,
    String? profileBackground,
    List<String>? unlockedFrames,
    List<String>? unlockedBackgrounds,
  }) {
    return UserData(
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      displayName: displayName ?? this.displayName,
      avatarIconKey: avatarIconKey ?? this.avatarIconKey,
      faction: faction ?? this.faction,
      title: title ?? this.title,
      bio: bio ?? this.bio,
      money: money ?? this.money,
      stamina: stamina ?? this.stamina,
      bankTaka: bankTaka ?? this.bankTaka,
      bankGold: bankGold ?? this.bankGold,
      bankDiamond: bankDiamond ?? this.bankDiamond,
      isBlackMarketUnlocked:
          isBlackMarketUnlocked ?? this.isBlackMarketUnlocked,
      phoneWallpaper: phoneWallpaper ?? this.phoneWallpaper,
      savedReplays: savedReplays ?? this.savedReplays,
      quizStats: quizStats ?? this.quizStats,
      discoveredOrganisms: discoveredOrganisms ?? this.discoveredOrganisms,
      completedAchievements:
          completedAchievements ?? this.completedAchievements,
      capturedOrganisms: capturedOrganisms ?? this.capturedOrganisms,
      inventory: inventory ?? this.inventory,
      craftedTalismans: craftedTalismans ?? this.craftedTalismans,
      activeQuests: activeQuests ?? this.activeQuests,
      battleTeam: battleTeam ?? this.battleTeam,
      rogueLikeState: rogueLikeState ?? this.rogueLikeState,
      bestRogueFloor: bestRogueFloor ?? this.bestRogueFloor,
      bestRogueTeam: bestRogueTeam ?? this.bestRogueTeam,
      accountLevel: accountLevel ?? this.accountLevel,
      accountXP: accountXP ?? this.accountXP,
      speciesStats: speciesStats ?? this.speciesStats,
      explorationEncounters:
          explorationEncounters ?? this.explorationEncounters,
      weatherData: weatherData ?? this.weatherData,
      displayedAchievements:
          displayedAchievements ?? this.displayedAchievements,
      farmSlots: farmSlots ?? this.farmSlots,
      savedMapStates: savedMapStates ?? this.savedMapStates,
      eventFlags: eventFlags ?? this.eventFlags,
      lastMedicalCenterMapId:
          lastMedicalCenterMapId ?? this.lastMedicalCenterMapId,
      lastMedicalCenterRow: lastMedicalCenterRow ?? this.lastMedicalCenterRow,
      lastMedicalCenterCol: lastMedicalCenterCol ?? this.lastMedicalCenterCol,
      anidexUnlocked: anidexUnlocked ?? this.anidexUnlocked,
      unitSystem: unitSystem ?? this.unitSystem,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      profileBackground: profileBackground ?? this.profileBackground,
      unlockedFrames: unlockedFrames ?? this.unlockedFrames,
      unlockedBackgrounds: unlockedBackgrounds ?? this.unlockedBackgrounds,
    );
  }

  /// The 5 animals in the battle team
  List<CapturedOrganism> get teamOrganisms {
    return battleTeam
        .where((index) => index >= 0 && index < capturedOrganisms.length)
        .map((index) => capturedOrganisms[index])
        .toList();
  }

  String get rankName {
    if (accountLevel >= 100) return 'MYTHICAL';
    if (accountLevel >= 80) return 'EMERALD';
    if (accountLevel >= 70) return 'DIAMOND';
    if (accountLevel >= 60) return 'PLATINUM';
    if (accountLevel >= 50) return 'MASTER';
    if (accountLevel >= 40) return 'GOLD';
    if (accountLevel >= 30) return 'SILVER';
    if (accountLevel >= 20) return 'BRONZE';
    return 'ROOKIE';
  }

  Color get rankColor {
    if (accountLevel >= 100) return Colors.redAccent;
    if (accountLevel >= 80) return Colors.greenAccent;
    if (accountLevel >= 70) return Colors.cyanAccent;
    if (accountLevel >= 60) return Colors.blueGrey;
    if (accountLevel >= 50) return const Color(0xFFDAA520); // Master Gold
    if (accountLevel >= 40) return Colors.orangeAccent;
    if (accountLevel >= 30) return Colors.white70;
    if (accountLevel >= 20) return Colors.brown;
    return Colors.grey;
  }

  UserData decreaseStamina(int amount) {
    final newStamina = (stamina - amount).clamp(0, 100);
    return copyWith(stamina: newStamina);
  }

  UserData restoreStamina(int amount) {
    final newStamina = (stamina + amount).clamp(0, 100);
    return copyWith(stamina: newStamina);
  }

  UserData spendMoney(int amount) {
    final newMoney = (money - amount);
    return copyWith(money: newMoney);
  }

  UserData addMoney(int amount) {
    final newMoney = (money + amount);
    return copyWith(money: newMoney);
  }

  int get xpToNextLevel => accountLevel * 200;

  UserData addXP(int amount) {
    int newXP = accountXP + amount;
    int newLevel = accountLevel;
    
    while (newXP >= (newLevel * 200)) {
      newXP -= (newLevel * 200);
      newLevel++;
    }
    
    return copyWith(accountLevel: newLevel, accountXP: newXP);
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'avatar': avatar,
    'gender': gender,
    'displayName': displayName,
    'avatarIconKey': avatarIconKey,
    'faction': faction,
    'title': title,
    'bio': bio,
    'stamina': stamina,
    'money': money,
    'quizStats': quizStats,
    'discoveredOrganisms': discoveredOrganisms,
    'completedAchievements': completedAchievements,
    'capturedOrganisms': capturedOrganisms.map((co) => co.toJson()).toList(),
    'inventory': inventory,
    'craftedTalismans': craftedTalismans,
    'activeQuests': activeQuests.map((q) => q.toJson()).toList(),
    'battleTeam': battleTeam,
    'rogueLikeState': rogueLikeState.toJson(),
    'bestRogueFloor': bestRogueFloor,
    'bestRogueTeam': bestRogueTeam.map((co) => co.toJson()).toList(),
    'accountLevel': accountLevel,
    'accountXP': accountXP,
    'speciesStats': speciesStats,
    'explorationEncounters': explorationEncounters.map(
      (k, v) => MapEntry(k, v?.toJson()),
    ),
    'weatherData': weatherData,
    'displayedAchievements': displayedAchievements,
    'farmSlots': farmSlots.map((slot) => slot.toJson()).toList(),
    'bankTaka': bankTaka,
    'bankGold': bankGold,
    'bankDiamond': bankDiamond,
    'isBlackMarketUnlocked': isBlackMarketUnlocked,
    'phoneWallpaper': phoneWallpaper,
    'savedReplays': savedReplays,
    'savedMapStates': savedMapStates.map((k, v) => MapEntry(k, v.toJson())),
    'eventFlags': eventFlags.toJson(),
    'lastMedicalCenterMapId': lastMedicalCenterMapId,
    'lastMedicalCenterRow': lastMedicalCenterRow,
    'lastMedicalCenterCol': lastMedicalCenterCol,
    'anidexUnlocked': anidexUnlocked,
    'unitSystem': unitSystem,
    'avatarFrame': avatarFrame,
    'profileBackground': profileBackground,
    'unlockedFrames': unlockedFrames,
    'unlockedBackgrounds': unlockedBackgrounds,
  };

  factory UserData.fromJson(
    Map<String, dynamic> json, {
    List<Organism>? allOrganisms,
  }) {
    Organism? findBaseOrganism(String name) {
      if (allOrganisms == null) return null;
      try {
        return allOrganisms.firstWhere((org) => org.name == name);
      } catch (_) {
        return null;
      }
    }

    final List<dynamic> capturedJson = json['capturedOrganisms'] ?? [];
    if (kDebugMode) {
      print('UserData.fromJson: capturedOrganisms JSON entries=${capturedJson.length}, allOrganisms=${allOrganisms?.length ?? "NULL"}');
    }
    final List<CapturedOrganism> capturedList = capturedJson
        .map((coJson) {
          final organismName = coJson['name'] as String?;
          if (organismName == null) {
            if (kDebugMode) print('UserData.fromJson: DROPPED entry — null name');
            return null;
          }

          final baseOrganism = findBaseOrganism(organismName);

          if (baseOrganism == null) {
            if (kDebugMode) print('UserData.fromJson: DROPPED "$organismName" — no base organism match');
            return null;
          }

          return CapturedOrganism.fromJson(coJson, [baseOrganism]);
        })
        .whereType<CapturedOrganism>()
        .toList();
    if (kDebugMode) {
      print('UserData.fromJson: final capturedList.length=${capturedList.length}');
    }
    return UserData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'N/A',
      displayName: json['displayName'] as String? ?? '',
      avatarIconKey: json['avatarIconKey'] as String? ?? '',
      faction: json['faction'] as String? ?? '',
      title: json['title'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      money: (json['money'] as num?)?.toInt() ?? 1000,
      stamina: (json['stamina'] as num?)?.toInt() ?? 100,
      bankTaka: (json['bankTaka'] as num?)?.toInt() ?? 0,
      bankGold: (json['bankGold'] as num?)?.toInt() ?? 0,
      bankDiamond: (json['bankDiamond'] as num?)?.toInt() ?? 0,
      isBlackMarketUnlocked: json['isBlackMarketUnlocked'] as bool? ?? false,
      phoneWallpaper: json['phoneWallpaper'] as String? ?? 'plains-bg.png',
      savedReplays:
          (json['savedReplays'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      quizStats: (json['quizStats'] as Map<String, dynamic>?) ?? {},
      discoveredOrganisms:
          (json['discoveredOrganisms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      completedAchievements:
          (json['completedAchievements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      capturedOrganisms: capturedList,
      inventory: json['inventory'] != null
          ? (json['inventory'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : {},
      craftedTalismans:
          (json['craftedTalismans'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      activeQuests:
          (json['activeQuests'] as List<dynamic>?)
              ?.map((q) => Quest.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      battleTeam:
          (json['battleTeam'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      rogueLikeState: json['rogueLikeState'] != null
          ? RogueLikeState.fromJson(
              json['rogueLikeState'] as Map<String, dynamic>,
              allOrganisms ?? [],
            )
          : const RogueLikeState(),
      bestRogueFloor: (json['bestRogueFloor'] as num?)?.toInt() ?? 0,
      bestRogueTeam: (json['bestRogueTeam'] as List? ?? [])
          .map((coJson) {
            final organismName = coJson['name'] as String?;
            if (organismName == null) return null;
            final base = findBaseOrganism(organismName);
            return base != null
                ? CapturedOrganism.fromJson(coJson, [base])
                : null;
          })
          .whereType<CapturedOrganism>()
          .toList(),
      accountLevel: (json['accountLevel'] as num?)?.toInt() ?? 1,
      accountXP: (json['accountXP'] as num?)?.toInt() ?? 0,
      speciesStats:
          (json['speciesStats'] as Map?)?.map(
            (k, v) => MapEntry(
              k.toString(),
              (v as Map).map((ki, vi) => MapEntry(ki.toString(), (vi as num).toInt())),
            ),
          ) ??
          {},
      explorationEncounters:
          (json['explorationEncounters'] as Map?)?.map(
            (k, v) => MapEntry(
              k as String,
              v != null
                  ? CapturedOrganism.fromJson(
                      v as Map<String, dynamic>,
                      allOrganisms ?? [],
                    )
                  : null,
            ),
          ) ??
          {},
      weatherData: (json['weatherData'] as Map?)?.cast<String, dynamic>() ?? {},
      displayedAchievements:
          (json['displayedAchievements'] as List?)?.cast<String>() ?? [],
      farmSlots:
          (json['farmSlots'] as List<dynamic>?)
              ?.map((e) => FarmSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          List.generate(10, (i) => FarmSlot.empty(i)),
      savedMapStates:
          (json['savedMapStates'] as Map?)?.map(
            (k, v) => MapEntry(
              k as String,
              SavedMapState.fromJson(v as Map<String, dynamic>, allOrganisms ?? []),
            ),
          ) ?? {},
      eventFlags: json['eventFlags'] != null
          ? EventFlags.fromJson(json['eventFlags'] as Map<String, dynamic>)
          : const EventFlags(),
      lastMedicalCenterMapId: json['lastMedicalCenterMapId'] as String?,
      lastMedicalCenterRow: (json['lastMedicalCenterRow'] as num?)?.toInt(),
      lastMedicalCenterCol: (json['lastMedicalCenterCol'] as num?)?.toInt(),
      anidexUnlocked: json['anidexUnlocked'] as bool? ?? false,
      unitSystem: json['unitSystem'] as String? ?? 'metric',
      avatarFrame: json['avatarFrame'] as String? ?? '',
      profileBackground: json['profileBackground'] as String? ?? '',
      unlockedFrames: (json['unlockedFrames'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      unlockedBackgrounds: (json['unlockedBackgrounds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }
}

// ------------------------------------------------------------------
// LocalAuthService
// ------------------------------------------------------------------
class LocalAuthService {
  static const _currentKey = 'current_user_username';
  static const _organismsAssetPath = 'assets/Organisms.json';

  /// Prevents concurrent writes to the same user file across all instances.
  static final Map<String, Future<void>?> _writeLocks = {};

  static List<Organism>? _cachedOrganisms;
  static Future<List<Organism>>? _loadingFuture;
  static Future<List<Organism>> loadOrganisms() async {
    if (_cachedOrganisms != null) return _cachedOrganisms!;
    
    // Prevent multiple concurrent loads
    if (_loadingFuture != null) return _loadingFuture!;

    final completer = Completer<List<Organism>>();
    _loadingFuture = completer.future;

    try {
      if (kDebugMode) print('LocalAuthService: Loading organisms from $_organismsAssetPath...');
      final String response = await rootBundle.loadString(_organismsAssetPath);
      final List<dynamic> data = jsonDecode(response);
      _cachedOrganisms = data
          .map((e) => Organism.fromJson(e as Map<String, dynamic>))
          .toList();
      
      if (kDebugMode) print('LocalAuthService: Successfully loaded ${_cachedOrganisms!.length} organisms.');
      completer.complete(_cachedOrganisms!);
      return _cachedOrganisms!;
    } catch (e) {
      if (kDebugMode) print('LocalAuthService: CRITICAL ERROR loading organisms: $e');
      _loadingFuture = null; // Allow retry
      completer.completeError(e);
      return [];
    }
  }

  static List<Organism> getCachedOrganisms() => _cachedOrganisms ?? [];

  Future<UserData?> readUserFile(String username) async {
    if (_writeLocks[username] != null) {
      if (kDebugMode) {
        print(
          "DEBUG: Waiting for pending write to complete before reading for $username",
        );
      }
      await _writeLocks[username];
    }
    try {
      final contents = await user_storage.readUserData(username);
      if (contents == null) {
        if (kDebugMode) {
          print("DEBUG: User file not found/does not exist for $username.");
        }
        return null;
      }
      try {
        final userMap = _robustJsonDecode(contents, username);
        final organisms = await loadOrganisms();
        
        if (organisms.isEmpty && userMap.containsKey('capturedOrganisms')) {
          final List? captured = userMap['capturedOrganisms'] as List?;
          if (captured != null && captured.isNotEmpty) {
            throw Exception('Failed to load base organisms. Aborting UserData reconstruction to prevent collection wipe.');
          }
        }

        return UserData.fromJson(
          userMap,
          allOrganisms: organisms.isEmpty ? null : organisms,
        );
      } catch (e) {
        if (kDebugMode) {
          print("ERROR: JSON decode failed for $username: $e");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("CRITICAL ERROR: Storage failure for $username: $e");
      }
      return null;
    }
  }

  Map<String, dynamic> _robustJsonDecode(String contents, String username) {
    if (contents.trim().isEmpty) {
      throw const FormatException("Empty JSON content");
    }
    try {
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      // Recovery attempt: strip trailing junk characters by searching for valid closing brace from the end
      if (kDebugMode) {
        print("DEBUG: Attempting robust JSON recovery for $username...");
      }
      int index = contents.lastIndexOf('}');
      while (index != -1) {
        try {
          final cleaned = contents.substring(0, index + 1);
          final decoded = jsonDecode(cleaned);
          if (decoded is Map<String, dynamic>) {
            if (kDebugMode) {
              print(
                "DEBUG: Successfully recovered JSON for $username at index $index.",
              );
            }
            return decoded;
          }
        } catch (_) {
          // ignore and keep searching backwards
        }
        if (index <= 0) break;
        index = contents.lastIndexOf('}', index - 1);
      }
      rethrow;
    }
  }

  Future<void> _writeUserFile(UserData user) async {
    if (_writeLocks[user.username] != null) {
      if (kDebugMode) {
        print(
          "DEBUG: Waiting for existing write operation to complete for ${user.username}",
        );
      }
      await _writeLocks[user.username];
    }

    final writeOperation = _performWrite(user);
    _writeLocks[user.username] = writeOperation;

    try {
      await writeOperation;
    } finally {
      _writeLocks[user.username] = null;
    }
  }

  Future<void> _performWrite(UserData user) async {
    try {
      if (kDebugMode) {
        print("DEBUG: Initiating write for ${user.username}...");
      }

      // 🔴 REMOVED: Faulty stale write check that aborted writes if quiz count on disk was higher.
      // This caused data loss during concurrent operations (e.g. capturing animal while quiz active).
      
      final jsonString = jsonEncode(user.toJson());
      await user_storage.writeUserData(user.username, jsonString);

      if (kDebugMode) {
        print(
          "DEBUG: SUCCESSFULLY SAVED ${user.username} (Captured: ${user.capturedOrganisms.length}, Quiz entries: ${user.quizStats.length})",
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print("ERROR writing user ${user.username}: $e");
        print(stack);
      }
      rethrow;
    }
  }

  Future<void> updateUser(UserData user) async {
    await _writeUserFile(user);
  }

  Future<bool> register(
    String username,
    String password, {
    String displayName = '',
    String gender = 'N/A',
    String avatarIconKey = '',
    String faction = '',
    String title = '',
    String bio = '',
  }) async {
    if (await readUserFile(username) != null) {
      if (kDebugMode) {
        print("DEBUG: Registration failed for $username (already exists).");
      }
      return false;
    }
    await _writeUserFile(
      UserData(
        username: username,
        password: password,
        displayName: displayName,
        gender: gender,
        avatarIconKey: avatarIconKey,
        faction: faction,
        title: title,
        bio: bio,
        discoveredOrganisms: [],
        completedAchievements: [],
        inventory: {'capture_net': 10},
        unlockedFrames: ['bronze_frame', 'savanna_frame'],
        unlockedBackgrounds: ['forest_bg'],
        avatarFrame: 'savanna_frame',
      ),
    );
    return await login(username, password);
  }

  Future<bool> login(String username, String password) async {
    final user = await readUserFile(username);
    if (user == null) {
      if (kDebugMode) {
        print("DEBUG: Login failed for $username (user not found).");
      }
      return false;
    }
    if (user.password != password) {
      if (kDebugMode) {
        print("DEBUG: Login failed for $username (wrong password).");
      }
      return false;
    }
    await _saveCurrentUserName(user.username);
    if (kDebugMode) print("DEBUG: Login successful for $username.");
    return true;
  }

  /// Automatically logs in as a Guest, creating the account if it doesn't exist.
  Future<bool> loginAsGuest() async {
    const guestUsername = 'Guest';
    const guestPassword = 'guest_password'; // Internal password for guest

    final user = await readUserFile(guestUsername);
    if (user == null) {
      await register(guestUsername, guestPassword, displayName: 'Guest Player');
    }
    return await login(guestUsername, guestPassword);
  }

  /// Reset password for an existing user. Returns true if successful.
  Future<bool> resetPassword(String username, String newPassword) async {
    final user = await readUserFile(username);
    if (user == null) {
      if (kDebugMode) {
        print("DEBUG: Password reset failed for $username (user not found).");
      }
      return false;
    }
    await _writeUserFile(user.copyWith(password: newPassword));
    if (kDebugMode) print("DEBUG: Password reset successful for $username.");
    return true;
  }

  /// Import user data from a JSON string, write it to disk, and set it as the active user.
  Future<bool> importUser(String jsonContent) async {
    try {
      final data = _robustJsonDecode(jsonContent, 'imported_user');
      final username = data['username'] as String?;

      if (username == null || username.isEmpty) {
        if (kDebugMode) {
          print("ERROR: Imported JSON is missing a valid username.");
        }
        return false;
      }

      final organisms = await loadOrganisms();
      final userData = UserData.fromJson(
        data,
        allOrganisms: organisms.isEmpty ? null : organisms,
      );

      await _writeUserFile(userData);
      await _saveCurrentUserName(username);

      if (kDebugMode) print("DEBUG: Import successful for $username.");
      return true;
    } catch (e) {
      if (kDebugMode) print("ERROR: Failed to import user: $e");
      return false;
    }
  }

  Future<void> _saveCurrentUserName(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, username);
  }

  Future<UserData?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsername = prefs.getString(_currentKey);

    if (currentUsername == null) {
      return null;
    }

    return await readUserFile(currentUsername);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
  }

  Future<void> updateProfile(
    String username, {
    String? avatar,
    String? gender,
    String? displayName,
    String? avatarIconKey,
    String? faction,
    String? title,
    String? bio,
    String? avatarFrame,
    String? profileBackground,
  }) async {
    final user = await readUserFile(username);
    if (user != null) {
      await _writeUserFile(
        user.copyWith(
          avatar: avatar,
          gender: gender,
          displayName: displayName,
          avatarIconKey: avatarIconKey,
          faction: faction,
          title: title,
          bio: bio,
          avatarFrame: avatarFrame,
          profileBackground: profileBackground,
        ),
      );
    }
  }

  Future<void> addCapturedOrganism(
    String username,
    CapturedOrganism newCapture,
  ) async {
    final user = await readUserFile(username);
    if (user == null) return;
    final list = List<CapturedOrganism>.from(user.capturedOrganisms)
      ..add(newCapture);
    await _writeUserFile(user.copyWith(capturedOrganisms: list));
  }

  Future<void> updateQuizStats(
    String username,
    String quizName,
    bool isCorrect, {
    String difficulty = 'Normal',
    int points = 0,
    int sessionPoints = 0,
    int streak = 0,
  }) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final stats = Map<String, dynamic>.from(user.quizStats);
    Map<String, dynamic> modeStats = Map<String, dynamic>.from(stats[quizName] ?? {});
    
    // Migration: if old format (direct keys), move to 'Normal' difficulty
    if (modeStats.containsKey('attempts') && !modeStats.containsKey('Normal')) {
      final oldData = Map<String, dynamic>.from(modeStats);
      modeStats = {'Normal': oldData};
    }

    final diffStats = Map<String, dynamic>.from(modeStats[difficulty] ?? {
      'attempts': 0,
      'correct': 0,
      'totalPoints': 0,
      'bestPoints': 0,
      'bestStreak': 0,
    });

    final currentBestStreak = diffStats['bestStreak'] as int? ?? 0;

    final newDiffStats = {
      ...diffStats,
      'attempts': (diffStats['attempts'] as int) + 1,
      'correct': (diffStats['correct'] as int) + (isCorrect ? 1 : 0),
      'totalPoints': (diffStats['totalPoints'] as int? ?? 0) + points,
      'bestPoints': sessionPoints > (diffStats['bestPoints'] as int? ?? 0) ? sessionPoints : (diffStats['bestPoints'] as int? ?? 0),
      'bestStreak': streak > currentBestStreak ? streak : currentBestStreak,
      'lastAttempt': DateTime.now().toIso8601String(),
    };

    modeStats[difficulty] = newDiffStats;
    stats[quizName] = modeStats;

    await _writeUserFile(user.copyWith(quizStats: stats));
  }

  Future<void> updateGameHighScore(
    String username,
    String gameName,
    int score, {
    String difficulty = 'Normal',
  }) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final stats = Map<String, dynamic>.from(user.quizStats);
    Map<String, dynamic> modeStats = Map<String, dynamic>.from(stats[gameName] ?? {});
    
    // Migration: If we have old flat data, move it to 'Normal'
    bool isOld = !modeStats.containsKey('Normal') && 
                 !modeStats.containsKey('Easy') && 
                 !modeStats.containsKey('Hard');
    bool hasData = modeStats.containsKey('attempts') || modeStats.containsKey('correct');
    
    if (isOld && hasData) {
      final oldData = Map<String, dynamic>.from(modeStats);
      modeStats = {'Normal': oldData};
    }

    final diffStats = Map<String, dynamic>.from(modeStats[difficulty] ?? {
      'attempts': 0,
      'correct': 0, // In games, 'correct' field often stores High Score
    });

    final int currentHigh = diffStats['correct'] as int? ?? 0;
    
    final newDiffStats = {
      ...diffStats,
      'attempts': (diffStats['attempts'] as int) + 1,
      'correct': score > currentHigh ? score : currentHigh,
      'lastAttempt': DateTime.now().toIso8601String(),
    };

    modeStats[difficulty] = newDiffStats;
    stats[gameName] = modeStats;

    await _writeUserFile(user.copyWith(quizStats: stats));
  }

  Future<void> unlockAchievement(String username, String achievementTitle) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final achievements = List<String>.from(user.completedAchievements);
    if (achievements.contains(achievementTitle)) return;
    
    achievements.add(achievementTitle);
    await _writeUserFile(user.copyWith(completedAchievements: achievements));
  }

  Future<void> markOrganismAsDiscovered(
    String username,
    String organismName,
  ) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final discovered = Set<String>.from(user.discoveredOrganisms);
    if (discovered.contains(organismName)) return;
    discovered.add(organismName);
    await _writeUserFile(
      user.copyWith(discoveredOrganisms: discovered.toList()),
    );
  }

  Future<void> addExperience(String username, int amount) async {
    final user = await readUserFile(username);
    if (user == null) return;
    await _writeUserFile(user.addXP(amount));
  }
}
