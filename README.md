# Animal Warfare🐾

**Animal Warfare** is a Flutter-based mobile application where players explore diverse biomes, discover and identify exotic organisms, and manage their resources like **Stamina** to continue their exploration. The app features dynamic biome-based aesthetics, an achievement system, and a **retro 8-bit aesthetic** using the `PressStart2P` font.

## ✨ Features

  * **Dynamic Biome Exploration:** Explore a variety of real-world biomes (Swamp, Desert, Rainforest, Ocean, etc.), each with a unique visual palette, background art, and looping theme music.
  * **Weighted Encounter System:** Encounter organisms specific to each biome, with discovery chance weighted by their **Rarity** (Common, Uncommon, Rare, Epic, Legendary, Mythical).
  * **Stamina System:** Manage a crucial resource, **Stamina (100 Max)**, which is required for both exploring a biome (10 Stamina) and identifying new organisms (cost determined by Rarity). Stamina regenerates over time.
  * **Discovery and Identification:** Encountered organisms are initially silhouetted. Players must spend stamina to **Identify** the organism, permanently adding it to their discovered list.
  * **Achievement System:** Track discovery progress and unlock achievements related to collecting organisms.
  * **Responsive UI:** Uses a dedicated 8-bit font (`PressStart2P`) and high-contrast color schemes for a nostalgic gaming feel.

-----

## ⚙️ Stamina Costs

The core loop revolves around two stamina drains: Exploration and Identification.

| Action | Stamina Cost | Notes |
| :--- | :--- | :--- |
| **Start Exploration** | 10 Stamina | Deducted on the initial button press to trigger an encounter. |
| **Identify Organism** | Varies by Rarity | Deducted when revealing a hidden organism's name. |

### Identification Cost Breakdown

| Rarity | Stamina Cost |
| :--- | :--- |
| **Common** | 5 |
| **Uncommon**| 10 |
| **Rare** | 15 |
| **Epic** | 25 |
| **Legendary**| 40 |
| **Mythical** | 60 |

-----

## 🛠️ Installation and Setup

### Prerequisites

  * **Flutter SDK:** Ensure you have the latest stable version of Flutter installed.
  * **Dart SDK:** Included with Flutter.

### Getting Started

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/YOUR_USERNAME/animal-warfare-biome-explorer.git
    cd animal-warfare-biome-explorer
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Ensure assets are linked:**
    Verify that `assets/sprites`, `assets/biomes`, and `assets/Organisms.json` are present and correctly linked in your `pubspec.yaml` file.

4.  **Run the app:**

    ```bash
    flutter run
    ```

### Asset Structure

For the app's functionality to work, ensure the following directory structure is maintained, especially for organism sprites and biome backgrounds:

```
.
├── assets/
│   ├── sprites/
│   │   └── organism_name.png  # Local sprites (checked first)
│   ├── biomes/
│   │   └── biome_name-bg.png  # Biome background images
│   ├── audio/
│   │   └── biome_name_theme.mp3 # Biome music
│   └── Organisms.json         # Master list of all organisms
└── lib/
    ├── main.dart
    ├── biome_detail_screen.dart # Main exploration logic
    └── ...
```

-----

## 💡 Technologies Used

  * **Flutter:** Mobile application framework.
  * **Dart:** Programming language.
  * **Provider:** State management for real-time user data updates (especially Stamina).
  * **Audioplayers:** Used for background biome music.
  * **LocalAuthService:** Handles user persistence and organism discovery tracking.

-----

## 🤝 Contributing

Contributions are always welcome\! If you have suggestions for new biomes, organisms, or feature improvements, please open an issue or submit a pull request.

1.  Fork the Project.
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the Branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

-----

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

-----

## 📞 Contact

Your Name - [@YourTwitterHandle](https://www.google.com/search?q=https://twitter.com/YourTwitterHandle) - YourEmail@example.com

Project Link: [https://github.com/CrescentsChaos/animal-warfare-final](https://www.google.com/search?q=https://github.com/CrescentsChaos/animal-warfare-final)
