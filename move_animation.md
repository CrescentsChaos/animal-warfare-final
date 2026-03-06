# How to Add a Custom Move Animation

Welcome! This guide explains step by step how to give any move in the game its own unique attack animation. You don't need to be an advanced developer — just follow along.

---

## 🗺️ Overview: What Makes an Animation?

When an animal uses a move in battle, the game does two things:

1. **Picks a visual effect** — a flying projectile, a slash, a beam, falling rocks, etc.
2. **Plays a sound** (optional)

Both of these are controlled by a single field in the move's JSON called `animationType`.

---

## 📂 Files You'll Work With

| File | What it does |
|---|---|
| `assets/moves.json` | Defines every move's stats AND its `animationType` |
| `lib/game/move_animations.dart` | Contains all the visual effect widgets |
| `assets/move_effects/` | Folder with PNG images used by animations |

---

## 🎬 Step 1 — Choose or Add Your Move in `moves.json`

Open `assets/moves.json`. Every move looks like this:

```json
{
    "name": "Flamethrower",
    "description": "The user breathes a stream of fire.",
    "baseDamage": 90,
    "type": "blaze",
    "accuracy": 100,
    "stamina": 15,
    "category": "special",
    "animationType": "blob",
    "effects": [
        {
            "type": "statusBurn",
            "target": "opponent",
            "chance": 10
        }
    ]
}
```

The key line is `"animationType": "blob"`. This tells the game which visual effect to play.

If your move already exists in the file, just find it and add the `animationType` field. If the move is brand new, add a whole new entry like the example above.

> **Tip:** The `animationType` field is optional. If you leave it out, the game uses a default procedural animation based on the move's `type` and `category` (e.g. physical moves get a slash impact, special moves get a projectile).

---

## 🎨 Step 2 — Pick an Animation Type

Here are all the built-in animation types you can use right now:

| `animationType` value | What it looks like | Best for |
|---|---|---|
| `blob` | Stream of blobs flying toward the target. Automatically shows flame blobs for fire-type moves, water pulses for moves with "pulse" in the name. | Flamethrower, Water Pulse, Aqua Jet |
| `slash` | A slashing image sweeps across the target. Uses a dark night-slash image for `darkness` type, otherwise an air slash. | Air Slash, Night Slash |
| `brave_bird` | A bird sprite dives diagonally into the target at high speed. | Brave Bird, Sky Dive |
| `bite` | Two jaw images snap together on the target. | Venomous Fang, Ice Fang, Bite |
| `melee` | A punch or kick image slams into the target. Auto-picks kick if move name contains "kick", otherwise punch. | Any punch/kick move |
| `close_combat` | Multiple rapid hits flash on the target in quick succession. | Close Combat, Burst Strike |
| `elemental_melee` | A punch/kick followed by blobs of elemental energy. Good for charged elemental strikes. | Fire Punch, Ice Punch, Thunder Punch |
| `rock` | Multiple rocks fall down from above onto the target. | Rock Slide, Stone Edge, Stealth Rock |
| `ice_beam` | A stream of ice particles travels in a diagonal beam toward the target. | Any beam-style ice move |
| `ice_beam_column` | Ice particles appear in a column/line from attacker to target, sequentially. | Ice Beam |
| `ice_shard` | Three ice shard images fly quickly toward the target. | Ice Shard, Quick Attack (cryo variant) |
| `ice_shard_single` | A single ice shard shoots toward the target. | Fast single projectile |
| `fire_fang` | Jaw images with fire particles scattered on impact. | Fire Fang |
| `aqua_fang` | Jaw images with water particles scattered around. | Crunch (aquatic variant) |
| `water_spout` | Jets of water shoot up dramatically from below. | Water Spout |
| `eruption` | Fire and rock jet up from below like a volcano. | Eruption |
| *(none / omitted)* | Default procedural animation: physical moves get a hit flash, special moves get a projectile based on elemental type, status moves get an aura glow. | Any move without a special animation |

---

## ✅ Step 3 — Apply the Animation

This is the easy part. Just add `"animationType"` to your move in `moves.json`.

**Example: Making Rock Slide use the rock animation**

Find `Rock Slide` in `moves.json`:

```json
{
    "name": "Rock Slide",
    "description": "May cause flinching.",
    "baseDamage": 75,
    "type": "rock",
    "accuracy": 90,
    "stamina": 15,
    "category": "physical",
    "effects": [...]
}
```

Add the `animationType` field:

```json
{
    "name": "Rock Slide",
    "description": "May cause flinching.",
    "baseDamage": 75,
    "type": "rock",
    "accuracy": 90,
    "stamina": 15,
    "category": "physical",
    "animationType": "rock",
    "effects": [...]
}
```

Done! Hot reload or restart the app and the animation will play.

---

## 🔊 Step 4 — Optionally Add a Sound Effect

