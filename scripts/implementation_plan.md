# Align Training Battle Interface

The goal is to update the `TrainingBattleScreen` to achieve visual parity with `BattleScreen`. Specifically, we need to match animal positioning, platform rendering, and the overall layered battlefield layout.

## Proposed Changes

### [TrainingBattleScreen](file:///C:/Users/USER/dev/animal_warfare/lib/training_battle_screen.dart)

#### [MODIFY] [training_battle_screen.dart](file:///C:/Users/USER/dev/animal_warfare/lib/training_battle_screen.dart)

- Refactor `_buildField` to use the same layout structure as `BattleScreen`.
- Incorporate `_BattleSprite` (or equivalent logic) for rendering animals on platforms.
- Ensure `_buildOpponentStatus` and `_buildPlayerStatus` are positioned correctly within a responsive stack.
- Match the background rendering and "layered" feel of the standard battle.

## Verification Plan

### Manual Verification
- Launch Training Mode.
- Verify that the player animal and the training dummy are positioned exactly like in a standard battle.
- Confirm platforms are rendered correctly under both participants.
- Check responsiveness on both landscape and portrait orientations.
