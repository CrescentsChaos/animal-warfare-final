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
      if (normalPool.isEmpty)
        return _buildChaos(
          allOrganisms,
          withTalismans: withTalismans,
          level: level,
          teamSize: teamSize,
          minIV: minIV,
        );

      return _buildChaos(
        normalPool,
        withTalismans: withTalismans,
        level: level,
        teamSize: teamSize,
        minIV: minIV,
      );
    }

    // Pick a random archetype
    final archetypes = TeamArchetype.values;
    final archetype = archetypes[_rng.nextInt(archetypes.length)];

    return _buildForArchetype(
      archetype,
      allOrganisms,
      withTalismans: withTalismans,
      level: level,
      teamSize: teamSize,
      minIV: minIV,
    );
  }

  // ───────────────────────────────────────────────
  // Chaos mode — pure random, no archetype logic
  // ───────────────────────────────────────────────
  static ArchetypeResult _buildChaos(
    List<Organism> allOrganisms, {
    bool withTalismans = true,
    int level = 50,
    int teamSize = 5,
    int minIV = 24,
  }) {
    final shuffled = List.of(allOrganisms)..shuffle(_rng);
    final picked = shuffled.take(teamSize).toList();

    final team = picked.map((o) {
      final moves = _resolveMovelist(o);
      final randomMoves = (List.of(moves)..shuffle(_rng)).take(4).toList();
      final c = _makeOrganism(o, randomMoves, level: level, minIV: minIV);
      return withTalismans
          ? _assignTalisman(null, c)
          : c; // Archetype null for chaos
    }).toList();

    return ArchetypeResult(archetype: null, archetypeName: 'Chaos', team: team);
  }

  // ───────────────────────────────────────────────
  // Archetype-driven team build
  // ───────────────────────────────────────────────
  static ArchetypeResult _buildForArchetype(
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

    // 3. Score candidates by archetype fit
    eligible.sort(
      (a, b) => _score(archetype, b).compareTo(_score(archetype, a)),
    );

    // 4. Pick top N (variety among top scores)
    final topN = eligible.take(min(15, eligible.length)).toList()
      ..shuffle(_rng);
    final picked = topN.take(teamSize).toList();

    // 5. Build CapturedOrganisms with archetype-tuned movesets
    var team = picked.map((c) {
      final moves = _selectMoves(archetype, c);
      final captured = _makeOrganism(
        c.organism,
        moves,
        level: level,
        minIV: minIV,
      );
      return withTalismans ? _assignTalisman(archetype, captured) : captured;
    }).toList();

    // 6. Order the lead
    team = _orderLead(archetype, team);

    return ArchetypeResult(
      archetype: archetype,
      archetypeName: _name(archetype),
      team: team,
    );
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
            o.types.contains(ElementalType.aquatic) ||
            _hasRainAbility(o);

      case TeamArchetype.sunTeam:
        return _isSunSetter(c) ||
            o.types.contains(ElementalType.blaze) ||
            _hasSunAbility(o);

      case TeamArchetype.sandTeam:
        return _isSandSetter(c) ||
            o.types.contains(ElementalType.rock) ||
            o.types.contains(ElementalType.metal) ||
            o.types.contains(ElementalType.earth) ||
            _hasSandAbility(o);

      case TeamArchetype.snowTeam:
        return _isSnowSetter(c) ||
            o.types.contains(ElementalType.cryo) ||
            _hasSnowAbility(o);

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
        if (o.types.contains(ElementalType.aquatic)) s += 50;
        if (_hasRainAbility(o)) s += 100;
        return s;

      case TeamArchetype.sunTeam:
        double s = (o.attack + o.power).toDouble();
        if (_isSunSetter(c)) s += 500;
        if (o.types.contains(ElementalType.blaze)) s += 50;
        if (_hasSunAbility(o)) s += 100;
        return s;

      case TeamArchetype.sandTeam:
        double s = (o.attack + o.power + o.defense).toDouble();
        if (_isSandSetter(c)) s += 500;
        if (o.types.contains(ElementalType.rock)) s += 50;
        if (_hasSandAbility(o)) s += 100;
        return s;

      case TeamArchetype.snowTeam:
        double s = (o.attack + o.power).toDouble();
        if (_isSnowSetter(c)) s += 500;
        if (o.types.contains(ElementalType.cryo)) s += 50;
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
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Move Selection — pick best 4 moves per archetype
  // ─────────────────────────────────────────────────────────────────
  static List<Move> _selectMoves(TeamArchetype archetype, _OrgCandidate c) {
    final pool = c.moves;
    if (pool.isEmpty) return [];

    // Score each move by archetype priority, then pick top 4
    final scored = pool
        .map((m) => MapEntry(m, _scoreMove(archetype, m)))
        .toList();
    scored.sort((a, b) => b.value.compareTo(a.value));

    // Always guarantee at least one damaging move
    final selected = <Move>[];
    final top = scored.take(min(8, scored.length)).map((e) => e.key).toList();

    // Mandatory: include archetype-priority moves first
    for (final m in top) {
      if (selected.length >= 4) break;
      if (!selected.contains(m)) selected.add(m);
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
            m.type == ElementalType.metal)
          s += 40;
        break;

      case TeamArchetype.snowTeam:
        if (m.effects.any((e) => e.stat == 'hail')) s += 800;
        if (m.type == ElementalType.cryo) s += 100;
        if (m.name == 'Blizzard') s += 150;
        if (m.name == 'Aurora Veil') s += 300;
        break;

      case TeamArchetype.hazardStacker:
        // Hazard setters: prize every hazard move; then phazing; then damage
        if (m.effects.any((e) => e.type == MoveEffectType.setHazard)) s += 500;
        if (m.name == 'Roar' ||
            m.name == 'Whirlwind' ||
            m.name == 'Dragon Tail' ||
            m.name == 'Circle Throw')
          s += 350; // hazard abuser core move
        if (_isProtect(m)) s += 80;
        if (m.baseDamage > 60) s += 20;
        break;

      case TeamArchetype.antiHazard:
        if (m.name == 'Rapid Spin' ||
            m.name == 'Defog' ||
            m.name == 'Mortal Spin')
          s += 500;
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
        if (m.baseDamage > 0 && _isStatusInflicting(m))
          s += 50; // damage+status
        // Hex gets massive bonus — doubles in power when target is statused
        if (m.name == 'Hex' ||
            m.name == 'Venoshock' ||
            m.name == 'Wake-Up Slap')
          s += 250;
        if (m.baseDamage > 60 && !_isStatusInflicting(m)) s += 10;
        break;

      case TeamArchetype.setupSweeper:
        if (_isSelfStatBoost(m, ['attack', 'power', 'speed'])) s += 400;
        if (m.baseDamage > 60) s += 50;
        if (m.category == MoveCategory.status &&
            !_isSelfStatBoost(m, ['attack', 'power', 'speed']))
          s -= 50;
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

    return CapturedOrganism(
      baseOrganism: o,
      individualValues: ivs,
      currentHealth: maxHp,
      selectedMoveNames: moveNames,
      level: level,
    );
  }

  static CapturedOrganism _assignTalisman(
    TeamArchetype? archetype,
    CapturedOrganism c,
  ) {
    // 1. Mandatory Weather Rocks for Setters
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

    // 2. Complimentary items for weather team members
    if (archetype != null &&
        [
          TeamArchetype.rainTeam,
          TeamArchetype.sunTeam,
          TeamArchetype.sandTeam,
          TeamArchetype.snowTeam,
        ].contains(archetype)) {
      final o = c.baseOrganism;
      final candidates = <String>[];

      // Offensive preference
      if (o.attack > o.power) {
        candidates.addAll([
          'Choice Band',
          'Life Orb',
          'Muscle Band',
          'Strength Charm',
        ]);
      } else {
        candidates.addAll([
          'Choice Specs',
          'Life Orb',
          'Wise Glasses',
          'Power Crystal',
        ]);
      }

      // Speed preference
      if (o.speed > 100) {
        candidates.addAll(['Choice Scarf', 'Swift Rune', 'Focus Sash']);
      }

      // Defensive preference
      if (o.defense > 80 || o.resistance > 80 || o.health > 100) {
        candidates.addAll([
          'Leftovers',
          'Assault Vest',
          'Rocky Helmet',
          'Iron Ward',
          'Guardian Shell',
        ]);
      }

      // Type specific
      if (o.types.contains(ElementalType.toxic)) {
        candidates.add('Black Sludge');
      }

      if (candidates.isNotEmpty) {
        final name = candidates[_rng.nextInt(candidates.length)];
        final item = Talisman.findByName(name);
        if (item != null) return c.copyWith(equippedTalisman: item);
      }
    }

    // 3. Archetype-specific talisman logic for non-weather teams
    if (archetype == TeamArchetype.hazardStacker) {
      final c2 = _wrap(c);
      final isHazardSetter = c2.moves.any(
        (m) => m.effects.any((e) => e.type == MoveEffectType.setHazard),
      );
      if (isHazardSetter) {
        // Setters want bulk to survive and set hazards
        final item =
            Talisman.findByName('Leftovers') ??
            Talisman.findByName('Assault Vest');
        if (item != null) return c.copyWith(equippedTalisman: item);
      } else {
        // Hazard abusers want Red Card to force switches into hazards
        final item =
            Talisman.findByName('Red Card') ??
            Talisman.findByName('Rocky Helmet');
        if (item != null) return c.copyWith(equippedTalisman: item);
      }
    }

    if (archetype == TeamArchetype.statusSpread) {
      // Rocky Helmet punishes contact moves; great with Hex
      final o = c.baseOrganism;
      final item = (o.defense > 80)
          ? Talisman.findByName('Rocky Helmet')
          : Talisman.findByName('Leftovers');
      if (item != null) return c.copyWith(equippedTalisman: item);
    }

    if (archetype == TeamArchetype.defensiveCore) {
      final item =
          Talisman.findByName('Leftovers') ??
          Talisman.findByName('Rocky Helmet') ??
          Talisman.findByName('Assault Vest');
      if (item != null) return c.copyWith(equippedTalisman: item);
    }

    if (archetype == TeamArchetype.trickRoom) {
      final c2 = _wrap(c);
      final isTRSetter = c2.moves.any((m) => m.name == 'Trick Room');
      if (isTRSetter) {
        final item =
            Talisman.findByName('Mental Herb') ??
            Talisman.findByName('Focus Sash');
        if (item != null) return c.copyWith(equippedTalisman: item);
      } else {
        // TR sweeper: Choice Band/Specs for max damage
        final o = c.baseOrganism;
        final item = o.attack > o.power
            ? Talisman.findByName('Choice Band')
            : Talisman.findByName('Choice Specs');
        if (item != null) return c.copyWith(equippedTalisman: item);
      }
    }

    // Fallback to random for Chaos or if no specific logic matched
    if (Talisman.allTalismans.isEmpty) return c;
    final t = Talisman.allTalismans[_rng.nextInt(Talisman.allTalismans.length)];
    return c.copyWith(equippedTalisman: t);
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
      m.name == 'Roost';

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

  static _OrgCandidate _wrap(CapturedOrganism c) {
    final moves = c.selectedMoveNames
        .map((name) => Move.findByName(name))
        .whereType<Move>()
        .toList();
    return _OrgCandidate(c.baseOrganism, moves);
  }
}

// ─────────────────────────────────────────────────────────────────
// Internal candidate container
// ─────────────────────────────────────────────────────────────────

class _OrgCandidate {
  final Organism organism;
  final List<Move> moves; // pre-resolved moves

  const _OrgCandidate(this.organism, this.moves);
}
