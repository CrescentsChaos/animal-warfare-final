// lib/models/event_flags.dart

/// Persistent world event state.
/// Tracks trainer defeats, quest completions, story progress, and one-time pickups.
class EventFlags {
  final Set<String> defeatedTrainers;
  final Set<String> completedQuests;
  final Set<String> storyFlags;
  final Set<String> collectedItems;
  final String currentMapId;

  const EventFlags({
    this.defeatedTrainers = const {},
    this.completedQuests = const {},
    this.storyFlags = const {},
    this.collectedItems = const {},
    this.currentMapId = 'littleroot_town',
  });

  EventFlags copyWith({
    Set<String>? defeatedTrainers,
    Set<String>? completedQuests,
    Set<String>? storyFlags,
    Set<String>? collectedItems,
    String? currentMapId,
  }) {
    return EventFlags(
      defeatedTrainers: defeatedTrainers ?? this.defeatedTrainers,
      completedQuests: completedQuests ?? this.completedQuests,
      storyFlags: storyFlags ?? this.storyFlags,
      collectedItems: collectedItems ?? this.collectedItems,
      currentMapId: currentMapId ?? this.currentMapId,
    );
  }

  bool hasFlag(String flag) => storyFlags.contains(flag);
  bool isTrainerDefeated(String npcId) => defeatedTrainers.contains(npcId);
  bool isQuestCompleted(String questId) => completedQuests.contains(questId);
  bool isItemCollected(String itemId) => collectedItems.contains(itemId);

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

  Map<String, dynamic> toJson() => {
    'defeatedTrainers': defeatedTrainers.toList(),
    'completedQuests': completedQuests.toList(),
    'storyFlags': storyFlags.toList(),
    'collectedItems': collectedItems.toList(),
    'currentMapId': currentMapId,
  };

  factory EventFlags.fromJson(Map<String, dynamic> json) {
    return EventFlags(
      defeatedTrainers: Set<String>.from(json['defeatedTrainers'] ?? []),
      completedQuests: Set<String>.from(json['completedQuests'] ?? []),
      storyFlags: Set<String>.from(json['storyFlags'] ?? []),
      collectedItems: Set<String>.from(json['collectedItems'] ?? []),
      currentMapId: json['currentMapId'] as String? ?? 'littleroot_town',
    );
  }
}
