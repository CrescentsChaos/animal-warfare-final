// lib/game/archetype_teams.dart
//
// Fully DYNAMIC archetype team builder.
// Each call picks an archetype (or chaos), scans the full organism pool,
// scores candidates by archetype fitness, picks the best 5, selects
// contextually correct moves, orders the lead, and returns a ready team.
//
// Zero hardcoded animal references — everything is runtime.

import 'dart:math';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/elemental_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result container
// ─────────────────────────────────────────────────────────────────────────────

class ArchetypeResult {
  final TeamArchetype? archetype; // null = chaos
  final String archetypeName;
  final List<CapturedOrganism> team; // ordered, lead first

  const ArchetypeResult({
    required this.archetype,
    required this.archetypeName,
    required this.team,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main builder
// ─────────────────────────────────────────────────────────────────────────────

class ArchetypeTeamBuilder {
  static final _rng = Random();

  /// Build a dynamic opponent team from [allOrganisms].
  /// Randomly chooses an archetype (or chaos), then assembles a legal 5-mon team.
  static ArchetypeResult build(
    List<Organism> allOrganisms, {
    bool allowChaos = true,
    bool withTalismans = true,
    int level = 50,
    int teamSize = 5,
    int minIV = 24,
    String? preferredClass,
    String? preferredType,
  }) {
    if (allOrganisms.isEmpty) {
      return const ArchetypeResult(
        archetype: null,
        archetypeName: 'Chaos',
        team: [],
      );
    }

    // 30% chance for chaos (fully random team), 70% for an archetype
    final chaosCutoff = allowChaos ? 0.30 : 0.0;
    if (_rng.nextDouble() < chaosCutoff) {
      // Filter out God-Tier organisms (test entries with 999 stats)
      final normalPool = allOrganisms.where((o) => !_isGodTier(o)).toList();
      var pool = normalPool.where((o) {
        if (preferredClass != null && o.animalClass.toLowerCase() != preferredClass.toLowerCase()) return false;
        if (preferredType != null && !o.types.map((t) => t.toLowerCase()).contains(preferredType.toLowerCase())) return false;
        return true;
      }).toList();
      if (pool.isEmpty) pool = normalPool;
      
      final team = buildChaos(
        pool.isEmpty ? allOrganisms : pool,
        withTalismans: withTalismans,
        level: level,
        teamSize: teamSize,
        minIV: minIV,
      );
      return ArchetypeResult(
        archetype: null,
        archetypeName: 'Chaos',
        team: team,
      );
    }

    // Pick a random archetype
    final archetypes = TeamArchetype.values;
    final archetype = archetypes[_rng.nextInt(archetypes.length)];

    var pool = allOrganisms.where((o) {
      if (preferredClass != null && o.animalClass.toLowerCase() != preferredClass.toLowerCase()) return false;
      if (preferredType != null && !o.types.map((t) => t.toLowerCase()).contains(preferredType.toLowerCase())) return false;
      return true;
    }).toList();
    if (pool.isEmpty) pool = allOrganisms;

    final team = buildForArchetype(
      archetype,
      pool,
      withTalismans: withTalismans,
      level: level,
      teamSize: teamSize,
      minIV: minIV,
    );

    return ArchetypeResult(
      archetype: archetype,
      archetypeName: _name(archetype),
      team: team,
    );
  }

  // ───────────────────────────────────────────────
  // Chaos mode — pure random, no archetype logic
  // ───────────────────────────────────────────────
  static List<CapturedOrganism> buildChaos(
    List<Organism> allOrganisms, {
    bool withTalismans = true,
    int level = 50,
    int teamSize = 5,
    int minIV = 24,
  }) {
    final shuffled = List.of(allOrganisms)..shuffle(_rng);
    final picked = shuffled.take(teamSize).toList();

    final team = picked.map((o) {
      final cand = _OrgCandidate(o, _resolveMovelist(o));

      // Rare chance to apply a specialized build even in Chaos mode
      final special = _tryApplySpecialBuild(null, cand, level, minIV);
      if (special != null) {
        return withTalismans ? _assignTalisman(null, special) : special;
      }

      final moves = (List.of(cand.moves)..shuffle(_rng)).take(4).toList();
      final ability = _selectAbility(null, o, moves);
      final c = _makeOrganism(
        o,
        moves,
        level: level,
        minIV: minIV,
        activeAbilityName: ability,
      );
      return withTalismans ? _assignTalisman(null, c) : c;
    }).toList();

    return team;
  }

  // ───────────────────────────────────────────────
  // Archetype-driven team build
  // ───────────────────────────────────────────────
  static List<CapturedOrganism> buildForArchetype(
    TeamArchetype archetype,
    List<Organism> allOrganisms, {
    bool withTalismans = true,
    int level = 50,
    int teamSize = 5,
    int minIV = 24,
  }) {
    // 1. Resolve moves for every organism (we need them for scoring)
    final candidates = allOrganisms
        .map((o) => _OrgCandidate(o, _resolveMovelist(o)))
        .toList();

    // 2. Filter by archetype fitness, fall back to full pool if too narrow
    var eligible = candidates.where((c) => _filter(archetype, c)).toList();
    if (eligible.length < teamSize) eligible = candidates; // fallback

    // 3. Score candidates by archetype fit for weighted selection
    final scoredEligible = eligible.map((c) {
      double s = _score(archetype, c);
      // Add a significant amount of jitter to ensure we don't always pick the same "top" animals
      s += _rng.nextDouble() * (s * 0.4); // 40% jitter based on score
      if (s <= 0) s = 1; // base weight for any eligible animal
      return MapEntry(c, s);
    }).toList();

    // 4. Pick randomly using weights to ensure variety while favoring better fits
    final picked = <_OrgCandidate>[];
    for (int i = 0; i < teamSize && scoredEligible.isNotEmpty; i++) {
      double totalWeight = scoredEligible.fold(0.0, (sum, e) => sum + e.value);
      double r = _rng.nextDouble() * totalWeight;

      for (int j = 0; j < scoredEligible.length; j++) {
        r -= scoredEligible[j].value;
        if (r <= 0) {
          picked.add(scoredEligible[j].key);
          scoredEligible.removeAt(j);
          break;
        }
      }
    }

    // 5. Build CapturedOrganisms with archetype-tuned movesets
    final teamMoves = <String>[];
    var team = picked.map((c) {
      // Rare chance to apply a specialized build if the animal fits
      final special = _tryApplySpecialBuild(archetype, c, level, minIV);
      if (special != null) {
        teamMoves.addAll(special.selectedMoveNames);
        return withTalismans ? _assignTalisman(archetype, special) : special;
      }

      final moves = _selectMoves(archetype, c, teamMoves);
      teamMoves.addAll(moves.map((m) => m.name));

      final ability = _selectAbility(archetype, c.organism, moves);

      final captured = _makeOrganism(
        c.organism,
        moves,
        level: level,
        minIV: minIV,
        activeAbilityName: ability,
      );
      return withTalismans ? _assignTalisman(archetype, captured) : captured;
    }).toList();

    // 6. Order the lead
    team = _orderLead(archetype, team);

    return team;
  }

  /// Specialized Build Engine:
  /// Identifies if a candidate fits a unique "style" and applies it.
  static CapturedOrganism? _tryApplySpecialBuild(
    TeamArchetype? archetype,
    _OrgCandidate c,
    int level,
    int minIV,
  ) {
    // 30% chance to even attempt a special build for an eligible animal
    if (_rng.nextDouble() > 0.3) return null;

    final availableBuilds = SpecialBuilds.all
        .where((b) => b.fitness(c.organism, c.moves))
        .toList();
    if (availableBuilds.isEmpty) return null;

    final build = availableBuilds[_rng.nextInt(availableBuilds.length)];

    // Force required ability
    final ability = build.requiredAbility;

    // Resolve moves: start with required moves
    final moves = <Move>[];
    for (final mName in build.requiredMoves) {
      final m = Move.findByName(mName);
      if (m != null) moves.add(m);
    }

    // Style-specific heuristics:
    if (build.name == 'Skill Link Multi-Hit') {
      final multiHits = c.moves.where((m) => m.maxHits > 1).toList();
      moves.addAll(multiHits);
    }
    if (build.name == 'No Guard Accuracy-Fixer') {
      final inaccurate = c.moves
          .where((m) => m.accuracy < 85 && m.baseDamage > 0)
          .toList();
      moves.addAll(inaccurate);
    }

    // Fill remaining slots from the general pool
    if (moves.length < 4) {
      final remaining = c.moves.where((m) => !moves.contains(m)).toList();
      // Prefer high power for the remaining slots
      remaining.sort((a, b) => b.baseDamage.compareTo(a.baseDamage));
      moves.addAll(remaining.take(4 - moves.length));
    }

    final captured = _makeOrganism(
      c.organism,
      moves.take(4).toList(),
      level: level,
      minIV: minIV,
      activeAbilityName: ability,
    );

    // Apply build-specific talisman if defined
    if (build.requiredTalisman != null) {
      final t = Talisman.findByName(build.requiredTalisman!);
      if (t != null) {
        return captured.copyWith(equippedTalisman: t);
      }
    }

    return captured;
  }

  // ─────────────────────────────────────────────────────────────────
  // Archetype: Filter — must an organism be eligible at all?
  // ─────────────────────────────────────────────────────────────────
  static bool _filter(TeamArchetype archetype, _OrgCandidate c) {
    final o = c.organism;

    // Global: Exclude God-Tier organisms (test entries with 999 stats)
    if (_isGodTier(o)) return false;

    switch (archetype) {
      case TeamArchetype.hyperOffense:
        return (o.attack + o.speed > 160) || o.speed > 90;

      case TeamArchetype.stall:
        return (o.defense + o.resistance > 150) || o.health > 100;

      case TeamArchetype.balanced:
        return true; // No filter — any animal can be balanced

      case TeamArchetype.statusSpread:
        return c.moves.any(
          (m) => m.effects.any(
            (e) =>
                e.type == MoveEffectType.statusPoison ||
                e.type == MoveEffectType.statusBurn ||
                e.type == MoveEffectType.statusParalysis ||
                e.type == MoveEffectType.statusBleed ||
                e.type == MoveEffectType.statusStun,
          ),
        );

      case TeamArchetype.rainTeam:
        return _isRainSetter(c) ||
            o.elementalTypes.contains(ElementalType.aquatic) ||
            _hasRainAbility(o);

      case TeamArchetype.sunTeam:
        return _isSunSetter(c) ||
            o.elementalTypes.contains(ElementalType.blaze) ||
            _hasSunAbility(o);

      case TeamArchetype.sandTeam:
        return _isSandSetter(c) ||
            o.elementalTypes.contains(ElementalType.rock) ||
            o.elementalTypes.contains(ElementalType.metal) ||
            o.elementalTypes.contains(ElementalType.earth) ||
            _hasSandAbility(o);

      case TeamArchetype.snowTeam:
        return _isSnowSetter(c) ||
            o.elementalTypes.contains(ElementalType.cryo) ||
            _hasSnowAbility(o);

      case TeamArchetype.psychicTerrainAbuser:
        return _isPsychicTerrainSetter(c) ||
            o.elementalTypes.contains(ElementalType.aura) ||
            _hasPsychicTerrainAbility(o);

      case TeamArchetype.electricTerrainAbuser:
        return _isElectricTerrainSetter(c) ||
            o.elementalTypes.contains(ElementalType.electric) ||
            _hasElectricTerrainAbility(o);

      case TeamArchetype.hazardStacker:
        // Allow hazard setters AND hazard abusers (Roar, Whirlwind, forced-switch moves)
        return c.moves.any(
              (m) => m.effects.any((e) => e.type == MoveEffectType.setHazard),
            ) ||
            c.moves.any(
              (m) =>
                  m.name == 'Roar' ||
                  m.name == 'Whirlwind' ||
                  m.name == 'Dragon Tail' ||
                  m.name == 'Circle Throw',
            ) ||
            true; // All can participate — hazard abusers just need decent bulk

      case TeamArchetype.antiHazard:
        return c.moves.any(
          (m) =>
              m.name == 'Rapid Spin' ||
              m.name == 'Defog' ||
              m.name == 'Mortal Spin',
        );

      case TeamArchetype.revengeKiller:
        return o.speed > 80;

      case TeamArchetype.defensiveCore:
        return o.defense > 80 || o.resistance > 80;

      case TeamArchetype.setupSweeper:
        return c.moves.any(
          (m) => m.effects.any(
            (e) =>
                e.type == MoveEffectType.statChange &&
                e.target == 'self' &&
                (e.stat == 'attack' || e.stat == 'power' || e.stat == 'speed'),
          ),
        );

      case TeamArchetype.trickRoom:
        // Must be either a TR setter (has Trick Room move) or a slow heavy hitter
        final hasTR = c.moves.any((m) => m.name == 'Trick Room');
        final isSlowHeavy = o.speed < 55 && (o.attack > 90 || o.power > 90);
        return hasTR || isSlowHeavy;

      case TeamArchetype.tailwindSpeed:
        return c.moves.any((m) => m.name == 'Tailwind') || o.speed > 100;

      case TeamArchetype.dualScreens:
        return c.moves.any(
              (m) =>
                  m.name == 'Reflect' ||
                  m.name == 'Light Screen' ||
                  m.name == 'Aurora Veil',
            ) ||
            (o.defense > 80 && o.resistance > 80);

      case TeamArchetype.prioritySweeper:
        return c.moves.any((m) => m.priority > 0 && m.baseDamage > 0);

      case TeamArchetype.perishTrapper:
        return c.moves.any((m) => m.name == 'Perish Song') ||
            c.moves.any(
              (m) => m.effects.any((e) => e.type == MoveEffectType.trapIndices),
            );

      case TeamArchetype.gimmickyAssist:
        return c.moves.any(
          (m) =>
              m.name == 'Metronome' ||
              m.name == 'Assist' ||
              m.name == 'Copycat',
        );

      case TeamArchetype.criticalFocus:
        return c.moves.any((m) => m.critRate > 0 || m.name == 'Focus Energy');

      case TeamArchetype.recoilReckless:
        return c.moves.any((m) => m.recoilPercent > 0);

      case TeamArchetype.restLoop:
        return c.moves.any((m) => m.name == 'Rest') &&
            c.moves.any((m) => m.name == 'Sleep Talk' || m.name == 'Snore');

      case TeamArchetype.evasionBuffer:
        return c.moves.any(
          (m) => m.name == 'Double Team' || m.name == 'Minimize',
        );

      case TeamArchetype.bulkyBruiser:
        return o.health > 110 && (o.attack > 100 || o.power > 100);

      case TeamArchetype.toxicStall:
        return c.moves.any((m) => m.name == 'Toxic') &&
            c.moves.any((m) => m.name == 'Protect' || m.name == 'Spiky Shield');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Archetype: Score — how well does this organism fit the archetype?
  // ─────────────────────────────────────────────────────────────────
  static double _score(TeamArchetype archetype, _OrgCandidate c) {
    final o = c.organism;
    switch (archetype) {
      case TeamArchetype.hyperOffense:
        return (o.attack + o.speed).toDouble();

      case TeamArchetype.stall:
        return (o.health + o.defense + o.resistance).toDouble();

      case TeamArchetype.balanced:
        // Prefer animals where no single stat dominates wildly
        final stats = [
          o.attack,
          o.defense,
          o.health,
          o.speed,
          o.resistance,
          o.power,
        ];
        final mx = stats.reduce(max).toDouble();
        final mn = stats.reduce(min).toDouble();
        final total = stats.reduce((a, b) => a + b).toDouble();
        // Lower spread = more balanced; score by total but penalise extremes
        return total - (mx - mn);

      case TeamArchetype.statusSpread:
        return c.moves
            .where(
              (m) => m.effects.any(
                (e) =>
                    e.type == MoveEffectType.statusPoison ||
                    e.type == MoveEffectType.statusBurn ||
                    e.type == MoveEffectType.statusParalysis ||
                    e.type == MoveEffectType.statusBleed ||
                    e.type == MoveEffectType.statusStun,
              ),
            )
            .length
            .toDouble();

      case TeamArchetype.rainTeam:
        double s = (o.attack + o.power).toDouble();
        if (_isRainSetter(c)) s += 500;
        if (o.elementalTypes.contains(ElementalType.aquatic)) s += 50;
        if (_hasRainAbility(o)) s += 100;
        return s;

      case TeamArchetype.psychicTerrainAbuser:
        double s = (o.attack + o.power).toDouble();
        if (_isPsychicTerrainSetter(c)) s += 500;
        if (o.elementalTypes.contains(ElementalType.aura)) s += 50;
        return s;

      case TeamArchetype.electricTerrainAbuser:
        double s = (o.attack + o.power).toDouble();
        if (_isElectricTerrainSetter(c)) s += 500;
        if (o.elementalTypes.contains(ElementalType.electric)) s += 50;
        return s;

      case TeamArchetype.sunTeam:
        double s = (o.attack + o.power).toDouble();
        if (_isSunSetter(c)) s += 500;
        if (o.elementalTypes.contains(ElementalType.blaze)) s += 50;
        if (_hasSunAbility(o)) s += 100;
        return s;

      case TeamArchetype.sandTeam:
        double s = (o.attack + o.power + o.defense).toDouble();
        if (_isSandSetter(c)) s += 500;
        if (o.elementalTypes.contains(ElementalType.rock)) s += 50;
        if (_hasSandAbility(o)) s += 100;
        return s;

      case TeamArchetype.snowTeam:
        double s = (o.attack + o.power).toDouble();
        if (_isSnowSetter(c)) s += 500;
        if (o.elementalTypes.contains(ElementalType.cryo)) s += 50;
        if (_hasSnowAbility(o)) s += 100;
        return s;

      case TeamArchetype.hazardStacker:
        // Score hazard-setters very highly; hazard abusers score by phazing+bulk
        final hazardCount = c.moves
            .where(
              (m) => m.effects.any((e) => e.type == MoveEffectType.setHazard),
            )
            .length;
        final isAbuserRole = hazardCount == 0;
        if (isAbuserRole) {
          // Hazard abuser: fast phazer or bulky switch-forcer
          final hasPhazer = c.moves.any(
            (m) =>
                m.name == 'Roar' ||
                m.name == 'Whirlwind' ||
                m.name == 'Dragon Tail' ||
                m.name == 'Circle Throw',
          );
          return (hasPhazer ? 300 : 0) + o.defense.toDouble();
        }
        return (hazardCount * 500 + o.defense).toDouble();

      case TeamArchetype.antiHazard:
        final hasSpinner = c.moves.any(
          (m) =>
              m.name == 'Rapid Spin' ||
              m.name == 'Defog' ||
              m.name == 'Mortal Spin',
        );
        return hasSpinner ? (1000 + o.speed).toDouble() : o.speed.toDouble();

      case TeamArchetype.revengeKiller:
        return (o.speed + o.attack).toDouble();

      case TeamArchetype.defensiveCore:
        // Prize high Defense for Body Press-style attackers
        return (o.health + o.defense * 2 + o.resistance).toDouble();

      case TeamArchetype.setupSweeper:
        // Setup user potential = setup move + high offensive stat + speed
        final hasSetup = c.moves.any(
          (m) => m.effects.any(
            (e) =>
                e.type == MoveEffectType.statChange &&
                e.target == 'self' &&
                (e.stat == 'attack' || e.stat == 'power' || e.stat == 'speed'),
          ),
        );
        return ((hasSetup ? 500 : 0) + o.attack + o.speed).toDouble();

      case TeamArchetype.trickRoom:
        final hasTR = c.moves.any((m) => m.name == 'Trick Room');
        // TR setter bonus; slow attackers score by inverse speed + bulk
        final speedPenalty = (100 - o.speed).clamp(0, 100).toDouble();
        return ((hasTR ? 800 : 0) + speedPenalty + o.attack + o.health)
            .toDouble();

      case TeamArchetype.tailwindSpeed:
        final hasTW = c.moves.any((m) => m.name == 'Tailwind');
        return ((hasTW ? 1000 : 0) + o.speed + o.attack).toDouble();

      case TeamArchetype.dualScreens:
        final hasScreens = c.moves.any(
          (m) => m.name == 'Reflect' || m.name == 'Light Screen',
        );
        return ((hasScreens ? 800 : 0) + o.defense + o.resistance + o.health)
            .toDouble();

      case TeamArchetype.prioritySweeper:
        final priorityCount = c.moves.where((m) => m.priority > 0).length;
        return (priorityCount * 200 + o.attack).toDouble();

      case TeamArchetype.perishTrapper:
        final hasPerish = c.moves.any((m) => m.name == 'Perish Song');
        final hasTrap = c.moves.any(
          (m) => m.effects.any((e) => e.type == MoveEffectType.trapIndices),
        );
        return ((hasPerish ? 600 : 0) +
                (hasTrap ? 600 : 0) +
                o.defense +
                o.health)
            .toDouble();

      case TeamArchetype.gimmickyAssist:
        return 500; // Almost any animal is fine, just high base score

      case TeamArchetype.criticalFocus:
        final critCount = c.moves.where((m) => m.critRate > 0).length;
        final hasFocus = c.moves.any((m) => m.name == 'Focus Energy');
        return (critCount * 300 + (hasFocus ? 500 : 0) + o.speed).toDouble();

      case TeamArchetype.recoilReckless:
        final recoilCount = c.moves.where((m) => m.recoilPercent > 0).length;
        return (recoilCount * 400 + o.attack).toDouble();

      case TeamArchetype.restLoop:
        final hasRest = c.moves.any((m) => m.name == 'Rest');
        final hasTalk = c.moves.any((m) => m.name == 'Sleep Talk');
        return ((hasRest ? 500 : 0) +
                (hasTalk ? 500 : 0) +
                o.defense +
                o.resistance)
            .toDouble();

      case TeamArchetype.evasionBuffer:
        final evasionCount = c.moves
            .where((m) => m.name == 'Double Team' || m.name == 'Minimize')
            .length;
        return (evasionCount * 600 + o.speed + o.defense).toDouble();

      case TeamArchetype.bulkyBruiser:
        return (o.health * 1.5 + o.attack + o.power).toDouble();

      case TeamArchetype.toxicStall:
        final hasToxic = c.moves.any((m) => m.name == 'Toxic');
        final hasProtect = c.moves.any(
          (m) => m.name == 'Protect' || m.name == 'Spiky Shield',
        );
        return ((hasToxic ? 700 : 0) +
                (hasProtect ? 500 : 0) +
                o.health +
                o.defense)
            .toDouble();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Move Selection — pick best 4 moves per archetype
  // ─────────────────────────────────────────────────────────────────
  static List<Move> _selectMoves(
    TeamArchetype archetype,
    _OrgCandidate c,
    List<String> teamMoves,
  ) {
    final pool = c.moves;
    if (pool.isEmpty) return [];

    // Score each move by archetype priority + team diversity
    final scored = pool.map((m) {
      double baseScore = _scoreMove(archetype, m);

      // Penalize moves already heavily present on the team
      final teamCount = teamMoves.where((name) => name == m.name).length;
      if (teamCount > 0) {
        // High penalty for repeating moves across the team,
        // unless it's an archetype that benefits from it (like Stall/Protect).
        double penalty = 150.0 * teamCount;
        if (archetype == TeamArchetype.stall && _isProtect(m)) penalty *= 0.3;
        if (archetype == TeamArchetype.hazardStacker &&
            m.effects.any((e) => e.type == MoveEffectType.setHazard)) {
          penalty *= 0.5;
        }

        baseScore -= penalty;
      }

      // Add a healthy amount of jitter to ensure different runs pick different moves
      baseScore += _rng.nextDouble() * 40.0;

      return MapEntry(m, baseScore);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    // Selection strategy: Pick top 2 most strategic moves, then weighted random for the rest
    final selected = <Move>[];

    // 1. Take the absolute best move first (Core strategy)
    if (scored.isNotEmpty) {
      selected.add(scored.removeAt(0).key);
    }

    // 2. Try to ensure a STAB move or high damage move
    if (scored.isNotEmpty) {
      final stabIndex = scored.indexWhere(
        (e) =>
            c.organism.elementalTypes.contains(e.key.type) &&
            e.key.baseDamage > 0,
      );
      if (stabIndex != -1) {
        selected.add(scored.removeAt(stabIndex).key);
      } else {
        selected.add(scored.removeAt(0).key);
      }
    }

    // 3. Fill remaining slots with weighted sampling from the top 6 remaining
    while (selected.length < 4 && scored.isNotEmpty) {
      final options = scored.take(6).toList();
      double totalWeight = 0;
      for (var i = 0; i < options.length; i++) {
        // Weight is (score + offset) to ensure even lower scores have a small chance
        double weight = max(10, options[i].value + 500);
        totalWeight += weight;
      }

      double r = _rng.nextDouble() * totalWeight;
      int pickedIndex = 0;
      for (int i = 0; i < options.length; i++) {
        double weight = max(10, options[i].value + 500);
        r -= weight;
        if (r <= 0) {
          pickedIndex = i;
          break;
        }
      }

      final picked = options[pickedIndex].key;
      selected.add(picked);
      scored.removeWhere((e) => e.key == picked);
    }

    // Fallback: if no damaging move included, swap last slot for one
    if (selected.every((m) => m.baseDamage == 0)) {
      final damager = pool.where((m) => m.baseDamage > 0).toList();
      if (damager.isNotEmpty && selected.isNotEmpty) {
        selected[selected.length - 1] = damager.reduce(
          (a, b) => a.baseDamage > b.baseDamage ? a : b,
        );
      }
    }

    return selected;
  }

  static double _scoreMove(TeamArchetype archetype, Move m) {
    double s = 0;

    // Base quality — always prefer reliable, accurate moves
    s += (m.accuracy / 100.0) * 10;
    s += m.baseDamage * 0.3;

    switch (archetype) {
      case TeamArchetype.hyperOffense:
        s += m.baseDamage * 2;
        if (m.category == MoveCategory.status) s -= 200;
        if (m.priority > 0) s += 30;
        break;

      case TeamArchetype.stall:
        if (_isProtect(m)) s += 300;
        if (_isStatusInflicting(m)) s += 200;
        if (_isHeal(m)) s += 180;
        if (m.baseDamage > 70) s -= 40;
        break;

      case TeamArchetype.balanced:
        if (m.baseDamage > 0) s += 20;
        if (_isStatusInflicting(m)) s += 10;
        if (_isHeal(m)) s += 15;
        break;

      case TeamArchetype.rainTeam:
        if (m.effects.any((e) => e.stat == 'rain')) s += 800;
        if (m.type == ElementalType.aquatic) s += 100;
        if (m.name == 'Thunder' || m.name == 'Hurricane') s += 150;
        break;

      case TeamArchetype.sunTeam:
        if (m.effects.any((e) => e.stat == 'sun')) s += 800;
        if (m.type == ElementalType.blaze) s += 100;
        if (m.name == 'Solar Beam' || m.name == 'Solar Blade') s += 200;
        break;

      case TeamArchetype.sandTeam:
        if (m.effects.any((e) => e.stat == 'sandstorm')) s += 800;
        if (m.type == ElementalType.rock ||
            m.type == ElementalType.earth ||
            m.type == ElementalType.metal) {
          s += 40;
        }
        break;

      case TeamArchetype.snowTeam:
        if (m.effects.any((e) => e.stat == 'hail')) s += 800;
        if (m.type == ElementalType.cryo) s += 100;
        if (m.name == 'Blizzard') s += 150;
        if (m.name == 'Aurora Veil') s += 300;
        break;

      case TeamArchetype.psychicTerrainAbuser:
        if (m.effects.any((e) => e.stat == 'psychic')) s += 800;
        if (m.type == ElementalType.aura) s += 100;
        if (m.name == 'Psychic' ||
            m.name == 'Psyshock' ||
            m.name == 'Expanding Force') {
          s += 150;
        }
        break;

      case TeamArchetype.electricTerrainAbuser:
        if (m.effects.any((e) => e.stat == 'electric')) s += 800;
        if (m.type == ElementalType.electric) s += 100;
        if (m.name == 'Thunderbolt' ||
            m.name == 'Thunder' ||
            m.name == 'Volt Switch') {
          s += 150;
        }
        break;

      case TeamArchetype.hazardStacker:
        // Hazard setters: prize every hazard move; then phazing; then damage
        if (m.effects.any((e) => e.type == MoveEffectType.setHazard)) s += 500;
        if (m.name == 'Roar' ||
            m.name == 'Whirlwind' ||
            m.name == 'Dragon Tail' ||
            m.name == 'Circle Throw') {
          s += 350; // hazard abuser core move
        }
        if (_isProtect(m)) s += 80;
        if (m.baseDamage > 60) s += 20;
        break;

      case TeamArchetype.antiHazard:
        if (m.name == 'Rapid Spin' ||
            m.name == 'Defog' ||
            m.name == 'Mortal Spin') {
          s += 500;
        }
        if (m.baseDamage > 60) s += 30;
        if (_isHeal(m)) s += 20;
        break;

      case TeamArchetype.revengeKiller:
        if (m.priority > 0) s += 200;
        s += m.baseDamage * 1.5;
        break;

      case TeamArchetype.defensiveCore:
        if (_isSelfStatBoost(m, ['defense', 'resistance'])) s += 250;
        if (_isHeal(m)) s += 200;
        // Body Press-style: high-base-damage status-category moves that scale with defense
        if (m.name == 'Body Press' || m.name == 'Heavy Slam') s += 200;
        // High-power slow moves are great for defensive cores
        if (m.baseDamage > 80 && m.accuracy >= 80) s += 60;
        if (m.recoilPercent > 0) s -= 100;
        break;

      case TeamArchetype.statusSpread:
        if (_isStatusInflicting(m)) s += 300;
        if (m.baseDamage > 0 && _isStatusInflicting(m)) {
          s += 50; // damage+status
        }
        // Hex gets massive bonus — doubles in power when target is statused
        if (m.name == 'Hex' ||
            m.name == 'Venoshock' ||
            m.name == 'Wake-Up Slap') {
          s += 250;
        }
        if (m.baseDamage > 60 && !_isStatusInflicting(m)) s += 10;
        break;

      case TeamArchetype.setupSweeper:
        if (_isSelfStatBoost(m, ['attack', 'power', 'speed'])) s += 400;
        if (m.baseDamage > 60) s += 50;
        if (m.category == MoveCategory.status &&
            !_isSelfStatBoost(m, ['attack', 'power', 'speed'])) {
          s -= 50;
        }
        break;

      case TeamArchetype.trickRoom:
        // Set Trick Room first; then slow heavy attackers spam high-base-power moves
        if (m.name == 'Trick Room') s += 900;
        if (m.baseDamage > 80) s += 80;
        if (m.baseDamage > 100) s += 60; // extra bonus for very high power
        // Iron-Defense-type boosts work great in TR
        if (_isSelfStatBoost(m, ['defense'])) s += 40;
        if (_isHeal(m)) s += 60;
        if (m.priority > 0) s -= 50; // priority is useless under TR
        break;

      case TeamArchetype.tailwindSpeed:
        if (m.name == 'Tailwind') s += 1000;
        if (m.baseDamage > 70) s += 50;
        break;

      case TeamArchetype.dualScreens:
        if (m.name == 'Reflect' ||
            m.name == 'Light Screen' ||
            m.name == 'Aurora Veil') {
          s += 800;
        }
        if (m.baseDamage > 0) s += 20;
        break;

      case TeamArchetype.prioritySweeper:
        if (m.priority > 0 && m.baseDamage > 0) s += 500;
        if (m.baseDamage > 80) s += 40;
        break;

      case TeamArchetype.perishTrapper:
        if (m.name == 'Perish Song') s += 1000;
        if (m.effects.any((e) => e.type == MoveEffectType.trapIndices)) {
          s += 800;
        }
        if (m.name == 'Protect') s += 200;
        break;

      case TeamArchetype.gimmickyAssist:
        if (m.name == 'Metronome' ||
            m.name == 'Assist' ||
            m.name == 'Copycat') {
          s += 1000;
        }
        break;

      case TeamArchetype.criticalFocus:
        if (m.critRate > 0) s += 400;
        if (m.name == 'Focus Energy') s += 800;
        if (m.baseDamage > 60) s += 30;
        break;

      case TeamArchetype.recoilReckless:
        if (m.recoilPercent > 0) s += 800;
        if (m.baseDamage > 100) s += 200;
        break;

      case TeamArchetype.restLoop:
        if (m.name == 'Rest' || m.name == 'Sleep Talk' || m.name == 'Snore') {
          s += 800;
        }
        break;

      case TeamArchetype.evasionBuffer:
        if (m.name == 'Double Team' || m.name == 'Minimize') s += 1000;
        break;

      case TeamArchetype.bulkyBruiser:
        if (m.baseDamage > 90) s += 100;
        if (m.priority > 0) s += 80;
        break;

      case TeamArchetype.toxicStall:
        if (m.name == 'Toxic') s += 1000;
        if (m.name == 'Protect' || m.name == 'Spiky Shield') s += 800;
        break;
    }

    return s;
  }

  // ─────────────────────────────────────────────────────────────────
  // Lead ordering
  // ─────────────────────────────────────────────────────────────────
  static List<CapturedOrganism> _orderLead(
    TeamArchetype archetype,
    List<CapturedOrganism> team,
  ) {
    if (team.isEmpty) return team;

    int leadIndex = 0;
    double bestScore = -double.infinity;

    for (int i = 0; i < team.length; i++) {
      final c = team[i];
      double s = _leadScore(archetype, c);
      // Lead Selection Jitter: helps avoid identical leads even if scores are close
      s += _rng.nextDouble() * 100;

      if (s > bestScore) {
        bestScore = s;
        leadIndex = i;
      }
    }

    if (leadIndex == 0) return team;
    final reordered = List.of(team);
    final lead = reordered.removeAt(leadIndex);
    reordered.insert(0, lead);
    return reordered;
  }

  static double _leadScore(TeamArchetype archetype, CapturedOrganism c) {
    switch (archetype) {
      case TeamArchetype.hyperOffense:
      case TeamArchetype.revengeKiller:
        return c.baseOrganism.speed.toDouble();

      case TeamArchetype.stall:
      case TeamArchetype.defensiveCore:
        return (c.baseOrganism.health + c.baseOrganism.defense).toDouble();

      case TeamArchetype.hazardStacker:
        // Lead with whoever has a hazard move
        final hasHazard = c.selectedMoveNames.any((name) {
          final m = Move.findByName(name);
          return m != null &&
              m.effects.any((e) => e.type == MoveEffectType.setHazard);
        });
        return hasHazard
            ? (1000 + c.baseOrganism.speed).toDouble()
            : c.baseOrganism.speed.toDouble();

      case TeamArchetype.antiHazard:
        // Lead with rapid spinner
        final hasSpinner = c.selectedMoveNames.any(
          (n) => n == 'Rapid Spin' || n == 'Defog' || n == 'Mortal Spin',
        );
        return hasSpinner ? 1000 : c.baseOrganism.speed.toDouble();

      case TeamArchetype.rainTeam:
        return _isRainSetter(_wrap(c)) ? 1000 : c.baseOrganism.speed.toDouble();
      case TeamArchetype.sunTeam:
        return _isSunSetter(_wrap(c)) ? 1000 : c.baseOrganism.speed.toDouble();
      case TeamArchetype.sandTeam:
        return _isSandSetter(_wrap(c)) ? 1000 : c.baseOrganism.speed.toDouble();
      case TeamArchetype.snowTeam:
        return _isSnowSetter(_wrap(c)) ? 1000 : c.baseOrganism.speed.toDouble();
      case TeamArchetype.psychicTerrainAbuser:
        return _isPsychicTerrainSetter(_wrap(c))
            ? 1000
            : c.baseOrganism.speed.toDouble();
      case TeamArchetype.electricTerrainAbuser:
        return _isElectricTerrainSetter(_wrap(c))
            ? 1000
            : c.baseOrganism.speed.toDouble();

      case TeamArchetype.trickRoom:
        // Lead with the TR setter
        final hasTR = c.selectedMoveNames.any((n) => n == 'Trick Room');
        return hasTR
            ? 2000
            : (100 - c.baseOrganism.speed).clamp(0, 100).toDouble();

      case TeamArchetype.setupSweeper:
        // Lead with setup move user
        final hasSetup = c.selectedMoveNames.any((name) {
          final m = Move.findByName(name);
          return m != null && _isSelfStatBoost(m, ['attack', 'power', 'speed']);
        });
        return hasSetup
            ? (1000 + c.baseOrganism.speed).toDouble()
            : c.baseOrganism.speed.toDouble();

      case TeamArchetype.statusSpread:
        // Lead with fastest status-spreader
        final hasStatus = c.selectedMoveNames.any((name) {
          final m = Move.findByName(name);
          return m != null && _isStatusInflicting(m);
        });
        return hasStatus
            ? (500 + c.baseOrganism.speed).toDouble()
            : c.baseOrganism.speed.toDouble();

      case TeamArchetype.balanced:
        return c.baseOrganism.speed.toDouble();

      case TeamArchetype.tailwindSpeed:
        return c.selectedMoveNames.contains('Tailwind')
            ? 1000
            : c.baseOrganism.speed.toDouble();

      case TeamArchetype.dualScreens:
        return (c.selectedMoveNames.contains('Reflect') ||
                c.selectedMoveNames.contains('Light Screen'))
            ? 1000
            : c.baseOrganism.defense.toDouble();

      case TeamArchetype.prioritySweeper:
        return c.baseOrganism.speed.toDouble();

      case TeamArchetype.perishTrapper:
        final canTrap = c.selectedMoveNames.any((n) {
          final m = Move.findByName(n);
          return m != null &&
              m.effects.any((e) => e.type == MoveEffectType.trapIndices);
        });
        return canTrap ? 1000 : c.baseOrganism.health.toDouble();

      case TeamArchetype.gimmickyAssist:
        return _rng.nextDouble() * 1000; // Complete random lead

      case TeamArchetype.criticalFocus:
        return c.selectedMoveNames.contains('Focus Energy')
            ? 1000
            : c.baseOrganism.speed.toDouble();

      case TeamArchetype.recoilReckless:
        return c.baseOrganism.attack.toDouble();

      case TeamArchetype.restLoop:
        return (c.baseOrganism.defense + c.baseOrganism.resistance).toDouble();

      case TeamArchetype.evasionBuffer:
        return c.selectedMoveNames.contains('Double Team')
            ? 1000
            : c.baseOrganism.speed.toDouble();

      case TeamArchetype.bulkyBruiser:
        return c.baseOrganism.health.toDouble();

      case TeamArchetype.toxicStall:
        return c.selectedMoveNames.contains('Toxic')
            ? 1000
            : c.baseOrganism.speed.toDouble();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  /// Resolve all Move objects for an organism's full movepool.
  static List<Move> _resolveMovelist(Organism o) {
    return o.moves
        .split(',')
        .map((n) => Move.findByName(n.trim()))
        .whereType<Move>()
        .toList();
  }

  static CapturedOrganism _makeOrganism(
    Organism o,
    List<Move> moves, {
    int level = 50,
    int minIV = 24,
    String? activeAbilityName,
  }) {
    // Near-perfect IVs for a challenging opponent
    final ivs = <String, int>{
      'health': minIV + _rng.nextInt(32 - minIV),
      'attack': minIV + _rng.nextInt(32 - minIV),
      'defense': minIV + _rng.nextInt(32 - minIV),
      'power': minIV + _rng.nextInt(32 - minIV),
      'resistance': minIV + _rng.nextInt(32 - minIV),
      'speed': minIV + _rng.nextInt(32 - minIV),
    };

    final maxHp = CapturedOrganism.calculateStat(
      'health',
      o.health,
      ivs['health']!,
      level: level,
    );

    final moveNames = moves.isEmpty
        ? ['Struggle']
        : moves.map((m) => m.name).toList();

    // 90% chance of base type, 10% chance of a completely random Tera Type
    ElementalType teraType;
    if (_rng.nextDouble() < 0.9) {
      final baseTypes = o.elementalTypes;
      teraType = baseTypes[_rng.nextInt(baseTypes.length)];
    } else {
      final allTypes = ElementalType.values
          .where((t) => t != ElementalType.basic)
          .toList();
      teraType = allTypes[_rng.nextInt(allTypes.length)];
    }

    return CapturedOrganism(
      baseOrganism: o,
      individualValues: ivs,
      currentHealth: maxHp,
      selectedMoveNames: moveNames,
      level: level,
      activeAbilityName: activeAbilityName,
      teraType: teraType,
    );
  }

  /// Randomly selects or forces an ability based on archetype.
  static String? _selectAbility(
    TeamArchetype? archetype,
    Organism o,
    List<Move> moves,
  ) {
    final pool = o.abilities
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    if (pool.isEmpty) return 'None';
    if (pool.length == 1) return pool.first;

    // For Chaos (null archetype), pure random selection
    if (archetype == null) {
      return pool[_rng.nextInt(pool.length)];
    }

    // Weather archetypes: PRIORITIZE weather-setting abilities
    if (archetype == TeamArchetype.sunTeam) {
      final sunSetter = pool.firstWhere(
        (a) => a.toLowerCase().contains('drought'),
        orElse: () => '',
      );
      if (sunSetter.isNotEmpty) return sunSetter;
    }
    if (archetype == TeamArchetype.rainTeam) {
      final rainSetter = pool.firstWhere(
        (a) => a.toLowerCase().contains('drizzle'),
        orElse: () => '',
      );
      if (rainSetter.isNotEmpty) return rainSetter;
    }
    if (archetype == TeamArchetype.sandTeam) {
      final sandSetter = pool.firstWhere(
        (a) => a.toLowerCase().contains('sand stream'),
        orElse: () => '',
      );
      if (sandSetter.isNotEmpty) return sandSetter;
    }
    if (archetype == TeamArchetype.snowTeam) {
      final snowSetter = pool.firstWhere(
        (a) => a.toLowerCase().contains('snow warning'),
        orElse: () => '',
      );
      if (snowSetter.isNotEmpty) return snowSetter;
    }

    // Secondary priority: Archetype synergy
    if (archetype == TeamArchetype.sunTeam) {
      final bloom = pool.firstWhere(
        (a) => a.toLowerCase().contains('chlorophyll'),
        orElse: () => '',
      );
      if (bloom.isNotEmpty) return bloom;
    }
    if (archetype == TeamArchetype.rainTeam) {
      final swim = pool.firstWhere(
        (a) => a.toLowerCase().contains('swift swim'),
        orElse: () => '',
      );
      if (swim.isNotEmpty) return swim;
    }

    // Default: Random selection for diversity
    return pool[_rng.nextInt(pool.length)];
  }

  static CapturedOrganism _assignTalisman(
    TeamArchetype? archetype,
    CapturedOrganism c,
  ) {
    // If a specialized build already assigned a talisman, stick with it!
    if (c.equippedTalisman != null) return c;

    // 0. Preliminary: Check for 4x Weaknesses and assign Resist Berry
    final resistBerry = _getResistBerryFor4xWeakness(c);
    if (resistBerry != null) {
      final item = Talisman.findByName(resistBerry);
      if (item != null) return c.copyWith(equippedTalisman: item);
    }

    // 1. Mandatory Weather Items for Setters
    if (archetype == TeamArchetype.rainTeam && _isRainSetter(_wrap(c))) {
      final item = Talisman.findByName('Damp Rock');
      if (item != null) return c.copyWith(equippedTalisman: item);
    }
    if (archetype == TeamArchetype.sunTeam && _isSunSetter(_wrap(c))) {
      final item = Talisman.findByName('Heat Rock');
      if (item != null) return c.copyWith(equippedTalisman: item);
    }
    if (archetype == TeamArchetype.sandTeam && _isSandSetter(_wrap(c))) {
      final item = Talisman.findByName('Smooth Rock');
      if (item != null) return c.copyWith(equippedTalisman: item);
    }
    if (archetype == TeamArchetype.snowTeam && _isSnowSetter(_wrap(c))) {
      final item = Talisman.findByName('Icy Rock');
      if (item != null) return c.copyWith(equippedTalisman: item);
    }

    // 2. Defensive items for bulky archetypes
    if (archetype == TeamArchetype.stall ||
        archetype == TeamArchetype.defensiveCore ||
        archetype == TeamArchetype.bulkyBruiser ||
        archetype == TeamArchetype.toxicStall) {
      final item = _getDefensiveItem(c);
      if (item != null) return c.copyWith(equippedTalisman: item);
    }

    // 3. Offensive items for offensive archetypes
    if (archetype == TeamArchetype.hyperOffense ||
        archetype == TeamArchetype.setupSweeper ||
        archetype == TeamArchetype.prioritySweeper ||
        archetype == TeamArchetype.revengeKiller ||
        (archetype != null &&
            [
              TeamArchetype.rainTeam,
              TeamArchetype.sunTeam,
              TeamArchetype.sandTeam,
              TeamArchetype.snowTeam,
            ].contains(archetype))) {
      // 50% chance for Gem, 50% for standard offensive item
      if (_rng.nextDouble() < 0.5) {
        final gem = _getGemForPrimarySTAB(c);
        if (gem != null) {
          final item = Talisman.findByName(gem);
          if (item != null) return c.copyWith(equippedTalisman: item);
        }
      }
      final item = _getOffensiveItem(c);
      if (item != null) return c.copyWith(equippedTalisman: item);
    }

    // 4. Hazard Stackers
    if (archetype == TeamArchetype.hazardStacker) {
      final c2 = _wrap(c);
      final isHazardSetter = c2.moves.any(
        (m) => m.effects.any((e) => e.type == MoveEffectType.setHazard),
      );
      if (isHazardSetter) {
        // Hazard setters usually want durability to set multiple layers
        final item =
            Talisman.findByName('Focus Sash') ??
            Talisman.findByName('Leftovers');
        if (item != null) return c.copyWith(equippedTalisman: item);
      } else {
        final item =
            Talisman.findByName('Red Card') ??
            Talisman.findByName('Rocky Helmet');
        if (item != null) return c.copyWith(equippedTalisman: item);
      }
    }

    // 5. Status Spread
    if (archetype == TeamArchetype.statusSpread) {
      final item = (c.baseOrganism.defense > 80)
          ? Talisman.findByName('Rocky Helmet')
          : Talisman.findByName('Leftovers');
      if (item != null) return c.copyWith(equippedTalisman: item);
    }

    // 6. Trick Room
    if (archetype == TeamArchetype.trickRoom) {
      final c2 = _wrap(c);
      final isTRSetter = c2.moves.any((m) => m.name == 'Trick Room');
      if (isTRSetter) {
        final item =
            Talisman.findByName('Mental Herb') ??
            Talisman.findByName('Focus Sash');
        if (item != null) return c.copyWith(equippedTalisman: item);
      } else {
        // TR Sweepers love power
        final item = c.baseOrganism.attack > c.baseOrganism.power
            ? (Talisman.findByName('Life Orb') ??
                  Talisman.findByName('Choice Band'))
            : (Talisman.findByName('Life Orb') ??
                  Talisman.findByName('Choice Specs'));
        if (item != null) return c.copyWith(equippedTalisman: item);
      }
    }

    // 7. Fallback: Strategy-based random selection
    final item = _getFallbackItem(c);
    if (item != null) return c.copyWith(equippedTalisman: item);

    // Final fallback
    return c;
  }

  static String? _getResistBerryFor4xWeakness(CapturedOrganism c) {
    for (final type in ElementalType.values) {
      if (type == ElementalType.basic) continue;
      double effectiveness = 1.0;
      for (final typeStr in c.baseOrganism.types) {
        final defType = ElementalTypeX.fromString(typeStr);
        effectiveness *= TypeChart.getEffectiveness(type, defType);
      }
      if (effectiveness >= 4.0) {
        return _resistBerries[type];
      }
    }
    return null;
  }

  static final Map<ElementalType, String> _resistBerries = {
    ElementalType.blaze: 'Occa Berry',
    ElementalType.aquatic: 'Passho Berry',
    ElementalType.electric: 'Wacan Berry',
    ElementalType.grass: 'Rindo Berry',
    ElementalType.cryo: 'Yache Berry',
    ElementalType.earth: 'Shuca Berry',
    ElementalType.flying: 'Coba Berry',
    ElementalType.toxic: 'Kebia Berry',
    ElementalType.rock: 'Charti Berry',
    ElementalType.arthropod: 'Tanga Berry',
    ElementalType.darkness: 'Colbur Berry',
    ElementalType.martial: 'Chople Berry',
    ElementalType.aura: 'Payapa Berry',
    ElementalType.spectral: 'Kasib Berry',
    ElementalType.drake: 'Haban Berry',
    ElementalType.metal: 'Babiri Berry',
    ElementalType.mystic: 'Roseli Berry',
  };

  static String? _getGemForPrimarySTAB(CapturedOrganism c) {
    if (c.baseOrganism.elementalTypes.isEmpty) return null;
    final primaryType = c.baseOrganism.elementalTypes.first;
    return _gemNames[primaryType];
  }

  static final Map<ElementalType, String> _gemNames = {
    ElementalType.blaze: 'Fire Gem',
    ElementalType.aquatic: 'Water Gem',
    ElementalType.grass: 'Grass Gem',
    ElementalType.electric: 'Electric Gem',
    ElementalType.cryo: 'Ice Gem',
    ElementalType.earth: 'Earth Gem',
    ElementalType.flying: 'Flying Gem',
    ElementalType.toxic: 'Toxic Gem',
    ElementalType.rock: 'Rock Gem',
    ElementalType.arthropod: 'Bug Gem',
    ElementalType.darkness: 'Dark Gem',
    ElementalType.martial: 'Fighting Gem',
    ElementalType.aura: 'Psychic Gem',
    ElementalType.spectral: 'Ghost Gem',
    ElementalType.drake: 'Dragon Gem',
    ElementalType.metal: 'Steel Gem',
    ElementalType.mystic: 'Fairy Gem',
    ElementalType.sound: 'Sound Gem',
    ElementalType.holy: 'Holy Gem',
    ElementalType.basic: 'Normal Gem',
  };

  static Talisman? _getDefensiveItem(CapturedOrganism c) {
    final o = c.baseOrganism;
    final wrapper = _wrap(c);
    final candidates = <String>[];

    // Assault Vest check: No status moves, good resistance
    final hasStatusMoves = wrapper.moves.any(
      (m) => m.category == MoveCategory.status,
    );
    if (!hasStatusMoves && o.resistance > 70) {
      candidates.add('Assault Vest');
    }

    if (o.elementalTypes.contains(ElementalType.toxic)) {
      candidates.add('Black Sludge');
    }

    if (o.defense > 90) {
      candidates.add('Rocky Helmet');
    }

    candidates.add('Leftovers');

    final name = candidates[_rng.nextInt(candidates.length)];
    return Talisman.findByName(name);
  }

  static Talisman? _getOffensiveItem(CapturedOrganism c) {
    final o = c.baseOrganism;
    final wrapper = _wrap(c);
    final candidates = <String>[];

    final isPhysical = o.attack >= o.power;

    // Choice items logic: Only if speed is decent or they are bulky
    if (o.speed > 90 || o.health > 100) {
      if (isPhysical) {
        candidates.add('Choice Band');
      } else {
        candidates.add('Choice Specs');
      }
    }

    if (o.speed > 80 && o.speed < 110) {
      candidates.add('Choice Scarf');
    }

    if (isPhysical) {
      candidates.add('Muscle Band');
    } else {
      candidates.add('Wise Glasses');
    }

    candidates.add('Life Orb');

    // High speed but frail
    if (o.speed > 100 && o.health < 80) {
      candidates.add('Focus Sash');
    }

    // Special items for multi-turn moves
    if (wrapper.moves.any((m) => m.isMultiTurn)) {
      final herb = Talisman.findByName('Power Herb');
      if (herb != null) return herb;
    }

    if (candidates.isEmpty) {
      return Talisman.findByName('Life Orb'); // Absolute fallback
    }

    final name = candidates[_rng.nextInt(candidates.length)];
    return Talisman.findByName(name) ?? Talisman.findByName('Life Orb');
  }

  static Talisman? _getFallbackItem(CapturedOrganism c) {
    if (c.baseOrganism.attack + c.baseOrganism.power > 160) {
      return _getOffensiveItem(c);
    }
    return _getDefensiveItem(c);
  }

  // ─────────────────────────────────────────────────────────────────
  // Move effect helpers
  // ─────────────────────────────────────────────────────────────────

  static bool _isProtect(Move m) =>
      m.effects.any((e) => e.type == MoveEffectType.protect) ||
      m.name == 'Protect' ||
      m.name == 'Spiky Shield';

  static bool _isStatusInflicting(Move m) => m.effects.any(
    (e) =>
        e.type == MoveEffectType.statusPoison ||
        e.type == MoveEffectType.statusBurn ||
        e.type == MoveEffectType.statusParalysis ||
        e.type == MoveEffectType.statusBleed ||
        e.type == MoveEffectType.statusStun ||
        e.type == MoveEffectType.statusSleep,
  );

  static bool _isHeal(Move m) =>
      m.effects.any((e) => e.type == MoveEffectType.heal) ||
      m.drainPercent > 0 ||
      m.name == 'Rest' ||
      m.name == 'Recover' ||
      m.name == 'Roost' ||
      m.name == 'Synthesis' ||
      m.name == 'Shore Up' ||
      m.name == 'Milk Drink' ||
      m.name == 'Wish' ||
      m.name == 'Morning Sun' ||
      m.name == 'Moonlight';

  static bool _isSelfStatBoost(Move m, List<String> stats) => m.effects.any(
    (e) =>
        e.type == MoveEffectType.statChange &&
        e.target == 'self' &&
        stats.any((s) => e.stat == s),
  );

  static String _name(TeamArchetype a) {
    switch (a) {
      case TeamArchetype.hyperOffense:
        return 'Hyper Offense';
      case TeamArchetype.stall:
        return 'Stall';
      case TeamArchetype.balanced:
        return 'Balanced';
      case TeamArchetype.statusSpread:
        return 'Status Spread';
      case TeamArchetype.rainTeam:
        return 'Rain';
      case TeamArchetype.sunTeam:
        return 'Sun';
      case TeamArchetype.sandTeam:
        return 'Sandstorm';
      case TeamArchetype.snowTeam:
        return 'Snow/Blizzard';
      case TeamArchetype.hazardStacker:
        return 'Hazard Stack';
      case TeamArchetype.antiHazard:
        return 'Anti-Hazard';
      case TeamArchetype.revengeKiller:
        return 'Revenge Killer';
      case TeamArchetype.defensiveCore:
        return 'Defensive Core';
      case TeamArchetype.setupSweeper:
        return 'Setup Sweeper';
      case TeamArchetype.trickRoom:
        return 'Trick Room';
      case TeamArchetype.tailwindSpeed:
        return 'Tailwind Offense';
      case TeamArchetype.dualScreens:
        return 'Dual Screens';
      case TeamArchetype.prioritySweeper:
        return 'Priority Rush';
      case TeamArchetype.perishTrapper:
        return 'Perish Trap';
      case TeamArchetype.gimmickyAssist:
        return 'Gimmick Chaos';
      case TeamArchetype.criticalFocus:
        return 'Crits Only';
      case TeamArchetype.recoilReckless:
        return 'Reckless Recoil';
      case TeamArchetype.restLoop:
        return 'Rest Loop';
      case TeamArchetype.evasionBuffer:
        return 'Evasion Buffer';
      case TeamArchetype.bulkyBruiser:
        return 'Bulky Bruiser';
      case TeamArchetype.toxicStall:
        return 'Toxic Stall';
      case TeamArchetype.psychicTerrainAbuser:
        return 'Psychic Terrain Abuser';
      case TeamArchetype.electricTerrainAbuser:
        return 'Electric Terrain Abuser';
    }
  }

  static bool _isGodTier(Organism o) {
    return o.health > 300 ||
        o.attack > 300 ||
        o.defense > 300 ||
        o.power > 300 ||
        o.resistance > 300 ||
        o.speed > 300;
  }

  // --- Weather Helpers ---

  static bool _isRainSetter(_OrgCandidate c) =>
      c.organism.abilities.toLowerCase().contains('drizzle') ||
      c.organism.abilities.toLowerCase().contains('primordial sea') ||
      c.moves.any((m) => m.effects.any((e) => e.stat == 'rain'));

  static bool _isSunSetter(_OrgCandidate c) =>
      c.organism.abilities.toLowerCase().contains('drought') ||
      c.organism.abilities.toLowerCase().contains('desolate land') ||
      c.moves.any((m) => m.effects.any((e) => e.stat == 'sun'));

  static bool _isSandSetter(_OrgCandidate c) =>
      c.organism.abilities.toLowerCase().contains('sand stream') ||
      c.moves.any((m) => m.effects.any((e) => e.stat == 'sandstorm'));

  static bool _isSnowSetter(_OrgCandidate c) =>
      c.organism.abilities.toLowerCase().contains('snow warning') ||
      c.moves.any((m) => m.effects.any((e) => e.stat == 'hail'));

  static bool _isPsychicTerrainSetter(_OrgCandidate c) =>
      c.organism.abilities.toLowerCase().contains('psychic surge') ||
      c.moves.any((m) => m.effects.any((e) => e.stat == 'psychic'));

  static bool _isElectricTerrainSetter(_OrgCandidate c) =>
      c.organism.abilities.toLowerCase().contains('electric surge') ||
      c.moves.any((m) => m.effects.any((e) => e.stat == 'electric'));

  static bool _hasRainAbility(Organism o) {
    final abs = o.abilities.toLowerCase();
    return abs.contains('swift swim') ||
        abs.contains('hydration') ||
        abs.contains('rain dish') ||
        abs.contains('dry skin');
  }

  static bool _hasSunAbility(Organism o) {
    final abs = o.abilities.toLowerCase();
    return abs.contains('chlorophyll') ||
        abs.contains('solar power') ||
        abs.contains('leaf guard') ||
        abs.contains('harvest');
  }

  static bool _hasSandAbility(Organism o) {
    final abs = o.abilities.toLowerCase();
    return abs.contains('sand rush') ||
        abs.contains('sand force') ||
        abs.contains('sand veil');
  }

  static bool _hasSnowAbility(Organism o) {
    final abs = o.abilities.toLowerCase();
    return abs.contains('slush rush') ||
        abs.contains('snow cloak') ||
        abs.contains('ice body');
  }

  static bool _hasElectricTerrainAbility(Organism o) {
    final abs = o.abilities.toLowerCase();
    return abs.contains('surge surfer') ||
        abs.contains('static') ||
        abs.contains('volt absorb') ||
        abs.contains('lightning rod') ||
        abs.contains('motor drive') ||
        abs.contains('galvanize') ||
        abs.contains('transistor') ||
        abs.contains('battery');
  }

  static bool _hasPsychicTerrainAbility(Organism o) {
    final abs = o.abilities.toLowerCase();
    return abs.contains('psychic surge') ||
        abs.contains('synchronize') ||
        abs.contains('magic guard') ||
        abs.contains('magic bounce') ||
        abs.contains('telepathy');
  }

  static _OrgCandidate _wrap(CapturedOrganism c) {
    final moves = c.selectedMoveNames
        .map((name) => Move.findByName(name))
        .whereType<Move>()
        .toList();
    return _OrgCandidate(c.baseOrganism, moves);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM SPECIALIZED BUILDS REGISTRY
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a specific animal 'style' or 'combo'.
/// Add your own builds to [SpecialBuilds.all] below!
class AnimalBuild {
  final String name;
  final String description;

  /// Returns true if this organism is a valid candidate for this build.
  final bool Function(Organism o, List<Move> allMoves) fitness;

  /// Moves that MUST be included in the build.
  final List<String> requiredMoves;

  /// The ability the animal MUST have.
  final String requiredAbility;

  /// Optional preferred talisman name.
  final String? requiredTalisman;

  const AnimalBuild({
    required this.name,
    required this.description,
    required this.fitness,
    required this.requiredMoves,
    required this.requiredAbility,
    this.requiredTalisman,
  });
}

class SpecialBuilds {
  static final List<AnimalBuild> all = [
    AnimalBuild(
      name: 'Skill Link Multi-Hit',
      description: 'Guarantees maximum hits for multi-hit moves.',
      fitness: (o, moves) =>
          o.abilities.contains('Skill Link') && moves.any((m) => m.maxHits > 1),
      requiredMoves: [], // Will pick from multi-hit moves automatically
      requiredAbility: 'Skill Link',
      requiredTalisman: 'Scope Lens',
    ),
    AnimalBuild(
      name: 'No Guard Accuracy-Fixer',
      description: 'Never misses, allowing for high-power low-accuracy moves.',
      fitness: (o, moves) =>
          o.abilities.contains('No Guard') &&
          moves.any((m) => m.accuracy < 85 && m.baseDamage > 0),
      requiredMoves: [],
      requiredAbility: 'No Guard',
      requiredTalisman: 'Life Orb',
    ),
    AnimalBuild(
      name: 'Reckless Recoil User',
      description: 'Powers up recoil moves.',
      fitness: (o, moves) =>
          o.abilities.contains('Reckless') &&
          moves.any((m) => m.recoilPercent > 0),
      requiredMoves: [],
      requiredAbility: 'Reckless',
      requiredTalisman: 'Shell Bell',
    ),
    AnimalBuild(
      name: 'Serene Grace Flincher',
      description:
          'Maximizes secondary effect chances for status or flinching.',
      fitness: (o, moves) =>
          o.abilities.contains('Serene Grace') &&
          moves.any(
            (m) => m.effects.any(
              (e) =>
                  e.type == MoveEffectType.statChangeChance ||
                  e.type == MoveEffectType.statusStun,
            ),
          ),
      requiredAbility: 'Serene Grace',
      requiredMoves: [],
      requiredTalisman: 'King\'s Rock',
    ),
    AnimalBuild(
      name: 'Crit Abuser',
      description: 'Abuses high crit rate moves.',
      fitness: (o, moves) =>
          o.abilities.contains('Super Luck') &&
          moves.any((m) => m.critRate > 0),
      requiredMoves: [],
      requiredAbility: 'Super Luck',
      requiredTalisman: 'Scope Lens',
    ),
    AnimalBuild(
      name: 'Guts Physical Attacker',
      description:
          'Boosts Attack significantly when afflicted by a status condition.',
      fitness: (o, moves) => o.abilities.contains('Guts') && o.attack > o.power,
      requiredAbility: 'Guts',
      requiredMoves: ["Facade"],
      requiredTalisman: 'Flame Orb',
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────
// Internal candidate container
// ─────────────────────────────────────────────────────────────────

class _OrgCandidate {
  final Organism organism;
  final List<Move> moves; // pre-resolved moves

  const _OrgCandidate(this.organism, this.moves);
}
