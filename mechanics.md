# Animal Warfare Battle Mechanics Documentation

This document provides a guide for developers to create and customize moves and abilities in the Animal Warfare battle engine. The engine is data-driven, meaning most mechanics can be defined or modified within JSON files without changing the core Dart code.

---

## ⚔️ Custom Moves

Moves are defined in `assets/moves.json`.

### Move Data Structure

Each move is a JSON object with the following primary fields:

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | Unique identifier for the move. Matches the `moves` list in `Organisms.json`. |
| `description` | String | User-facing description of the move's effect. |
| `baseDamage` | int | Power of the move. 0 for status/non-damaging moves. |
| `accuracy` | int | Percentage chance (0-100) for the move to hit. |
| `type` | String | Elemental type (e.g., `basic`, `blaze`, `aquatic`, `cryo`). |
| `stamina` | int | PP equivalent. Cost to use the move. |
| `category` | String | `physical`, `special`, or `status`. |
| `targetCount` | String | `single` (default) or `multiple` (hits all opponents in doubles). |

### Complex Move Flags

Use these boolean flags to interact with specific abilities (e.g., "Strong Jaw" boosts "isBite" moves):

- `isContact`: (Defaults to true for physical moves) Move involves physical touching.
- `isPunch`: Move is a punching attack (Interacts with Iron Fist).
- `isBite`: Move is a biting attack (Interacts with Strong Jaw).
- `isSoundBased`: Move is sound-based (Bypasses certain protections).

### Move Effects

The `effects` array defines additional behavior beyond raw damage.

Example: **Fire Punch** (Damage + 10% Burn)
```json
{
  "name": "Fire Punch",
  "baseDamage": 75,
  "category": "physical",
  "isPunch": true,
  "effects": [
    {
      "type": "statusBurn",
      "target": "opponent",
      "chance": 10
    }
  ]
}
```

#### Common `MoveEffect` Types:
- `statChange`: Buffs or debuffs a `stat` by a `value` (stages).
- `statusPoison`, `statusBurn`, `statusSleep`, etc.: Inflicts a status condition.
- `heal`: Restores HP to the `target`.
- `weather`, `terrain`: Changes the field environment.
- `drainPercent`: Heals the user for a percentage of the damage dealt.
- `recoilPercent`: Damages the user for a percentage of the damage dealt.

---

## 🧬 Custom Abilities

Abilities are defined in `assets/abilities.json`.

### Ability Triggers

The `trigger` field determines when the ability logic fires:

| Trigger | Description |
| :--- | :--- |
| `onEntry` | Fires when the organism enters the battlefield. |
| `onCalculateStat` | Modifies stats temporarily during battle. |
| `onCalculateDamage` | Modifies damage dealt or taken. |
| `onDamageTaken` | Fires after the organism is hit by a move. |
| `onDamageDealt` | Fires after the organism hits a target. |
| `onStatLoss` | Protects or reacts to stat drops. |
| `onTurnEnd` | Fires at the end of every turn. |

### Ability Effects

The `effectType` field defines what the ability actually does:

- `statMultiplier`: Multiplies a stat (e.g., `2.0` for Huge Power).
- `damageMultiplier`: Multiplies damage dealt or taken.
- `statChange`: Applies a permanent stat stage change (e.g., `Intimidate`).
- `weatherChange`, `terrainChange`: Changes field effects.
- `preventStatus`: Immunitizes against certain status effects.
- `preventDamage`: Immunitizes against specific move types (e.g., `Levitate`).

### Condition System

Conditions allow abilities to be situational. Add them to the `conditions` array:

- `full_hp`: Only active at 100% HP.
- `hp_below_50`, `hp_below_30`: Threshold-based triggers.
- `contact`: Only triggers on contact moves.
- `type_blaze`, `type_earth`, etc.: Only triggers on specific move types.
- `statused`: Active only if the organism has a status condition.

Example: **Swift Swim**
```json
{
    "name": "Swift Swim",
    "description": "Speed doubles in rain.",
    "trigger": "onCalculateStat",
    "effectType": "statMultiplier",
    "targetStat": "speed",
    "magnitude": 2.0,
    "conditions": ["weather_rain"]
}
```

---

## 🛠️ Internal Processing

The engine processes these JSON definitions through the following core files:

1. **`BattleManager` (`lib/game/battle_manager.dart`)**: The central state machine.
   - `_executeTurn`: Orchestrates the move execution flow.
   - `_applyMoveEffect`: Parses the `MoveEffect` objects from JSON.
   - `_applyGlobalTurnEffects`: Handles weather and terrain damage.

2. **`AbilityHelpers` (`lib/game/ability_helpers.dart`)**: A mixin used by `BattleManager`.
   - `_triggerAbilities`: Scans an organism's abilities for a specific trigger.
   - `_checkAbilityCondition`: Evaluates if the `conditions` list is met.
   - `_applyAbilityEffect`: Translates `effectType` into actual game state changes.

### Adding New Mechanics

To add a completely new mechanic (e.g., a "Room" effect or a new status):
1. Add the enum value to `MoveEffectType` (`move.dart`) or `AbilityEffectType` (`ability.dart`).
2. Implement the logic in `BattleManager._applyMoveEffect` or `AbilityHelpers._applyAbilityEffect`.
3. Update the JSON files to use the new type.

---

## 📋 Reference: Status Effects

Defined in `StatusEffectType` within `lib/models/status_effect.dart`.

| Status | Effect |
| :--- | :--- |
| `poison` | 12.5% Max HP damage/turn. |
| `burn` | 6% Max HP damage/turn + Physical damage halved. |
| `paralysis` | -75% Speed + 25% chance to fail move. |
| `sleep` | Cannot move for 2-5 turns. |
| `freeze` | Cannot move until thawed. |
| `bleed` | Heavy DoT (12.5% Max HP/turn). |
| `stun` | Skips 1 turn. |
| `stealth` | 50% evasion + 2x damage dealt (Removed on attack/hit). |
| `vulnerable` | Takes 50% extra damage from attacks. |
