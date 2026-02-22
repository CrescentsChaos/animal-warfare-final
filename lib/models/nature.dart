// lib/models/nature.dart
import 'dart:math';

enum NatureStat { attack, defense, power, resistance, speed, none }

class Nature {
  final String name;
  final NatureStat increasedStat;
  final NatureStat decreasedStat;

  const Nature({
    required this.name,
    required this.increasedStat,
    required this.decreasedStat,
  });

  double getMultiplier(String statName) {
    if (increasedStat == decreasedStat) return 1.0;

    final normalizedStat = statName.toLowerCase();
    if (normalizedStat == increasedStat.name) return 1.1;
    if (normalizedStat == decreasedStat.name) return 0.9;

    return 1.0;
  }

  static const List<Nature> allNatures = [
    // Neutral
    Nature(
      name: 'Hardy',
      increasedStat: NatureStat.attack,
      decreasedStat: NatureStat.attack,
    ),
    Nature(
      name: 'Docile',
      increasedStat: NatureStat.defense,
      decreasedStat: NatureStat.defense,
    ),
    Nature(
      name: 'Serious',
      increasedStat: NatureStat.speed,
      decreasedStat: NatureStat.speed,
    ),
    Nature(
      name: 'Bashful',
      increasedStat: NatureStat.power,
      decreasedStat: NatureStat.power,
    ),
    Nature(
      name: 'Quirky',
      increasedStat: NatureStat.resistance,
      decreasedStat: NatureStat.resistance,
    ),

    // +Attack
    Nature(
      name: 'Lonely',
      increasedStat: NatureStat.attack,
      decreasedStat: NatureStat.defense,
    ),
    Nature(
      name: 'Adamant',
      increasedStat: NatureStat.attack,
      decreasedStat: NatureStat.power,
    ),
    Nature(
      name: 'Naughty',
      increasedStat: NatureStat.attack,
      decreasedStat: NatureStat.resistance,
    ),
    Nature(
      name: 'Brave',
      increasedStat: NatureStat.attack,
      decreasedStat: NatureStat.speed,
    ),

    // +Defense
    Nature(
      name: 'Bold',
      increasedStat: NatureStat.defense,
      decreasedStat: NatureStat.attack,
    ),
    Nature(
      name: 'Impish',
      increasedStat: NatureStat.defense,
      decreasedStat: NatureStat.power,
    ),
    Nature(
      name: 'Lax',
      increasedStat: NatureStat.defense,
      decreasedStat: NatureStat.resistance,
    ),
    Nature(
      name: 'Relaxed',
      increasedStat: NatureStat.defense,
      decreasedStat: NatureStat.speed,
    ),

    // +Power (SpAtk)
    Nature(
      name: 'Modest',
      increasedStat: NatureStat.power,
      decreasedStat: NatureStat.attack,
    ),
    Nature(
      name: 'Mild',
      increasedStat: NatureStat.power,
      decreasedStat: NatureStat.defense,
    ),
    Nature(
      name: 'Rash',
      increasedStat: NatureStat.power,
      decreasedStat: NatureStat.resistance,
    ),
    Nature(
      name: 'Quiet',
      increasedStat: NatureStat.power,
      decreasedStat: NatureStat.speed,
    ),

    // +Resistance (SpDef)
    Nature(
      name: 'Calm',
      increasedStat: NatureStat.resistance,
      decreasedStat: NatureStat.attack,
    ),
    Nature(
      name: 'Gentle',
      increasedStat: NatureStat.resistance,
      decreasedStat: NatureStat.defense,
    ),
    Nature(
      name: 'Careful',
      increasedStat: NatureStat.resistance,
      decreasedStat: NatureStat.power,
    ),
    Nature(
      name: 'Sassy',
      increasedStat: NatureStat.resistance,
      decreasedStat: NatureStat.speed,
    ),

    // +Speed
    Nature(
      name: 'Timid',
      increasedStat: NatureStat.speed,
      decreasedStat: NatureStat.attack,
    ),
    Nature(
      name: 'Hasty',
      increasedStat: NatureStat.speed,
      decreasedStat: NatureStat.defense,
    ),
    Nature(
      name: 'Jolly',
      increasedStat: NatureStat.speed,
      decreasedStat: NatureStat.power,
    ),
    Nature(
      name: 'Naive',
      increasedStat: NatureStat.speed,
      decreasedStat: NatureStat.resistance,
    ),
  ];

  static const List<Nature> _allNaturesList = allNatures;

  static final Map<String, Nature> _byName = {
    for (final n in _allNaturesList) n.name.toLowerCase(): n,
  };

  static Nature findByName(String name) {
    return _byName[name.toLowerCase()] ??
        _allNaturesList[0]; // Default to Hardy
  }

  static Nature getRandom() {
    return _allNaturesList[Random().nextInt(_allNaturesList.length)];
  }
}
