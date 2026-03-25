// lib/models/npc_data.dart

class NPCData {
  final String id;
  final String name;
  final String spriteKey;
  final int y;
  final int x;
  final String facing; // 'down', 'up', 'left', 'right'
  final String scriptType; // 'trainer', 'shopkeeper', 'medic', 'quest_giver', 'fetch_quest', 'story', 'blocker', 'item_giver', 'rival', 'professor', 'major_trainer', 'evil_team', 'request_board', 'none'
  final List<String> dialogue;
  final String movementType; // 'still', 'random', 'pattern'
  final int movementRange;
  final int visionRange; // tiles the NPC can see to detect the player
  final String teamId; // links to npc_teams.json entry
  final String defeatText; // text shown after the trainer is defeated
  final bool disappearsOnDefeat; // if true, the trainer leaves the map after defeat

  // --- Event & Quest Fields ---
  final String questId; // links to a quest definition (for quest_giver)
  final String requiredFlag; // flag needed for this NPC to be active / unblock
  final String setsFlag; // flag to set after interaction (trainer defeat, story read, etc.)
  final String itemRewardId; // item to give (for item_giver)
  final int itemRewardCount; // quantity of item reward
  final String itemRequiredId; // item needed for fetch_quest
  final int itemRequiredCount; // quantity needed for fetch_quest
  final String organismRequiredId; // specific organism needed
  final List<String> postEventDialogue; // dialogue after event is done
  final String condition; // generic condition expression, e.g. "flag:beat_gym_1"
  final int rewardMoney; // money given after trainer defeat (Taka)

  NPCData({
    required this.id,
    required this.name,
    required this.spriteKey,
    required this.y,
    required this.x,
    this.facing = 'down',
    this.scriptType = 'none',
    this.dialogue = const [],
    this.movementType = 'still',
    this.movementRange = 0,
    this.visionRange = 0,
    this.teamId = '',
    this.defeatText = '',
    this.questId = '',
    this.requiredFlag = '',
    this.setsFlag = '',
    this.itemRewardId = '',
    this.itemRewardCount = 1,
    this.itemRequiredId = '',
    this.itemRequiredCount = 1,
    this.organismRequiredId = '',
    this.postEventDialogue = const [],
    this.condition = '',
    this.rewardMoney = 0,
    this.disappearsOnDefeat = false,
  });

  factory NPCData.fromJson(Map<String, dynamic> json) {
    return NPCData(
      id: json['id'] as String,
      name: json['name'] as String,
      spriteKey: json['spriteKey'] as String,
      y: json['y'] as int? ?? json['row'] as int,
      x: json['x'] as int? ?? json['col'] as int,
      facing: json['facing'] as String? ?? 'down',
      scriptType: json['scriptType'] as String? ?? 'none',
      dialogue: List<String>.from(json['dialogue'] ?? []),
      movementType: json['movementType'] as String? ?? 'still',
      movementRange: json['movementRange'] as int? ?? 0,
      visionRange: json['visionRange'] as int? ?? 0,
      teamId: json['teamId'] as String? ?? '',
      defeatText: json['defeatText'] as String? ?? '',
      questId: json['questId'] as String? ?? '',
      requiredFlag: json['requiredFlag'] as String? ?? '',
      setsFlag: json['setsFlag'] as String? ?? '',
      itemRewardId: json['itemRewardId'] as String? ?? '',
      itemRewardCount: json['itemRewardCount'] as int? ?? 1,
      itemRequiredId: json['itemRequiredId'] as String? ?? '',
      itemRequiredCount: json['itemRequiredCount'] as int? ?? 1,
      organismRequiredId: json['organismRequiredId'] as String? ?? '',
      postEventDialogue: (json['postEventDialogue'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      condition: json['condition'] as String? ?? '',
      rewardMoney: json['rewardMoney'] as int? ?? 0,
      disappearsOnDefeat: json['disappearsOnDefeat'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'spriteKey': spriteKey,
      'y': y,
      'x': x,
      'facing': facing,
      'scriptType': scriptType,
      'dialogue': dialogue,
      'movementType': movementType,
      'movementRange': movementRange,
      'visionRange': visionRange,
      'teamId': teamId,
      'defeatText': defeatText,
      'questId': questId,
      'requiredFlag': requiredFlag,
      'setsFlag': setsFlag,
      'itemRewardId': itemRewardId,
      'itemRewardCount': itemRewardCount,
      'itemRequiredId': itemRequiredId,
      'itemRequiredCount': itemRequiredCount,
      'organismRequiredId': organismRequiredId,
      'postEventDialogue': postEventDialogue,
      'condition': condition,
      'rewardMoney': rewardMoney,
      'disappearsOnDefeat': disappearsOnDefeat,
    };
  }

  NPCData copyWith({
    String? id,
    String? name,
    String? spriteKey,
    int? y,
    int? x,
    String? facing,
    String? scriptType,
    List<String>? dialogue,
    String? movementType,
    int? movementRange,
    int? visionRange,
    String? teamId,
    String? defeatText,
    String? questId,
    String? requiredFlag,
    String? setsFlag,
    String? itemRewardId,
    int? itemRewardCount,
    String? itemRequiredId,
    int? itemRequiredCount,
    String? organismRequiredId,
    List<String>? postEventDialogue,
    String? condition,
    int? rewardMoney,
    bool? disappearsOnDefeat,
  }) {
    return NPCData(
      id: id ?? this.id,
      name: name ?? this.name,
      spriteKey: spriteKey ?? this.spriteKey,
      y: y ?? this.y,
      x: x ?? this.x,
      facing: facing ?? this.facing,
      scriptType: scriptType ?? this.scriptType,
      dialogue: dialogue ?? this.dialogue,
      movementType: movementType ?? this.movementType,
      movementRange: movementRange ?? this.movementRange,
      visionRange: visionRange ?? this.visionRange,
      teamId: teamId ?? this.teamId,
      defeatText: defeatText ?? this.defeatText,
      questId: questId ?? this.questId,
      requiredFlag: requiredFlag ?? this.requiredFlag,
      setsFlag: setsFlag ?? this.setsFlag,
      itemRewardId: itemRewardId ?? this.itemRewardId,
      itemRewardCount: itemRewardCount ?? this.itemRewardCount,
      itemRequiredId: itemRequiredId ?? this.itemRequiredId,
      itemRequiredCount: itemRequiredCount ?? this.itemRequiredCount,
      organismRequiredId: organismRequiredId ?? this.organismRequiredId,
      postEventDialogue: postEventDialogue ?? this.postEventDialogue,
      condition: condition ?? this.condition,
      rewardMoney: rewardMoney ?? this.rewardMoney,
      disappearsOnDefeat: disappearsOnDefeat ?? this.disappearsOnDefeat,
    );
  }
}
