# Battle Screen Documentation Guide

This document provides a comprehensive breakdown of `lib/battle_screen.dart`, detailing its UI architecture, state management, and individual components. Use this guide to customize the visual appearance, layout, and interactive elements of the battle experience.

---

## 🏗️ Architecture Overview

The Battle Screen is a complex, multi-layered interface that manages real-time battle state and animations.

-   **Layering**: The UI uses a `Stack` to layer background images, weather/terrain overlays, sprites, and animation overlays.
-   **State Management**: It relies heavily on `Provider` to listen to `BattleManager` (state) and `UserState` (persistence).
-   **Responsiveness**: Uses `isNarrow` flag (screenWidth < 360) and `OrientationBuilder` to adapt between portrait and landscape modes.

---

## 🎨 UI Layout & Layers

### 1. Background System
The background is dynamically determined in `_getAssetPath(biomeName)` and modified by the current time-of-day.
-   **Lighting Filters**: `StreamBuilder<GameTime>` applies `ColorFilter` to the background image based on hour (Day, Evening, Night).
-   **Biome Themes**: Primary, Secondary, and Accent colors are derived from the biome name via `_getBiomePrimaryColor()`, `_getBiomeSecondaryColor()`, and `_getBiomeThemeColor()`.

### 2. Environmental Overlays
Visual effects are layered directly over the background:
-   **Weather**: Managed by `WeatherOverlay`.
-   **Terrain**: Managed by `TerrainOverlay`.
-   **Trick Room**: A distinct purple overlay active when `trickRoomTurns > 0`.
-   **Tailwind**: Wind effects active when either side has `tailwindTurns > 0`.

---

## 🧪 Core UI Components

### 📊 Participant Status Bars
The `_buildPlayerStatus` and `_buildOpponentStatus` methods handle the health and info plates.

-   **Health Bar**: A `LinearProgressIndicator` wrapped in a `TweenAnimationBuilder` for smooth HP sliding.
    -   **Colors**: Green (>50%), Orange (>20%), Red (<=20%).
-   **Stamina/XP**: Player-exclusive bars for tracking resource management and level progress.
-   **Team Indicators**: Small circles (`_buildPlayerTeamIndicator`) showing remaining healthy animals in the party.
-   **Status Icons**: Tappable badges for active status effects (Poisoned, Asleep, etc.) with long-press descriptions.

### ⚔️ Action Controls
The `_buildActionControls` widget is the primary interaction hub.

-   **Move Buttons**: Grid of buttons representing the active animal's move-set.
    -   **Visuals**: Colored by move type; includes effectiveness indicators (e.g., "Super Effective!").
    -   **Interaction**: Tap to use, long-press for detailed move info (`_showMoveDetails`).
-   **Gimmick Buttons**: Large, stylized buttons for **Prismorph** and **Titanize** activation.
-   **Utility Buttons**: Switch, Net (Capture), Release, and Run/Forfeit.

### 💬 Message System
The `_buildMessageBox` handles the battle log with a typewriter effect.

-   **Speed Control**: Default 50ms per character.
-   **Fast Mode**: Users can long-press the message box to speed up the text significantly.
-   **Scrolling**: Automatically scrolls to the latest log entry.

---

## 👾 Visual Effects & Animations

### 🖼️ _BattleSprite Component
The `_BattleSprite` handles rendering of the animal images.

-   **Outline Logic**: Uses 8 layered offsets to create a crisp, thick outline around the animal sprite.
-   **Animations**:
    -   **Entry**: Elastic "pop-in" effect.
    -   **Bounce**: Subtle idle breathing animation (`_pulseController`).
    -   **Faint**: White flash followed by fading opacity.
    -   **Pulse**: Crystalline shimmer effect used specifically for **Prismorph** state.
-   **Hazards**: Visualizes entry hazards like Spikes or Sticky Web directly on the animal's platform.

