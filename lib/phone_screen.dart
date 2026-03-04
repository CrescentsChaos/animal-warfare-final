import 'package:animal_warfare/game/time_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/services/weather_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:animal_warfare/models/weather.dart';

class PhoneScreen extends StatefulWidget {
  final String? initialBiome; // Optional biome for weather app context
  const PhoneScreen({super.key, this.initialBiome});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  String? _activeApp; // null means home screen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),

          Center(
            child: Container(
              width: 320,
              height: 600,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: Column(
                  children: [
                    // Status Bar
                    _buildStatusBar(),

                    // Main Content
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _activeApp == null
                            ? _buildHomeScreen()
                            : _buildAppView(_activeApp!),
                      ),
                    ),

                    // Home Button / Indicator
                    _buildHomeIndicator(),
                  ],
                ),
              ),
            ),
          ),

          // Close button outside the phone
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return StreamBuilder<GameTime>(
      stream: TimeService().timeStream,
      initialData: TimeService().currentGameTime,
      builder: (context, snapshot) {
        final timeStr = snapshot.data?.formattedTime ?? '--:--';
        return Padding(
          padding: const EdgeInsets.fromLTRB(30, 12, 30, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: const [
                  Icon(
                    Icons.signal_cellular_4_bar,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.wifi, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Icon(Icons.battery_full, color: Colors.white, size: 14),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: InkWell(
        onTap: () => setState(() => _activeApp = null),
        child: Container(
          width: 120,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apps',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              children: [
                _buildAppIcon(
                  'Weather',
                  Icons.cloud_outlined,
                  Colors.lightBlue,
                ),
                _buildAppIcon('Profile', Icons.person_outline, Colors.orange),
                _buildAppIcon(
                  'Bank',
                  Icons.account_balance_wallet_outlined,
                  Colors.green,
                ),
                _buildAppIcon('Settings', Icons.settings_outlined, Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(String name, IconData icon, Color color) {
    return InkWell(
      onTap: () => setState(() => _activeApp = name),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildAppView(String appName) {
    void closeApp() => setState(() => _activeApp = null);

    switch (appName) {
      case 'Weather':
        return _WeatherApp(
          biome: widget.initialBiome ?? 'Forest',
          onBack: closeApp,
        );
      case 'Profile':
        return _ProfileApp(onBack: closeApp);
      case 'Bank':
        return _BankApp(onBack: closeApp);
      case 'Settings':
        return _SettingsApp(onBack: closeApp);
      default:
        return Center(
          child: Text(appName, style: const TextStyle(color: Colors.white)),
        );
    }
  }
}

class _WeatherApp extends StatefulWidget {
  final String biome;
  final VoidCallback onBack;
  const _WeatherApp({required this.biome, required this.onBack});

  @override
  State<_WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<_WeatherApp> {
  late String _currentBiome;

  @override
  void initState() {
    super.initState();
    _currentBiome = widget.biome;
  }

  @override
  Widget build(BuildContext context) {
    final forecast = WeatherService().getForecast(_currentBiome);
    final biomes = [
      'Volcano',
      'Cave',
      'Coastal',
      'Coral Reef',
      'Deep Sea',
      'Frozen Ocean',
      'Kelp Forest',
      'Swamp',
      'Lake',
      'Mangrove',
      'Polar',
      'Rainforest',
      'Taiga',
      'Tundra',
      'Urban',
      'Jungle',
      'Desert',
      'Savanna',
      'River',
      'Ocean',
      'Mountain',
    ];

    return Column(
      children: [
        _AppHeader(title: 'Weather', onBack: widget.onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                SizedBox(
                  height: 30,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: biomes.length,
                    itemBuilder: (context, index) {
                      final b = biomes[index];
                      final isSelected = b == _currentBiome;
                      return GestureDetector(
                        onTap: () => setState(() => _currentBiome = b),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.cyanAccent.withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.cyanAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              b.toUpperCase(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.cyanAccent
                                    : Colors.white70,
                                fontFamily: 'PressStart2P',
                                fontSize: 6,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: forecast.length,
                    itemBuilder: (context, index) {
                      final f = forecast[index];
                      return _buildForecastRow(f);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastRow(WeatherForecast f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.dayLabel,
                style: TextStyle(
                  color: f.isToday ? Colors.yellow : Colors.white70,
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${f.date.month}/${f.date.day}",
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _getWeatherIcon(f.weather),
                      const SizedBox(width: 8),
                      Text(
                        f.weather.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'PressStart2P',
                          fontSize: 7,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    f.formattedTemp,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontFamily: 'PressStart2P',
                      fontSize: 6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getWeatherIcon(Weather weather) {
    switch (weather) {
      case Weather.clear:
        return const Icon(
          Icons.wb_sunny_outlined,
          color: Colors.yellow,
          size: 18,
        );
      case Weather.rain:
        return const Icon(Icons.umbrella, color: Colors.blue, size: 18);
      case Weather.heavyRain:
        return const Icon(
          Icons.beach_access,
          color: Colors.blueAccent,
          size: 18,
        );
      case Weather.sunny:
        return const Icon(Icons.wb_sunny, color: Colors.orange, size: 18);
      case Weather.snowstorm:
        return const Icon(
          Icons.ac_unit,
          color: Colors.lightBlueAccent,
          size: 18,
        );
      case Weather.hail:
        return const Icon(Icons.grain, color: Colors.white, size: 18);
      case Weather.sandstorm:
        return const Icon(Icons.waves, color: Colors.brown, size: 18);
      case Weather.windstorm:
        return const Icon(Icons.air, color: Colors.white70, size: 18);
      case Weather.thunderstorm:
        return const Icon(Icons.bolt, color: Colors.yellowAccent, size: 18);
      case Weather.fog:
        return const Icon(Icons.cloud_queue, color: Colors.grey, size: 18);
      default:
        return const Icon(Icons.wb_cloudy, color: Colors.white, size: 18);
    }
  }
}

class _ProfileApp extends StatelessWidget {
  final VoidCallback onBack;
  const _ProfileApp({required this.onBack});

  String _getRankName(int level) {
    if (level >= 70) return 'Legendary Hunter';
    if (level >= 60) return 'Grandmaster';
    if (level >= 50) return 'Master';
    if (level >= 40) return 'Expert';
    if (level >= 30) return 'Veteran';
    if (level >= 20) return 'Intermediate';
    if (level >= 10) return 'Rookie';
    return 'Novice';
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final user = userState.currentUser;

    if (user == null) return const Center(child: Text('Not logged in'));

    // Account XP formula: (level^2) * 100
    int xpForLevel(int l) => (l <= 1) ? 0 : (l * l) * 100;
    final currentLevelXp = xpForLevel(user.accountLevel);
    final nextLevelXp = xpForLevel(user.accountLevel + 1);
    final progress =
        ((user.accountXP - currentLevelXp) / (nextLevelXp - currentLevelXp))
            .clamp(0.0, 1.0);

    return Column(
      children: [
        _AppHeader(title: 'Trainer Profile', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orangeAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.orangeAccent,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user.username,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(
                  _getRankName(user.accountLevel),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildInfoRow('Gender', user.gender),
              _buildInfoRow('Account Level', 'LV. ${user.accountLevel}'),
              const SizedBox(height: 24),
              const Text(
                'ACCOUNT PROGRESS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildProgressBar(
                label: 'EXP',
                value:
                    '${user.accountXP - currentLevelXp} / ${nextLevelXp - currentLevelXp}',
                progress: progress,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'STAMINA',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildProgressBar(
                label: 'AP',
                value: '${user.stamina} / 100',
                progress: user.stamina / 100,
                color: Colors.greenAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BankApp extends StatelessWidget {
  final VoidCallback onBack;
  const _BankApp({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final money = userState.currentUser?.money ?? 0;

    return Column(
      children: [
        _AppHeader(title: 'Bank', onBack: onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.greenAccent,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AVAILABLE BALANCE',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$$money',
                        style: GoogleFonts.pressStart2p(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsApp extends StatelessWidget {
  final VoidCallback onBack;
  const _SettingsApp({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AppHeader(title: 'Settings', onBack: onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.white),
                  title: const Text(
                    'Music',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Switch(value: true, onChanged: (v) {}),
                ),
                ListTile(
                  leading: const Icon(Icons.volume_up, color: Colors.white),
                  title: const Text(
                    'SFX',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Switch(value: true, onChanged: (v) {}),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _AppHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: onBack,
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
