# Animal Warfare 🐾

> **A tactical turn-based creature battle game with a retro pixel-art aesthetic, combining education with strategic gameplay.**

A feature-rich **Flutter-based mobile application** that immerses players in a biologically-inspired world of tactical creature battles. Explore real-world ecosystems, discover exotic organisms, develop strategic teams, and master combat mechanics through engaging gameplay.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Core Features](#-core-features)
- [Game Mechanics](#-game-mechanics)
- [Technical Architecture](#-technical-architecture)
- [Installation & Setup](#-installation--setup)
- [Project Structure](#-project-structure)
- [Dependencies](#-dependencies)
- [Development](#-development)
- [Future Roadmap](#-future-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## Overview

**Animal Warfare** seamlessly blends education with entertainment, offering players a unique monster-battler experience grounded in real biology. The game features:

- **200+ Real Organisms** with scientific names and realistic habitat distributions
- **Strategic Turn-Based Combat** with elemental types, abilities, and tactical depth
- **Biome-Based Exploration** across diverse real-world ecosystems with environmental mechanics
- **Retro Aesthetic** with pixel-art sprites, PressStart2P typography, and high-contrast UI
- **Persistent Progression** with cloud synchronization and achievement tracking
- **Educational Components** including an integrated Quiz Lab for biology learning

---

## ✨ Core Features

### 🌍 **Dynamic Biome Exploration**
Venture into meticulously crafted real-world biomes and discover organisms based on scientific habitat data.

- **Multiple Biome Types**: Swamp, Desert, Rainforest, Ocean, Savanna, Urban, Arctic, Mountains, and more
- **Unique Visual Theming**: Each biome features custom color palettes, background artwork, and atmospheric design
- **Dynamic Audio**: Biome-specific ambient music and environmental sound effects
- **Weighted Encounter System**: Discover organisms based on:
  - **Rarity Tiers**: Common → Uncommon → Rare → Epic → Legendary → Mythical
  - **Habitat Distribution**: Realistic species spawn probabilities based on biome ecosystem data
  - **Time-based Spawning**: Diurnal/nocturnal organisms appear dynamically

### ⚔️ **Strategic Turn-Based Battle System**
Engage in deep tactical combat with multi-layered strategic mechanics.

**Core Battle Features:**
- **Turn-Based Mechanics**: Simultaneous speed-stat resolution for dramatic moments
- **Team Composition**: Deploy customized teams of captured organisms for maximum synergy
- **Individual Values (IVs)**: Every captured organism has unique stats:
  - Health (HP)
  - Attack
  - Defense
  - Special Attack
  - Special Defense
  - Speed
- **Move System**: 
  - 4-move limit per organism
  - Move Power Points (PP) mechanic for strategic resource management
  - Fallback "Struggle" move when PP depleted
  - Custom move database with 100+ unique moves
- **Elemental Type System**: 
  - 12+ elemental types with rock-paper-scissors advantage mechanics
  - Type effectiveness calculations for attack multipliers
  - Strategic team building around type coverage
- **Passive Abilities**: 
  - 50+ unique creature abilities affecting battle dynamics
  - In-battle passive triggers (stat changes, status immunities, damage reduction)
  - Ability synergy opportunities for advanced players
- **Status Effects**: 
  - Poison, Burn, Freeze, Sleep, Paralysis, and custom status conditions
  - Visual status overlays and gameplay impact
  - Recovery through moves and items

### 🧬 **Advanced Battle Mechanics**

**Environmental Interactions:**
- **Weather Systems**: Rain, Hail, Harsh Sunlight, Sandstorm with mechanical effects
  - Type-specific advantages (Water in Rain, Fire in Sunlight)
  - Damage modifications and accuracy changes
- **Terrain Effects**: Grassland, Electric, Psychic, Misty terrain modifications
  - Speed bonuses, stat changes, type coverage advantages
- **Damage Calculations**: Accurate stat-based formulas with critical hit system
- **Strategy Depth**: 
  - Switch mechanics for tactical repositioning
  - Item usage in battle for healing/buffing
  - Move chaining and synergy

### 🎯 **Dual Stamina Systems**

1. **Exploration Stamina** (Player-level)
   - Manages exploration action capacity
   - Regenerates automatically over time
   - Required for biome encounters and organism identification

2. **Move Stamina** (Move-specific)
   - Power Points (PP) per move (5-40 depending on move)
   - Depletes with each move use
   - Strategic resource management during extended battles
   - "Struggle" fallback when all moves exhausted

### 📦 **Comprehensive Creature Management**

**Animal Box System:**
- Store and manage unlimited captured organisms
- View complete creature stats and moveset details
- Sort by rarity, type, level, and custom criteria
- Quick-access favorites system

**Move Customization:**
- Learn moves from organism's natural pool
- Swap moves dynamically before battles
- Move pool displays power, accuracy, and PP information
- Move type and category information

**Team Building:**
- 6-slot party system for exploration and combat
- Drag-and-drop interface for team arrangement
- Auto-generated suggested teams based on synergy
- Battle-ready team verification

### 📖 **Comprehensive Creature Index (AniDex)**

Track your collection progress with the integrated creature encyclopedia:
- **Discovery Tracking**: Record all encountered organisms
- **Collection Completion**: Visual progress tracking toward 100% completion
- **Detailed Organism Information**:
  - Scientific names for educational value
  - Habitat distribution across biomes
  - Move pools and ability information
  - Type matchup guide
  - Rarity classification
- **Search & Filter**: Find organisms by:
  - Name or scientific name
  - Type
  - Rarity
  - Habitat/Biome
  - Ability
- **Organism Details**: Complete stats, moves, abilities, and lore descriptions

### 🧪 **Educational Quiz Lab**

Master biological knowledge through interactive challenges:

**Quiz Modes:**
1. **Scientific Name Identification**: Match organisms to their scientific names
2. **Sprite Identification**: Identify creatures from pixel art sprites
3. **Silhouette Recognition**: Test pattern recognition with creature outlines
4. **Biome Knowledge**: Answer questions about habitat and ecosystem facts

**Progression System:**
- Experience points (XP) earned per correct answer
- Performance tracking and statistics
- Difficulty progression with scaling challenges
- Achievement rewards for quiz milestones
- Leaderboard integration (future)

### 🏆 **Achievement & Quest System**

Comprehensive goal-tracking and reward system:

**Achievement Categories:**
- **Combat Achievements**: Victory milestones, battle types won
- **Collection Achievements**: Creature discovery targets
- **Quiz Achievements**: Education-based unlocks
- **Exploration Achievements**: Biome completion

**Quest System:**
- Daily/weekly challenging missions
- Progressive quest chains with narrative elements
- Reward scaling based on difficulty
- Custom quest generators for varied gameplay

### 🎁 **Crafting & Item System**

Develop creatures and craft powerful items:

**Crafting Station Features:**
- Recipe-based crafting system
- Item transmutation mechanics
- Ingredient gathering from battle drops
- Talisman creation and enhancement
- Upgrade tree progression

**Talisman System:**
- 50+ unique talismans (hold items)
- Stat modification effects
- Special passive effects during combat
- Rarity-based item distribution
- Drop table integration with battle rewards

### 👤 **User Profile & Progression**

Track your journey with comprehensive statistics:

- **Player Level** with XP progression
- **Playtime Tracking**: Total hours invested
- **Battle Statistics**: 
  - Wins/losses/draw records
  - Trainer rankings
  - Regional leaderboard positions
- **Collection Stats**:
  - Creatures captured
  - Pokedex completion percentage
  - Shiny rate statistics
- **Custom Profiles**:
  - Avatar customization
  - Title/badge display
  - Bio and player information

### ⚙️ **Game Modes**

**Standard Mode:**
- Free exploration across biomes
- Encounter wild organisms
- Build team and battle strategically
- Progress through creature collection

**Arena Mode:**
- Competitive battles against AI trainers
- Pre-built challenging teams
- Rank progression system
- Reward scaling with difficulty

**Rogue-Like Mode:**
- Procedurally generated challenge runs
- Limited resources and strategic constraints
- Wave-based progression system
- High-difficulty tactical gameplay

**Double Battle Mode:**
- 2v2 team-based combat system
- Synchronized creature movements
- Field-wide weather/terrain effects
- Cooperative and competitive variants

### 🔐 **User Authentication & Data**

- **Firebase Integration**: Secure cloud authentication
- **Local Auth Fallback**: Offline account creation and management
- **Persistent Storage**: Local JSON-based data with auto-sync
- **Progress Synchronization**: Cross-device save state support
- **Data Export**: Backup and restore functionality

### 🎨 **Visual Design**

**Retro Pixel-Art Aesthetic:**
- Custom 32x32 pixel creature sprites
- PressStart2P typography for authentic retro feel
- High-contrast color palettes for accessibility
- Smooth animations and pixel-perfect rendering
- Military-themed UI borders and elements

**Responsive Layout:**
- FlutterScreenUtil for multi-device support
- Adaptive UI scaling from phones to tablets
- Portrait and landscape orientation support
- Safe area handling for notched devices

---

## 🎮 Game Mechanics

### Combat Flow

1. **Encounter Generation**
   - Wild organism spawned based on biome rarity weighting
   - Stats calculated with IV generation
   - Moves randomly selected from move pool

2. **Battle Initialization**
   - Player selects team creature or captures wild organism
   - Turn order determined by Speed stats
   - Initial weather/terrain effects applied

3. **Turn Resolution**
   - Players choose action (Move, Switch, Item, Capture)
   - Speed-stat ordering determines action sequence
   - Damage calculations with STAB, type, ability modifiers
   - Status effects applied and damage processed
   - End-of-turn effects resolved (weather, terrain, ability effects)

4. **Battle Conclusion**
   - Experience points awarded
   - Stat growth applied
   - Items and currency dropped
   - Shiny rate calculation and notification

### Capture Mechanics

- **Capture Rate**: Determined by:
  - Current HP percentage (lower = higher chance)
  - Status conditions (paralysis, sleep boost capture)
  - Capture item used
  - Creature's base capture rate
- **IV Assignment**: Random stat generation on successful capture
- **Move Pool**: Learns up to 4 moves from natural move set

### Leveling & Stat Growth

- **Experience Gain**: Calculated from opponent stats and player level
- **Base Stats**: Inherent stats per species
- **IV System**: Individual value impact on final stat calculation
- **EV Farming**: Optional stat specialization system (future)
- **Nature Bonuses**: Stat multipliers based on creature nature (future)

---

## 🛠️ Technical Architecture

### Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter (Dart) | Cross-platform mobile UI |
| **State Management** | Provider 6.1+ | Reactive state and business logic |
| **Authentication** | Firebase Auth + Custom | User account management |
| **Storage** | Firebase + Local JSON | Data persistence and sync |
| **Audio** | Audioplayers 6.5+ | Music and sound effects |
| **UI Framework** | Material Design | Material Design components |
| **Utilities** | FlutterScreenUtil | Responsive layout |

### Architecture Patterns

**Model-View-ViewModel (MVVM):**
- Clear separation of concerns
- Business logic in service classes
- UI logic in stateful widgets

**State Management with Provider:**
- `UserState` provider for global user data
- `RogueState` for rogue mode progression
- Battle state managed in `BattleManager`
- Responsive UI updates on state changes

**Asset Management:**
- JSON-based data files for organisms, moves, abilities
- Lazy loading of image assets for performance
- Audio asset preloading on startup

### Core Model Classes

```
User
├── CapturedOrganism (party member)
├── Achievement
├── Quest
├── PlayerHistory (stats)
└── Equipment (talismans)

Organism (wild encounter base)
├── ElementalType
├── Ability
├── Move
├── Nature
└── StatusEffect

Battle
├── BattleManager (orchestration)
├── BattleModel (state container)
├── AIDecisionEngine (opponent logic)
└── Weather/Terrain (environmental effects)
```

### File Organization

```
lib/
├── main.dart                    # App entry point
├── splash_screen.dart           # Loading/auth splash
├── login_screen.dart            # Authentication UI
├── game_screen.dart             # Main hub/navigation
├── models/                      # Data models
│   ├── organism.dart
│   ├── captured_organism.dart
│   ├── move.dart
│   ├── ability.dart
│   ├── achievement.dart
│   ├── quest.dart
│   └── ...
├── game/                        # Game logic
│   ├── battle_manager.dart
│   ├── ai_decision_engine.dart
│   ├── battle_models.dart
│   └── ...
├── services/                    # Business logic
│   ├── audio_service.dart
│   ├── local_auth_service.dart
│   └── achievement_service.dart
├── widgets/                     # Reusable UI components
│   ├── organism_sprite_widget.dart
│   ├── weather_overlay.dart
│   └── ...
├── screens/                     # Feature screens
│   ├── explore_screen.dart
│   ├── battle_screen.dart
│   ├── anidex_screen.dart
│   ├── quiz_game_screen.dart
│   └── ...
├── user_state.dart              # Global state provider
├── theme.dart                   # Design system
└── utils/                       # Utilities
```

---

## ⚙️ Installation & Setup

### Prerequisites

- **Flutter SDK**: v3.9.2 or higher ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Dart SDK**: Included with Flutter
- **Platform Tools**:
  - **Android**: Android Studio with SDK 21+
  - **iOS**: Xcode 12+ (macOS)
  - **Web**: Chrome/Firefox with enabled developer mode

### Quick Start

1. **Clone the Repository**
   ```bash
   git clone https://github.com/CrescentsChaos/animal-warfare-final.git
   cd animal-warfare-final
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase** (Optional - for cloud features)
   - Create Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place files in appropriate platform directories

4. **Run the Application**
   ```bash
   # Default (auto-detect platform)
   flutter run
   
   # Or specify platform:
   flutter run -d chrome        # Web
   flutter run -d android       # Android emulator
   flutter run -d ios           # iOS simulator
   ```

5. **Build for Release**
   ```bash
   # Android APK
   flutter build apk --release
   
   # iOS
   flutter build ios --release
   
   # Web
   flutter build web --release
   ```

---

## 📁 Project Structure

### Asset Organization

```
assets/
├── Organisms.json           # Creature database (39K+ lines)
├── Organisms2.json          # Extended organism data
├── moves.json              # Move definitions
├── abilities.json          # Ability effects
├── achievements.json       # Achievement definitions
├── talismans.json         # Item/talisman database
├── biomes/                # Biome configuration
├── audio/
│   ├── effects/           # Sound effects
│   ├── biome_themes/      # Background music
│   └── battle_sounds/     # Combat audio
├── sprites/               # Creature pixel art
├── status_overlays/       # Status effect visuals
├── fonts/                # Custom typography
├── items/                # Item artwork
└── icon/                 # App icons
```

### Core Dart Modules

**Models** (`lib/models/`)
- Entity definitions with serialization
- Type-safe data structures
- JSON loading and conversion

**Game Logic** (`lib/game/`)
- `BattleManager`: Turn-based combat orchestration
- `AIDecisionEngine`: Opponent decision logic
- `ArchetypeTeams`: Pre-built team templates
- Weather/Terrain systems

**Services** (`lib/services/`)
- `AudioService`: Music and SFX management
- `LocalAuthService`: User authentication
- `AchievementService`: Achievement unlocking logic

**Screens** (`lib/`)
- Feature-specific UI implementation
- Routing and navigation
- Interaction handlers

---

## 📦 Dependencies

### Key Packages

```yaml
# UI & Framework
flutter: ^3.9.2
cupertino_icons: ^1.0.8
flutter_screenutil: ^5.9.3      # Responsive UI
google_fonts: ^8.0.2             # Typography

# State Management
provider: ^6.1.5+1               # Reactive state

# Backend & Auth
firebase_core: ^2.27.0           # Cloud infrastructure
firebase_auth: ^4.17.7           # Authentication

# Storage
shared_preferences: ^2.2.0       # Local storage
path_provider: ^2.1.0            # File system access

# Audio
audioplayers: ^6.5.1             # Music and sound effects

# Utilities
permission_handler: ^11.3.1      # Device permissions
image_picker: ^1.2.0             # Photo selection
url_launcher: ^6.3.0             # Link handling
file_picker: ^8.0.7              # File selection
package_info_plus: ^8.0.0        # App metadata
```

---

## 🚀 Development

### Getting Started with Development

1. **Set Up Environment**
   ```bash
   flutter doctor              # Check setup
   flutter pub upgrade         # Update dependencies
   ```

2. **Run in Debug Mode**
   ```bash
   flutter run -v              # Verbose logging
   ```

3. **Format & Lint Code**
   ```bash
   dart format lib/            # Auto-format
   dart analyze                # Static analysis
   flutter analyze             # Flutter-specific checks
   ```

4. **Run Tests**
   ```bash
   flutter test                # Unit and widget tests
   flutter test --coverage     # Coverage report
   ```

### Code Organization Guidelines

- **One class per file** (except small utilities)
- **Prefix private members** with underscore (`_privateMethod`)
- **Use const constructors** where possible
- **Document public APIs** with dartdoc comments
- **Follow Flutter style guide**: Use `flutter_lints`

### Adding New Features

**Adding a New Organism Type:**
1. Update `assets/Organisms.json` with creature data
2. Create species-specific moves in `moves.json`
3. Run `Move.loadFromJson()` and `Organism.loadFromJson()` on app init
4. Test encounter rate weighting in biome

**Creating a Battle Move:**
1. Define move in `models/move.dart`
2. Add to `assets/moves.json` with stats
3. Reference in creature move pool
4. Implement damage calculation in `BattleManager`

**Implementing New UI Screen:**
1. Create widget in `lib/screens/`
2. Add navigation route in `MainScreen`
3. Wire state management with Provider
4. Style with theme colors from `theme.dart`

---

## 🔮 Future Roadmap

### Planned Features & Enhancements

#### Phase 2: Community & Social
- [ ] **Multiplayer Battles**: Real-time PvP combat
- [ ] **Trading System**: Player-to-player creature trading
- [ ] **Guilds**: Team-based progression and events
- [ ] **Global Leaderboards**: Regional and worldwide rankings
- [ ] **Clan Wars**: Guild-based competitive events

#### Phase 3: Immersive Systems
- [ ] **Operations Base**: Customizable player headquarters
- [ ] **Creature Breeding**: Genetic inheritance system
- [ ] **Puzzle Dungeons**: Story-driven challenge modes
- [ ] **Seasonal Events**: Limited-time creatures and battles
- [ ] **Narrative Campaign**: Multi-chapter story progression

#### Phase 4: Advanced Mechanics
- [ ] **Nature System**: Stat-altering personality traits
- [ ] **EV Training**: Stat specialization mechanics
- [ ] **Competitive Tiers**: Ranked battle divisions
- [ ] **Tournament Mode**: Elimination-style competitions
- [ ] **Ability Synergy Matrix**: Team composition recommendations

#### Phase 5: Technology & Platform
- [ ] **AR Mode**: Augmented reality creature encounters
- [ ] **Haptic Feedback**: Immersive vibration patterns
- [ ] **Cloud Cross-Save**: Seamless multi-device progression
- [ ] **Web Support**: Full-featured web client
- [ ] **Offline Mode**: Complete offline gameplay

See [FUTURE_FEATURES.md](FUTURE_FEATURES.md) for detailed feature descriptions and design philosophy.

---

## 📊 Performance & Optimization

### Optimization Strategies

- **Lazy Loading**: Image assets load on-demand
- **Audio Pooling**: Sound effects reuse player instances
- **Memory Management**: Proper disposal of resources
- **UI Performance**: Efficient widget rebuilds with Provider
- **JSON Caching**: Single-load organism and move databases
- **Sprite Batching**: Optimized rendering pipeline

### Performance Targets

- **Load Time**: < 3 seconds to main screen
- **Battle FPS**: 60 FPS on mid-range devices
- **Memory**: < 150MB RAM at peak usage
- **Storage**: < 500MB on device

---

## 🐛 Troubleshooting

### Common Issues

**App won't start after update**
- Clear app cache: `flutter clean`
- Rebuild pubspec lock: `flutter pub get`
- Reinstall app: `flutter run --release`

**Audio not playing**
- Check asset paths in `pubspec.yaml`
- Verify `AudioService.instance.init()` in `main()`
- Test with device volume not muted

**Firebase errors**
- Verify Firebase configuration files
- Check Internet connectivity
- Review Firebase console for quota limits

**Battle lag or stuttering**
- Close background apps
- Reduce device load
- Report with device specs to issues

See [Issues](https://github.com/CrescentsChaos/animal-warfare-final/issues) for known bugs and workarounds.

---

## 🤝 Contributing

We welcome contributions! Whether you're fixing bugs, adding features, or improving documentation.

### Contribution Process

1. **Fork** the repository
2. **Create Feature Branch**: `git checkout -b feature/amazing-feature`
3. **Make Changes**: Follow code style guidelines
4. **Commit**: `git commit -m 'Add amazing feature'`
5. **Push**: `git push origin feature/amazing-feature`
6. **Open Pull Request**: Describe changes and reference issues

### Contribution Areas

- **New Creatures**: Research and add real organisms
- **Balancing**: Adjust move stats and battle mechanics
- **Features**: Implement from roadmap
- **Bug Fixes**: Report and fix issues
- **Documentation**: Improve README and comments
- **Localization**: Translate to new languages
- **Art**: Create sprites and UI assets

### Code Standards

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `const` constructors
- Document public methods with dartdoc
- Write descriptive commit messages
- Add tests for new functionality

---

## 📜 License

Distributed under the **MIT License**. See [LICENSE](LICENSE) file for details.

The MIT License allows:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use

Conditions:
- Include original license and copyright notice
- Include NOTICE of any modifications

---

## 📞 Support & Contact

### Get Help

- **Documentation**: Read inline comments and [FUTURE_FEATURES.md](FUTURE_FEATURES.md)
- **Issues**: [GitHub Issues](https://github.com/CrescentsChaos/animal-warfare-final/issues)
- **Discussions**: [GitHub Discussions](https://github.com/CrescentsChaos/animal-warfare-final/discussions)

### Project Links

- **Repository**: [github.com/CrescentsChaos/animal-warfare-final](https://github.com/CrescentsChaos/animal-warfare-final)
- **Issues**: Report bugs and request features
- **Releases**: Download APK and source releases

### Author

**Project Maintainer**: CrescentsChaos

---

## 🙏 Acknowledgments

- **Flutter Team**: Excellent cross-platform framework
- **Firebase**: Backend infrastructure and authentication
- **Community Contributors**: Bug reports, feature suggestions, and code
- **Real Organisms**: Inspiration from Earth's incredible biodiversity

---

## 📈 Project Statistics

- **Lines of Code**: 10,000+
- **Creatures**: 200+ real organisms
- **Moves**: 100+ unique attacks
- **Abilities**: 50+ creature abilities
- **Talismans**: 50+ collectable items
- **Biomes**: 8+ unique environments
- **Platforms Supported**: Android, iOS, Web

---

**Happy battling! 🎮🐾**

*Last Updated: February 2026*
