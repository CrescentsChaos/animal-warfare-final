# How to Customize Move Audio

This guide shows you exactly how to add custom sounds and music to any move in your game.

## Quick Start: Adding Sound to "Scratch"

To change the sound effect for the "Scratch" move, simply add the `soundEffect` parameter:

```dart
Move(
  name: 'Scratch',
  description: 'A basic attack.',
  baseDamage: 10,
  type: ElementalType.normal,
  stamina: 35,
  accuracy: 100,
  category: MoveCategory.physical,
  soundEffect: 'audio/effects/scratch_sound.mp3', // 👈 Add your custom sound!
  effects: [],
),
```

## Adding Custom Battle Music

For epic moves like "Death Roll", you can change the entire battle music:

```dart
Move(
  name: 'Death Roll',
  description: 'The user grabs the target and spins violently.',
  baseDamage: 80,
  type: ElementalType.aquatic,
  stamina: 5,
  category: MoveCategory.physical,
  soundEffect: 'audio/effects/death_roll.mp3',      // Custom sound effect
  battleMusic: 'audio/intense_battle.mp3',          // Custom battle music
  effects: [
    MoveEffect(
      type: MoveEffectType.statChange,
      target: 'opponent',
      stat: 'defense',
      value: -1,
      chance: 40,
    ),
  ],
),
```

## Where to Put Audio Files

Place your audio files in the following structure:

```
assets/audio/
├── effects/                # Sound effects go here
│   ├── scratch_sound.mp3
│   ├── death_roll.mp3
│   ├── thunder_crash.mp3
│   └── ... (your custom sounds)
│
└── intense_battle.mp3      # Battle music goes here
    epic_fight.mp3
    ... (your custom music)
```

## Default Sounds (If You Don't Specify)

If you don't add a `soundEffect`, the game uses these defaults:

- **Physical moves** → `assets/audio/effects/physical_attack.mp3`
- **Special moves** → `assets/audio/effects/special_attack.mp3`
- **Status moves** → `assets/audio/effects/status_move.mp3`
- **Battle music** → `assets/audio/battle_default.mp3`

## Full Example: Thunder Move

Here's a complete example with custom sound and music:

```dart
Move(
  name: 'Thunder',
  description: 'A massive bolt of lightning crashes down.',
  baseDamage: 110,
  accuracy: 70,
  type: ElementalType.electric,
  stamina: 10,
  category: MoveCategory.special,
  soundEffect: 'audio/effects/thunder_boom.mp3',
  battleMusic: 'audio/storm_battle.mp3',
  effects: [
    MoveEffect(
      type: MoveEffectType.statusParalysis,
      target: 'opponent',
      chance: 30,
    ),
  ],
),
```

## Loading from JSON

You can also define move audio in JSON files:

```json
{
  "name": "Tackle",
  "baseDamage": 40,
  "type": "normal",
  "category": "physical",
  "soundEffect": "audio/effects/tackle_hit.mp3",
  "battleMusic": "audio/battle_intense.mp3"
}
```

The game will automatically load these values when reading your move data!

## Tips

1. **Audio formats**: Use MP3 format (matches existing game audio)
2. **Sound effects**: Keep them short (< 1 second) for responsive gameplay
3. **Battle music**: Should loop smoothly (2-3 minutes recommended)
4. **File size**: Compress audio to keep app size manageable
5. **Testing**: Test each move in battle to ensure audio plays correctly

## What Happens When

- **Battle starts** → Default battle music plays
- **Move used** → Sound effect plays (custom or category default)
- **Move with custom music** → Battle music switches to that track
- **Battle ends** → All audio stops and resources are cleaned up

That's it! You now have complete control over every move's sound. 🎵
