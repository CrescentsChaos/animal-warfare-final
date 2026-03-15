import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';

class SavedSpriteState {
  final String pheno;
  final double x;
  final double y;
  final int health; // or some basic stats if we want to retain damage, but we have CapturedOrganism
  
  // Actually, we can just save the CapturedOrganism so we retain all its stats
  final CapturedOrganism organism;

  SavedSpriteState({
    required this.pheno,
    required this.x,
    required this.y,
    this.health = 100,
    required this.organism,
  });

  Map<String, dynamic> toJson() => {
    'pheno': pheno,
    'x': x,
    'y': y,
    'organism': organism.toJson(),
  };

  factory SavedSpriteState.fromJson(Map<String, dynamic> json, List<Organism> allOrganisms) {
    Organism? findBaseOrganism(String name) {
      try {
        return allOrganisms.firstWhere((org) => org.name == name);
      } catch (_) {
        return null;
      }
    }
    
    final orgJson = json['organism'];
    CapturedOrganism? capturedOrg;
    if (orgJson != null) {
      final name = orgJson['name'] as String?;
      if (name != null) {
        final base = findBaseOrganism(name);
        if (base != null) {
          capturedOrg = CapturedOrganism.fromJson(orgJson, [base]);
        }
      }
    }

    return SavedSpriteState(
      pheno: json['pheno'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      organism: capturedOrg ?? CapturedOrganism.spawn(allOrganisms.first, level: 1), // Fallback
    );
  }
}

class SavedMapState {
  final double playerX;
  final double playerY;
  final String playerDirection;
  final List<SavedSpriteState> savedSprites;

  // We optionally save the whole map grid here if it was procedural
  // but for now let's just save the layout strings if it's dynamic
  final List<String>? customBaseLayout;
  final List<String>? customOverlayLayout;

  SavedMapState({
    required this.playerX,
    required this.playerY,
    required this.playerDirection,
    required this.savedSprites,
    this.customBaseLayout,
    this.customOverlayLayout,
  });

  Map<String, dynamic> toJson() => {
    'playerX': playerX,
    'playerY': playerY,
    'playerDirection': playerDirection,
    'savedSprites': savedSprites.map((s) => s.toJson()).toList(),
    'customBaseLayout': customBaseLayout,
    'customOverlayLayout': customOverlayLayout,
  };

  factory SavedMapState.fromJson(Map<String, dynamic> json, List<Organism> allOrganisms) {
    return SavedMapState(
      playerX: (json['playerX'] as num).toDouble(),
      playerY: (json['playerY'] as num).toDouble(),
      playerDirection: json['playerDirection'] as String? ?? 'down',
      savedSprites: (json['savedSprites'] as List?)
          ?.map((e) => SavedSpriteState.fromJson(e, allOrganisms))
          .toList() ?? [],
      customBaseLayout: (json['customBaseLayout'] as List?)?.map((e) => e as String).toList(),
      customOverlayLayout: (json['customOverlayLayout'] as List?)?.map((e) => e as String).toList(),
    );
  }
}
