# AI Decision Engine – High-Level Overview

The AI in `ai_decision_engine.dart` operates as a sophisticated rule-based scoring system. It processes the game state through two primary phases to determine the most effective action.

## Phase 1: Move Scoring

For every legal move available, the AI calculates a numerical **score**. The move with the highest total score is selected for the turn.

* **Heuristics:** 50 distinct traits covering mechanics like damage, status, healing, stat changes, hazards, items, weather/terrain, and turn counting.
* **Logic Blocks:** The scoring function is modular; each block implements a specific trait or game mechanic.

---

## Phase 2: Switching Decision

After a move is selected, the AI evaluates if the active organism should be swapped for a bench member.

* **Heuristics:** Traits 11–20 drive this logic (e.g., "switch on bad matchup," "protect sweeper," or "sacrifice weakest member").
* **Contextual Awareness:** Decisions are based on matchup data, entry hazards, One-Hit Knockout (OHKO) risks, and team win-conditions.

---

## Core Components of the Scoring System

### 1. Damage & Status Evaluation

| Category | Logic |
| --- | --- |
| **Damage** | Estimates expected damage (multipliers, crits, weather). Moves that guaranteed a **KO** receive a massive bonus. |
| **Status Moves** | Penalized if redundant (e.g., if the opponent is likely to switch). High rewards for spreading status (poison, burn, etc.) to healthy targets. |

### 2. Utility & Resource Management

* **Healing:** Rewarded when HP is low; penalized when healthy.
* **Setup:** Stat-boosting moves are favored if the AI isn't already capped and the current situation is "survivable."
* **Hazards:** Strong positive score for setting a new hazard; heavy penalty for attempting to set a hazard already active on the field.
* **Risk/Reward:** Lethal recoil or recharge turns are penalized unless they guarantee a crucial KO.

### 3. Held-Item Synergy

The AI adjusts its scoring based on equipped items:

* **Choice Items:** Enforces move lock-in; penalizes status moves once locked.
* **Focus Sash/Life Orb:** Influences the trade-off between aggressive plays and defensive preservation.
* **Weather/Terrain Items:** Strongly favors moves that initiate effects extended by the held item.

### 4. Team Archetype Behavior

The AI shifts its scoring priorities based on its assigned `TeamArchetype`.

* **Hyper Offense:** Rewards high-damage STAB; penalizes passive status moves.
* **Stall:** Rewards `Protect`, `Detect`, and status spreading; penalizes redundant attacks.
* **Weather (Sun/Rain):** Prioritizes setting weather early, then favors moves benefiting from those conditions.
* **Hazard Stacker:** Prioritizes hazards early, then transitions to hard attacks.

---

## Internal Helpers

### `shouldSwitch`

A static method that acts as a tactical advisor. It evaluates the bench against the current opponent to decide if a swap is necessary. It balances:

* Incoming/Outgoing damage.
* Speed mismatches and OHKO risks.
* **Player History:** Anticipates if the human player frequently switches or plays aggressively.

### Evaluation Helpers

* **`identifyWinCondition`**: Identifies the "sweeper" by analyzing speed, power, and move-type coverage.
* **`identifyWall`**: Finds the defensive anchor by analyzing HP, resistances, and recovery moves.

---

## Turn Flow Summary

1. **Move Selection:** `evaluateMove` is called for all legal moves $\rightarrow$ Highest score wins.
2. **Switch Decision:** `shouldSwitch` determines if the active mon should stay or leave.
3. **Action Resolution:** Actions are resolved in speed order by the engine, applying damage and effects.

> **Bottom Line:** This system creates a logically coherent opponent that adapts to the player while maintaining a strategy consistent with its team's design.

---

**Would you like me to generate a Mermaid.js flowchart code block to visualize this turn flow within the document?**