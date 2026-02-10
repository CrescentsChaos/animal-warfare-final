# Animal Warfare 🐾

**Animal Warfare** is a feature-rich Flutter-based mobile application that combines education with an engaging monster-battler experience. Explore diverse biomes, discover exotic organisms, capture them in tactical battles, and master the ecosystem in the Quiz Lab.

The application features a **retro pixel-art aesthetic**, utilizing the `PressStart2P` font and high-contrast visuals for a nostalgic gaming feel.

---

## ✨ Core Features

### 🌍 Dynamic Biome Exploration
Explore real-world biomes like **Swamp, Desert, Rainforest, Ocean**, and more. Each biome features:
*   Unique visual palettes and custom background art.
*   Looping theme music specific to the environment.
*   **Weighted Encounter System**: Discover animals based on **Rarity** (Common, Uncommon, Rare, Epic, Legendary, Mythical).

### ⚔️ Battle & Capture System
Take your team of captured animals into the wild and engage in strategic turn-based combat.
*   **Capture Wild Animals**: Use your tools to capture new animals and add them to your collection.
*   **Individual Values (IVs)**: Every animal has unique stats (Health, Attack, Defense, Speed) determined at spawn.
*   **Element Types**: Strategic advantages based on elemental affinities (Fire, Water, Grass, etc.).
*   **Talismans & Abilities**: Equip items and utilize unique passive abilities to turn the tide.

### 🔋 Dual Stamina Systems
1.  **Exploration Stamina (Global)**: Manage your player's energy to explore biomes and identify new species. Regenerates over time.
2.  **Move Stamina (Move-specific)**: Each attack in battle has its own stamina (PP). Use your moves wisely; running out forces you to use "Struggle".

### 📦 Animal Box & Move Management
Manage your captured team with ease:
*   **Move Selection**: Customize each animal's moveset by picking up to 4 moves from their natural pool.
*   **Attacker Selection**: Choose which animal leads your party into battle.

### 🧪 Quiz Lab
Test and improve your biological knowledge in the newly redesigned Quiz Lab:
*   Multiple quiz types: Scientific Names, Sprite Identification, and Silhouette Challenges.
*   Earn XP and track your stats as you become an expert in the ecosystem.
*   **Retro UI**: A fully themed interface that matches the core game experience.

---

## 🛠️ Technical Overview

*   **Framework**: Flutter (Dart)
*   **State Management**: Provider (for real-time battle state and persistent user data)
*   **Persistence**: Local JSON-based storage with auto-sync.
*   **Audio**: Audioplayers for environment immersion.
*   **Theming**: Custom rigid-border design system with responsive typography.

---

## ⚙️ Installation and Setup

### Prerequisites
*   **Flutter SDK**: Latest stable version.
*   **Dart SDK**: Included with Flutter.

### Getting Started
1.  **Clone the repository**:
    ```bash
    git clone https://github.com/CrescentsChaos/animal-warfare-final.git
    cd animal-warfare-final
    ```
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Run the app**:
    ```bash
    flutter run
    ```

---

## 🤝 Contributing
Contributions are welcome! Whether it's adding new biomes, animals, or balancing battle mechanics.
1.  Fork the Project.
2.  Create your Feature Branch.
3.  Commit your Changes.
4.  Push to the Branch.
5.  Open a Pull Request.

---

## 📜 License
Distributed under the MIT License.

---

## 📞 Contact
Project Link: [https://github.com/CrescentsChaos/animal-warfare-final](https://github.com/CrescentsChaos/animal-warfare-final)
