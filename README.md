# 🐾 Animal Warfare: Biological Combat & Discovery

**Animal Warfare** is a premium, feature-rich Flutter application that blends deep biological education with engaging arcade gameplay and an expansive RPG battle and story engine. Explore a massive database of real-world species, test your knowledge in tactical quizzes, master high-speed arcade games, and embark on a grand adventure!

---

## ✨ Key Features in Detail

### 📖 **AniDex (3,000+ Organisms)**
A comprehensive encyclopedia of Earth's biodiversity that grows as you play.
- **Real Data**: Detailed entries for over 3,000+ real-world animals.
- **Advanced Taxonomy**: Search and filter by scientific names, Genus, Class, and Species classification.
- **Ecological Stats**: Learn about Diets, Habitats (24+ distinct Biomes), and Elemental Types.
- **Collection Tracking**: Monitor your discovery progress from Common to Mythical rarities.

### 🔍 **AI-Powered Biometric Scanner**
The ultimate tool for field researchers and explorers, built directly into the app.
- **Feature Identification**: Identifies species from real-world images using advanced shape and color extraction.
- **Taxonomic Gating**: Uses biological classification to ensure high-precision matching.
- **Offline Identification**: Fast, on-device scanner that works anywhere, perfect for out-in-the-field discoveries without an internet connection!

### ⚔️ **Deep RPG Battle Mechanics**
A complex, data-driven battle engine that rivals traditional monster-taming games.
- **Custom Moves & Abilities**: Hundreds of moves defined by types, categories (physical/special/status), and mechanics (isBite, isPunch, isSoundBased).
- **Intricate Status Effects**: From standard Poison, Burn, and Sleep, to unique conditions like Bleed, Stun, Stealth, and Vulnerable.
- **Synergistic Abilities**: Abilities that trigger on entry, stat calculation, damage calculation, and more. Condition systems (e.g., Swift Swim in Rain, Strong Jaw for bite moves) allow for deep strategic teambuilding.
- **Field Effects**: Dynamic Weathers (Rain, Sun, etc.) and Terrains that completely change the flow of battle.
- **Held Items**: Equip Choice Items, Focus Sashes, Life Orbs, and weather-extending items to formulate the perfect strategy.

### 🧠 **Advanced AI Decision Engine**
You aren't fighting mindless opponents. The AI evaluates every move dynamically.
- **Heuristic Scoring System**: Evaluates 50 distinct traits covering damage, status spreading, setup, healing, and hazard management.
- **Dynamic Switching**: The AI actively swaps out animals to avoid OHKO risks, protect sweepers, or gain advantageous matchups based on your play history.
- **Team Archetypes**: Opponents play according to their team design, from Hyper Offense and Stall to Weather Control and Hazard Stacking.

### 🗺️ **Story, Quests, and Overworld Exploration**
A persistent world built on a robust Event Flag system.
- **Dynamic NPCs**: Encounter story characters, blockers, quest givers, shopkeepers, medics, and trainers.
- **Branching Quests & Progression**: Fetch quests, milestone evaluations (e.g., capturing a certain number of species), and intricate event flags create a seamless, non-linear adventure.
- **Meaningful Rewards**: Earn items, unlock new paths, and receive permanent account flags that alter the world state around you.

### 🎮 **Arcade Game Modes**
Fast-paced, addicting games that test your reflexes and biological intuition:
- **Stat Showdown**: A "Higher or Lower" attribute comparison battle evaluating Health, Attack, Defense, Speed, and Weight.
- **Habitat Sort**: A rapid-fire 2x2 grid challenge where you drag animals into their correct biomes (Desert, Taiga, Jungle, etc.).
- **Silhouette Sprint**: Identify as many species as possible from their shadows in a race against the clock.
- **The Echo**: A memory sequence game requiring you to repeat increasingly complex patterns of animal types.

### 🧪 **Educational Quiz System**
Test your expertise across multiple biological disciplines:
- **Game Modes**: Sprite ID, Silhouette ID, Scientific Names, and Biome Knowledge.
- **Difficulty Scaling**: Choose between Easy, Normal, and Hard for every quiz.
- **Smart Scoring**: Features timers, streak multipliers, and difficulty-adjusted points to maximize replayability.

### 🏆 **Achievements & Progression**
A deep rewards system designed to keep you coming back:
- **Medal Milestones**: Hundreds of Bronze, Silver, and Gold medals to unlock for your achievements.
- **Account Leveling**: Earn XP from all games, battles, and quizzes to level up and gain new rank titles.
- **Dynamic Leaderboards**: Persistent high scores saved separately for every game mode and difficulty setting.

### 🎨 **Premium Visuals, Animations, & Sound**
- **Pixel-Art Aesthetic**: A stunning, consistent retro-modern UI built for high performance.
- **Dynamic Environments**: Battle backgrounds feature lighting filters that shift based on the real-world time of day (Day, Evening, Night), alongside immersive Weather and Terrain overlays.
- **Rich Battle Animations**: A highly customizable move animation system featuring projectiles (blobs, slashes, beams), melee combos, descending rocks, screen shake on heavy impacts, and unique entrance effects.
- **Immersive Audio**: Custom sound effects for every interaction, attack hit, and specific theme songs for different game modes and biomes.

---

## 🛠️ Technical Overview

- **Framework**: Flutter 3.x (Cross-platform Android, iOS, Web)
- **State Management**: Provider 6.x
- **Authentication**: LocalAuthService (Offline-first architecture)
- **Persistence**: Secure Local Storage with JSON-based database architecture, allowing mid-gameplay saving across the overworld.
- **UI Engine**: FlutterScreenUtil for pixel-perfect responsive layouts on phones and tablets.
- **AI/ML**: On-device biometric identification engine.

---

## 🚀 Quick Start

1. **Clone the repo**
2. **Run `flutter pub get`**
3. **Run `flutter run`**
4. **Login or Sign up** to start your journey as a Master Naturalist!

---

*Developed with passion for biodiversity, rich storytelling, and strategic gaming.*