### 💥 Battle Animations
-   **Move Animations**: Triggered via `_onAttack` callback, using `anims.MoveAnimationOverlay`.
-   **Screen Shake**: Triggered by high-impact moves (e.g., Earthquake) via `_runScreenShake()`.
-   **Indicators**: Floating damage/heal numbers and stat change arrows (`_FloatingIndicatorWidget`).

---

## 🛠️ Code Customization Cheat Sheet

Use this table to quickly find the code responsible for specific UI elements in `lib/battle_screen.dart`.

| UI Element | Method / Class | Line Range (Approx.) |
| :--- | :--- | :--- |
| **Main Layout** | `_BattleScreenContentState.build` | 1104 - 1459 |
| **Top Header** | `_buildHeader` | 1461 - 1578 |
| **Field Effects** | `_buildFieldEffects` | 1580 - 1710 |
| **Opponent Status** | `_buildOpponentStatus` | 1904 - 2134 |
| **Player Status** | `_buildPlayerStatus` | 2136 - 2365 |
| **Message Box** | `_buildMessageBox` | 2367 - 2435 |
| **Action Controls** | `_buildActionControls` | 2562 - 3165 |
| **Move Buttons** | Inside `_buildActionControls` | 2673 - 2874 |
| **Prismorph Button**| Inside `_buildActionControls` | 2879 - 2953 |
| **Animal Sprites** | `_BattleSpriteState` | 5244 - 5876 |
| **Typewriter Text**| `TypewriterText` | 6043 - 6115 |

---

## 👨‍💻 Detailed How-To Guides

### 1. How to move the HP Bars / Status Plates
The status plates are positioned within the `Column` inside the `Participant area` (lines 1301-1380).
- **To swap positions**: Swap the order of `_buildOpponentStatus` and `_buildPlayerStatus` calls in the `Column`.
- **To adjust padding/margins**: Look for the `Padding` wrapping the `statusBox` inside `_buildPlayerStatus` (Line 2302) or `_buildOpponentStatus` (Line 2069).

### 2. How to change Move Button colors/shapes
Move buttons are generated in `_buildActionControls` (Line 2701).
- **Colors**: Change the `backgroundColor` logic (Line 2712). Currently, it uses `typeColor`.
- **Shapes**: Modify the `RoundedRectangleBorder` (Line 2720). Increase `borderRadius` for rounder buttons.
- **Size**: Adjust the `childAspectRatio` in the `GridView.count` (Line 2664).

### 3. How to resize the Animal Sprites
Sprite sizes are calculated responsively at the start of the status build methods.
- **Opponent**: Edit `spriteSize` on Line 1922.
- **Player**: Edit `spriteSize` on Line 2153.
- **Platform Size**: To adjust the platform diameter, edit the `width` and `height` of the `Container` in `_BattleSpriteState.build` (Line 5728).

### 4. How to edit the Background Filters (Time of Day)
The background lighting effect is managed by the `StreamBuilder` in the main `build` method.
- **Logic**: Find the `ColorFilter.mode` calls (Lines 1157-1167).
- **Customization**: You can change `Colors.orangeAccent` (Evening) or `Colors.indigo` (Night) to adjust the ambient mood.

### 5. How to add new UI Overlays
To add a persistent UI element (like a score counter or a new button):
1.  **Add a new method**: e.g., `Widget _buildMyNewWidget() { ... }`.
2.  **Insert into Stack**: Add it to the main `Stack` in the `build` method (Line 1142). If it's a fixed element, wrap it in a `Positioned` or `Align` widget.

### 6. Adjusting Health Bar Animation Speed
Find the `TweenAnimationBuilder` in `_buildPlayerStatus` (Line 2197) or `_buildOpponentStatus` (Line 1965).
-   **Change Duration**: Edit `duration: const Duration(milliseconds: 1200)`. Lower values make the bar move faster.

---

> [!IMPORTANT]
> **Safe Listener Pattern**: When adding new UI updates that depend on `BattleManager` state changes, always wrap your `setState` calls in `WidgetsBinding.instance.addPostFrameCallback` to avoid "markNeedsBuild during build" errors. See `_handleStateTriggers` (Line 316) for an example.
