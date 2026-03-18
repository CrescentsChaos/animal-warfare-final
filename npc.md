# Animal Warfare: Story and NPC Creation Guide

This document is your comprehensive guide to bringing the world of Animal Warfare to life using the NPC and Event Flag systems. With these tools, you can build immersive quests, branching storylines, and dynamic map changes.

---

## 1. The Core Data Model (`NPCData`)

When defining an NPC in your `maps.json` or `biome_data.json` files, you use the `NPCData` structure. Here are all the fields you have at your disposal to craft a story:

### Basic Information
*   `id` *(String)*: Unique identifier for the NPC. Critical for tracking if they've been defeated, given their rewards, or completed their quests.
*   `name` *(String)*: The NPC's display name in dialogue.
*   `spriteKey` *(String)*: The visual asset used for this NPC on the overworld.
*   `row`, `col` *(int)*: Starting grid coordinates on the map.

### Movement & Vision
*   `movementType` *(String)*: `still` (stationary) or `random` (wanders around).
*   `movementRange` *(int)*: How many tiles from their spawn point they are allowed to wander.
*   `visionRange` *(int)*: Number of tiles they can see in front of them (triggers battles for trainers).

### Dialogue
*   `dialogue` *(List<String>)*: The main text the NPC says upon interaction or when spotting the player.
*   `postEventDialogue` *(List<String>)*: Alternate text shown *after* their main event is completed (e.g., after receiving their item, completing their quest, or reading their story).
*   `defeatText` *(String)*: Specifically for trainer variants. Spoken after you defeat them in battle.

### Event & Progression Fields (The Story Engine)
*   `scriptType` *(String)*: Determines the NPC's core behavior (see Section 2).
*   `requiredFlag` *(String)*: The NPC will be ignored/invisible unless the player possesses this flag. (If used with `blocker` NPCs, this flag *removes* them instead of spawning them).
*   `setsFlag` *(String)*: A custom event flag given to the player permanently after they successfully clear this NPC's event.
*   `questId` *(String)*: Registers a quest to the player's active log.
*   `itemRewardId` *(String)* / `itemRewardCount` *(int)*: Handed to the player upon event completion.
*   `itemRequiredId` *(String)* / `itemRequiredCount` *(int)*: Consumed from the player's inventory as a requirement for the event.
*   `organismRequiredId` *(String)*: Requires the player to have captured a specific species (by name) in their Anidex.
*   `teamId` *(String)*: Maps to an enemy squad in `npc_teams.json` for battles.

---

## 2. NPC Script Types (Archetypes)

The `scriptType` dictates how the engine parses your NPC's interaction.

### Story & Lore
*   **`story`**: A simple narrator or lore character. Once you talk to them, they read their `dialogue`. If `setsFlag` is defined, they grant it. On subsequent talks, they say `postEventDialogue`.
*   **`blocker`**: Placed intentionally mapped on a narrow road or doorway. They say their `dialogue` to reject entry. Once the player obtains the `requiredFlag` from someone else in the world, the blocker disappears forever and frees the path.

### Quests & Errands
*   **`quest_giver`**: Grants the quest specified in `questId`. Until completed, they will repeat quest lore. Once the quest finishes, they grant `setsFlag` and show `postEventDialogue`.
*   **`fetch_quest`**: Instantly checks your inventory for `itemRequiredId` (amount: `itemRequiredCount`) or `organismRequiredId`. If you have it, they take the items, grant `itemRewardId` + `setsFlag`, and shift to `postEventDialogue`.
*   **`request_board`**: Similar to `quest_giver`, but represents inanimate bounty boards offering structured tasks.

### Rewards & Upgrades
*   **`item_giver`**: Says their `dialogue` and blindly hands you `itemRewardId` x `itemRewardCount`. Prevents double-dipping automatically. Grants `setsFlag` optionally.
*   **`professor`**: Represents a milestone rewarder. Evaluates your total total species captured in your Anidex. If it meets `itemRequiredCount`, they grant you the `itemRewardId` and set a flag.

### Battles 
*(All trainers behave exactly the same logically, acting on line of sight and remembering their defeat state permanently).*
*   **`trainer`**: Generic opponent.
*   **`rival`**: Re-occurs throughout the story. Use custom `teamId` values scaled for your progress.
*   **`major_trainer`**: Gym leaders, bosses, etc.
*   **`evil_team`**: Antagonists in the story.
*   **`medic`**: Instantly heals your entire 5-slot battle team back to maximum health.
*   **`shopkeeper`**: Opens the biome's standard merchant UI screen.

---

## 3. Creating a Perfect Story Arc (Examples)

### Example 1: The "Blocker" Progression Loop
1.  **Blocker NPC (`grunt_1`)**: Placed on a bridge. `scriptType: 'blocker'`, `dialogue: ["You can't pass! Our boss is having a meeting!"]`, `requiredFlag: 'boss_defeated'`.
2.  **Boss NPC (`evil_boss`)**: Placed in a warehouse. `scriptType: 'evil_team'`, `teamId: 'rocket_admin_1'`, `setsFlag: 'boss_defeated'`.
*   **Flow**: The player cannot cross the bridge. They go to the warehouse, defeat the boss, and earn the `boss_defeated` flag. Upon returning to the bridge, `grunt_1` instantly vanishes from the world state forever.

### Example 2: The Fetch Quest Chain
1.  **Town Mayor (`mayor`)**: `scriptType: 'fetch_quest'`, `dialogue: ["The bridge is broken! Bring me 5 Wood!"]`, `itemRequiredId: 'wood'`, `itemRequiredCount`: 5, `itemRewardId`: 'gold_coin', `itemRewardCount`: 100, `setsFlag: 'bridge_repaired'`, `postEventDialogue: ["Thank you! The bridge is safe."]`.
2.  **Bridge Guard (`bridge_guard`)**: `scriptType: 'blocker'`, `requiredFlag: 'bridge_repaired'`.
*   **Flow**: The mayor takes your 5 wood, gives you money, and sets a game-wide flag. The guard sees this flag and deletes himself, clearing the path forward.

### Example 3: Professor Anidex Evaluation
1.  **Professor Oak (`prof_oak`)**: `scriptType: 'professor'`, `dialogue: ["Go catch 10 species!"]`, `itemRequiredCount`: 10, `itemRewardId`: 'master_ball', `itemRewardCount`: 1.
*   **Flow**: The engine sees he is a 'professor' type. It checks `user.discoveredOrganisms.length`. If you have >= 10, he hands you 1 Master Ball, sets a custom milestone flag locally to his ID (`prof_oak_milestone`), and thanks you forever.

---

## 4. Under the Hood: The Event Flags Engine
Everything interacts globally. `UserState` writes the map and flag status directly to `user_data.json` instantaneously whenever you:
- Step out of a map boundary (Saves `currentMapId` and `defeatedNpcIds`).
- Close or minimize the app on your phone (Saves current position dynamically so you can resume mid-town seamlessly).
- Finish a battle (Saves Trainer defat status).
- Speak to an Item/Quest Giver (Updates Inventory and flags).

Because the world persists on disk per-action, branching narratives will never glitch or repeat dialogues if a user crashes or hard-quits immediately after an event.
