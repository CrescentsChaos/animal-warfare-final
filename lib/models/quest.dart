// lib/models/quest.dart

enum QuestStatus { active, completed }

class Quest {
  final String id;
  final String description;
  final String targetOrganismName;
  final int targetCount;
  final int currentCount;
  final int rewardMoney;
  final QuestStatus status;
  final String npcId;
  final String category;
  final String giverNpcId; // which NPC gave the quest
  final List<String> rewardItemIds; // item rewards on completion
  final String completionFlag; // flag to set on completion (for blocker NPCs)

  Quest({
    required this.id,
    required this.description,
    required this.targetOrganismName,
    required this.targetCount,
    this.currentCount = 0,
    required this.rewardMoney,
    this.status = QuestStatus.active,
    this.npcId = 'jeremy_wade',
    this.category = 'River Monsters',
    this.giverNpcId = '',
    this.rewardItemIds = const [],
    this.completionFlag = '',
  });

  Quest copyWith({
    int? currentCount,
    QuestStatus? status,
  }) {
    return Quest(
      id: id,
      description: description,
      targetOrganismName: targetOrganismName,
      targetCount: targetCount,
      currentCount: currentCount ?? this.currentCount,
      rewardMoney: rewardMoney,
      status: status ?? this.status,
      npcId: npcId,
      category: category,
      giverNpcId: giverNpcId,
      rewardItemIds: rewardItemIds,
      completionFlag: completionFlag,
    );
  }

  bool get isCompleted => currentCount >= targetCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'targetOrganismName': targetOrganismName,
    'targetCount': targetCount,
    'currentCount': currentCount,
    'rewardMoney': rewardMoney,
    'status': status.index,
    'npcId': npcId,
    'category': category,
    'giverNpcId': giverNpcId,
    'rewardItemIds': rewardItemIds,
    'completionFlag': completionFlag,
  };

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
    id: json['id'],
    description: json['description'],
    targetOrganismName: json['targetOrganismName'],
    targetCount: json['targetCount'],
    currentCount: json['currentCount'],
    rewardMoney: json['rewardMoney'],
    status: QuestStatus.values[json['status']],
    npcId: json['npcId'] ?? 'jeremy_wade',
    category: json['category'] ?? 'River Monsters',
    giverNpcId: json['giverNpcId'] as String? ?? '',
    rewardItemIds: List<String>.from(json['rewardItemIds'] ?? []),
    completionFlag: json['completionFlag'] as String? ?? '',
  );
}

