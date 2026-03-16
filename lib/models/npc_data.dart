// lib/models/npc_data.dart

class NPCData {
  final String id;
  final String name;
  final String spriteKey;
  final int row;
  final int col;
  final String scriptType; // e.g., 'shopkeeper', 'medic', 'none'
  final List<String> dialogue;
  final String movementType; // 'still', 'random', 'pattern'
  final int movementRange;

  NPCData({
    required this.id,
    required this.name,
    required this.spriteKey,
    required this.row,
    required this.col,
    this.scriptType = 'none',
    this.dialogue = const [],
    this.movementType = 'still',
    this.movementRange = 0,
  });

  factory NPCData.fromJson(Map<String, dynamic> json) {
    return NPCData(
      id: json['id'] as String,
      name: json['name'] as String,
      spriteKey: json['spriteKey'] as String,
      row: json['row'] as int,
      col: json['col'] as int,
      scriptType: json['scriptType'] as String? ?? 'none',
      dialogue: List<String>.from(json['dialogue'] ?? []),
      movementType: json['movementType'] as String? ?? 'still',
      movementRange: json['movementRange'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'spriteKey': spriteKey,
      'row': row,
      'col': col,
      'scriptType': scriptType,
      'dialogue': dialogue,
      'movementType': movementType,
      'movementRange': movementRange,
    };
  }

  NPCData copyWith({
    String? id,
    String? name,
    String? spriteKey,
    int? row,
    int? col,
    String? scriptType,
    List<String>? dialogue,
    String? movementType,
    int? movementRange,
  }) {
    return NPCData(
      id: id ?? this.id,
      name: name ?? this.name,
      spriteKey: spriteKey ?? this.spriteKey,
      row: row ?? this.row,
      col: col ?? this.col,
      scriptType: scriptType ?? this.scriptType,
      dialogue: dialogue ?? this.dialogue,
      movementType: movementType ?? this.movementType,
      movementRange: movementRange ?? this.movementRange,
    );
  }
}
