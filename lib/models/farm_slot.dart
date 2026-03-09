// lib/models/farm_slot.dart

enum PlantStage { empty, seed, sprout, flower, fruit }

class FarmSlot {
  final int index;
  final String? plantType;
  final PlantStage stage;
  final DateTime? lastStageTime;
  final bool isWatered;
  final bool isFertilized;

  FarmSlot({
    required this.index,
    this.plantType,
    this.stage = PlantStage.empty,
    this.lastStageTime,
    this.isWatered = false,
    this.isFertilized = false,
  });

  /// Factory constructor to create a completely empty farmland slot
  factory FarmSlot.empty(int index) {
    return FarmSlot(index: index);
  }

  FarmSlot copyWith({
    int? index,
    String? plantType,
    PlantStage? stage,
    DateTime? lastStageTime,
    bool? isWatered,
    bool? isFertilized,
    bool clearPlantType = false,
  }) {
    return FarmSlot(
      index: index ?? this.index,
      plantType: clearPlantType ? null : (plantType ?? this.plantType),
      stage: stage ?? this.stage,
      lastStageTime: lastStageTime ?? this.lastStageTime,
      isWatered: isWatered ?? this.isWatered,
      isFertilized: isFertilized ?? this.isFertilized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'plantType': plantType,
      'stage': stage.index,
      'lastStageTime': lastStageTime?.toIso8601String(),
      'isWatered': isWatered,
      'isFertilized': isFertilized,
    };
  }

  factory FarmSlot.fromJson(Map<String, dynamic> json) {
    return FarmSlot(
      index: json['index'] as int? ?? 0,
      plantType: json['plantType'] as String?,
      stage: PlantStage.values[(json['stage'] as int?) ?? 0],
      lastStageTime: json['lastStageTime'] != null
          ? DateTime.tryParse(json['lastStageTime'] as String)
          : null,
      isWatered: json['isWatered'] as bool? ?? false,
      isFertilized: json['isFertilized'] as bool? ?? false,
    );
  }
}
