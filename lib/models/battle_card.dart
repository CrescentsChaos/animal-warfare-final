import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BattleCard {
  final String id;
  final String name;
  final String description;
  final String imagePath;
  final String? requiredOrganism;
  final String? requiredFamily;
  final List<String> requiredBiomes;

  BattleCard({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    this.requiredOrganism,
    this.requiredFamily,
    required this.requiredBiomes,
  });

  factory BattleCard.fromJson(Map<String, dynamic> json) {
    return BattleCard(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String,
      requiredOrganism: json['requiredOrganism'] as String?,
      requiredFamily: json['requiredFamily'] as String?,
      requiredBiomes: (json['requiredBiomes'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'requiredOrganism': requiredOrganism,
      'requiredFamily': requiredFamily,
      'requiredBiomes': requiredBiomes,
    };
  }

  static List<BattleCard> _allCards = [];

  static Future<void> loadCards() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/cards.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _allCards = jsonList.map((json) => BattleCard.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading cards: $e');
      _allCards = [];
    }
  }

  static List<BattleCard> get allCards => _allCards;

  static BattleCard? findById(String id) {
    try {
      return _allCards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }
}
