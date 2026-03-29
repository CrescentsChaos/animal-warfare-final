# Phase 3: Animations & Polish - Double Battle System

This phase focuses on visual excellence and game feel for the 2v2 combat. We will adapt the existing 1v1 animation system to handle multiple attackers and targets, and add smooth transitions for health and status changes.

## User Review Required

> [!IMPORTANT]
> **Animation Refactor**: I will be modifying the core `MoveAnimData` structure in `move_animations.dart`. This might affect 1v1 battles if not handled carefully. I will ensure backward compatibility by making new fields optional or using defaults.

> [!WARNING]
> **Performance**: Rendering up to 4 simultaneous animations (e.g., a "Surf" hitting two targets while two others react) might impact lower-end performance. I will optimize by ensuring animations are disposed of immediately upon completion.

## Proposed Changes

### Move Animation System
We need to move away from hardcoded "bottom-left" to "top-right" trajectories.

#### [MODIFY] [move_animations.dart](file:///c:/Users/USER/dev/animal_warfare/lib/game/move_animations.dart)
- Update `MoveAnimData` to include `attackerSlot` (0 or 1) and `targetSlot` (0 or 1).
- Refactor `BlobStreamEffect`, `SlashEffect`, and `MeleeEffect` to accept `attackerPosition` and `targetPosition` (Offsets) instead of using hardcoded numbers.
- Add a helper to calculate screen offsets based on the 4 `LayerLink` positions.

#### [MODIFY] [double_battle_screen.dart](file:///c:/Users/USER/dev/animal_warfare/lib/double_battle_screen.dart)
- Implement `_onAttack`, `_onDamage`, and `_onHeal` callbacks.
- Add a `Stack` layer for `MoveAnimationOverlay` (reusing the logic from `BattleScreen`).
- Connect the 4 `LayerLink` objects to the animation system.

### HP & Status Polish
#### [MODIFY] [double_battle_screen.dart](file:///c:/Users/USER/dev/animal_warfare/lib/double_battle_screen.dart)
- Replace static `LinearProgressIndicator` in HP bars with a custom `TweenAnimationBuilder` for smooth health drain.
- Add a "shake" animation to the status box when an animal takes damage.

### Game Feel & Sound
#### [MODIFY] [double_battle_manager.dart](file:///c:/Users/USER/dev/animal_warfare/lib/game/double_battle_manager.dart)
- Trigger `notifyListeners()` at specific animation milestones (e.g., start of move, moment of impact).
- Ensure `AudioService` triggers are sent for hits, faints, and super-effective moves.

## Open Questions

1. **Spread Moves**: For moves like "Surf" or "Earthquake" that hit multiple targets, should we play the animation once for the whole field, or once per target?
    - *Proposed*: Play once for the field, but trigger damage "reaction" shakes for each hit target.

2. **Simultaneous Faints**: When two animals faint, do we show the "Your animal fainted" message one after another, or both at once?
    - *Proposed*: Sequential messages are better for readability of the log.

## Verification Plan

### Automated Tests
- N/A (UI focused)

### Manual Verification
- **Visual Check**: Run a Double Battle and use a targeted move (e.g., Bite) on slot 1 vs slot 2. Verify the animation hits the correct sprite.
- **Spread Test**: Use a move that hits all opponents and verify both health bars decrease smoothly.
- **Faint Test**: Knock out an opponent and verify the sprite fades out and the next one switches in correctly.
