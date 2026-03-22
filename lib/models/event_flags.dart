// lib/models/event_flags.dart

/// Persistent world event state.
/// Tracks trainer defeats, quest completions, story progress, one-time pickups,
/// and tile interaction cooldowns (e.g. headbutt trees).
class EventFlags {
  final Set<String> defeatedTrainers;
  final Set<String> completedQuests;
  final Set<String> storyFlags;
  final Set<String> collectedItems;
  final String currentMapId;
  /// Tile interaction cooldowns. Key: "mapId:row:col", Value: epoch millis.
  final Map<String, int> tileCooldowns;
  final Map<String, int> cutGrassTiles; // Key: "mapId:row:col", Value: game epoch millis
  final bool isSickleActive;

  const EventFlags({
    this.defeatedTrainers = const {},
    this.completedQuests = const {},
    this.storyFlags = const {},
    this.collectedItems = const {},
    this.currentMapId = 'littleroot_town',
    this.tileCooldowns = const {},
    this.cutGrassTiles = const {},
    this.isSickleActive = false,
  });

  EventFlags copyWith({
    Set<String>? defeatedTrainers,
    Set<String>? completedQuests,
    Set<String>? storyFlags,
    Set<String>? collectedItems,
    String? currentMapId,
    Map<String, int>? tileCooldowns,
    Map<String, int>? cutGrassTiles,
    bool? isSickleActive,
  }) {
    return EventFlags(
      defeatedTrainers: defeatedTrainers ?? this.defeatedTrainers,
      completedQuests: completedQuests ?? this.completedQuests,
      storyFlags: storyFlags ?? this.storyFlags,
      collectedItems: collectedItems ?? this.collectedItems,
      currentMapId: currentMapId ?? this.currentMapId,
      tileCooldowns: tileCooldowns ?? this.tileCooldowns,
      cutGrassTiles: cutGrassTiles ?? this.cutGrassTiles,
      isSickleActive: isSickleActive ?? this.isSickleActive,
    );
  }

  bool hasFlag(String flag) => storyFlags.contains(flag);
  bool isTrainerDefeated(String npcId) => defeatedTrainers.contains(npcId);
  bool isQuestCompleted(String questId) => completedQuests.contains(questId);
  bool isItemCollected(String itemId) => collectedItems.contains(itemId);

  /// Returns true if the tile at [key] is still on cooldown.
  /// Cooldown period is 5 minutes (300 000 ms).
  bool isTileOnCooldown(String key) {
    final lastUsed = tileCooldowns[key];
    if (lastUsed == null) return false;
    return DateTime.now().millisecondsSinceEpoch - lastUsed < 300000;
  }

  EventFlags withTileCooldown(String key) {
    return copyWith(tileCooldowns: {
      ...tileCooldowns,
      key: DateTime.now().millisecondsSinceEpoch,
    });
  }

  EventFlags withFlag(String flag) {
    return copyWith(storyFlags: {...storyFlags, flag});
  }

  EventFlags withTrainerDefeated(String npcId) {
    return copyWith(defeatedTrainers: {...defeatedTrainers, npcId});
  }

  EventFlags withQuestCompleted(String questId) {
    return copyWith(completedQuests: {...completedQuests, questId});
  }

  EventFlags withItemCollected(String itemId) {
    return copyWith(collectedItems: {...collectedItems, itemId});
  }

  EventFlags withCutGrass(String key, int timestamp) {
    return copyWith(cutGrassTiles: {...cutGrassTiles, key: timestamp});
  }

  EventFlags toggleSickle() {
    return copyWith(isSickleActive: !isSickleActive);
  }

  Map<String, dynamic> toJson() => {
    'defeatedTrainers': defeatedTrainers.toList(),
    'completedQuests': completedQuests.toList(),
    'storyFlags': storyFlags.toList(),
    'collectedItems': collectedItems.toList(),
    'currentMapId': currentMapId,
    'tileCooldowns': tileCooldowns,
    'cutGrassTiles': cutGrassTiles,
    'isSickleActive': isSickleActive,
  };

  factory EventFlags.fromJson(Map<String, dynamic> json) {
    return EventFlags(
      defeatedTrainers: Set<String>.from(json['defeatedTrainers'] ?? []),
      completedQuests: Set<String>.from(json['completedQuests'] ?? []),
      storyFlags: Set<String>.from(json['storyFlags'] ?? []),
      collectedItems: Set<String>.from(json['collectedItems'] ?? []),
      currentMapId: json['currentMapId'] as String? ?? 'littleroot_town',
      tileCooldowns: (json['tileCooldowns'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)) ?? {},
      cutGrassTiles: (json['cutGrassTiles'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)) ?? {},
      isSickleActive: json['isSickleActive'] as bool? ?? false,
    );
  }
}