You can also make the move play a sound by adding a `soundEffect` field pointing to a file in `assets/audio/effects/`:

```json
{
    "name": "Flamethrower",
    "animationType": "blob",
    "soundEffect": "audio/effects/flamethrower.mp3",
    ...
}
```

The sound will play automatically when the move animation starts.

---

## 🛠️ Step 5 — Creating a Brand New Animation (Advanced)

If none of the built-in animation types fit your move, you can create a completely new one. Here's how:

### 5a. Add a new widget in `move_animations.dart`

Open `lib/game/move_animations.dart`. Scroll to the top — you'll see a series of effect classes like `BlobStreamEffect`, `SlashEffect`, `RockEffect`, etc.

Copy the structure of any existing one and change the drawing logic. Here's a minimal template:

```dart
// ----------------------------------------------------------------
// My Custom Effect
// ----------------------------------------------------------------
class MyCustomEffect extends StatelessWidget {
  final double progress; // 0.0 (start) → 1.0 (end)
  final bool isPlayer;   // true = player attacking, false = opponent

  const MyCustomEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    // Example: a simple image that flies from attacker to target
    final cx = size / 2;
    final cy = size / 2;

    double startX = cx - 180; // comes from the left (player)
    double startY = cy + 180;
    if (!isPlayer) {
      startX = cx + 180; // comes from the right (opponent)
      startY = cy - 180;
    }

    final currentX = startX + (cx - startX) * p;
    final currentY = startY + (cy - startY) * p;
    final opacity = p > 0.8 ? (1.0 - p) / 0.2 : 1.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: currentX - 20,
            top: currentY - 20,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Image.asset(
                'assets/move_effects/flame.png', // use any image from assets/move_effects/
                width: 40,
                height: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

> **How `progress` works:** It goes from `0.0` to `1.0` over the course of the animation (about 3.5 seconds). You use it to move things around, change opacity, and control timing.

### 5b. Register the new animation type

Inside the same file (`move_animations.dart`), find the `build()` method of `_MoveAnimationOverlayState` (around line 867). You'll see a series of `if` blocks like this:

```dart
if (move.animationType == 'blob') {
  // ... BlobStreamEffect used here
}

if (move.animationType == 'slash') {
  // ... SlashEffect used here
}
```

Add a new block at the end, before the `// Default procedural animation fallback` comment:

```dart
if (move.animationType == 'my_custom') {
  return AnimatedBuilder(
    animation: _progress,
    builder: (context, _) {
      return CompositedTransformFollower(
        link: targetLink,
        showWhenUnlinked: false,
        followerAnchor: Alignment.center,
        targetAnchor: Alignment.center,
        child: MyCustomEffect(
          progress: _progress.value,
          isPlayer: isPlayer,
        ),
      );
    },
  );
}
```

### 5c. Add it to your move in `moves.json`

```json
{
    "name": "My Cool Move",
    "animationType": "my_custom",
    ...
}
```

---

## 🖼️ Available Images in `assets/move_effects/`

These PNG images can be used inside animation widgets:

| Filename | Description |
|---|---|
| `flame.png` | Orange/red flame blob |
| `aqua.png` | Blue water droplet |
| `water_pulse.png` | Wide rippling water pulse |
| `ice.png` | Ice shard crystal |
| `rock.png` | Brown jagged rock chunk |
| `air_slash.png` | White curved slash mark |
| `night_slash.png` | Dark purple slash mark |
| `punch.png` | Fist impact image |
| `kick.png` | Foot impact image |
| `upper_jaw.png` | Top half of biting jaw |
| `lower_jaw.png` | Bottom half of biting jaw |
| `bird.png` | Bird sprite (used for Brave Bird) |

To add your own image, drop a PNG into `assets/move_effects/` and make sure it's registered in `pubspec.yaml` under `assets:` (the whole folder is usually listed, so new files auto-include).

---

## 🧪 Quick Reference Cheat Sheet

```
Move wants a...              →  Use animationType:
─────────────────────────────────────────────────────
Flame / projectile stream    →  blob
Air / wing slash             →  slash
High-speed dive              →  brave_bird
Jaw snap attack              →  bite
Punch or kick                →  melee
Elemental charged strike     →  elemental_melee
Rapid combo                  →  close_combat
Falling rocks                →  rock
Ice crystal stream           →  ice_beam
Ice column spread            →  ice_beam_column
Ice shards x3                →  ice_shard
Single ice shard             →  ice_shard_single
Flaming bite                 →  fire_fang
Water bite                   →  aqua_fang
Upward water jets            →  water_spout
Upward fire/rock jets        →  eruption
```

---

That's everything you need! The simplest way to get started is just adding `"animationType": "blob"` to any move and watching it come alive in battle. Good luck! 🦁⚔️🦈
