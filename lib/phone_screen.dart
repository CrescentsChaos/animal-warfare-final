import 'package:animal_warfare/game/time_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/services/weather_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/services/save_service.dart';
import 'package:animal_warfare/models/shop_item.dart';
import 'package:animal_warfare/services/market_service.dart';
import 'dart:async';

class PhoneScreen extends StatefulWidget {
  final String? initialBiome; // Optional biome for weather app context
  const PhoneScreen({super.key, this.initialBiome});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  String? _activeApp; // null means home screen
  bool _showDealNotification = false;
  String _dealItemMessage = '';
  List<ShopItem> _allItemConfigs = [];
  Timer? _notificationTimer;
  bool _isVpnOn = false;

  @override
  void initState() {
    super.initState();
    _loadDeals();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeals() async {
    final items = await ShopItem.loadAll();
    if (!mounted) return;

    setState(() {
      _allItemConfigs = items;
    });

    // Find the best deal today
    final gameTime = TimeService().currentGameTime;
    ShopItem? bestDeal;
    double bestMult = 1.0;

    for (var item in items) {
      if (item.category == 'mystery_box') continue;
      final mult = MarketService.getPriceMultiplier(item.id, gameTime);
      if (mult < bestMult) {
        bestMult = mult;
        bestDeal = item;
      }
    }

    if (bestDeal != null && bestMult <= 0.75) {
      _dealItemMessage =
          "BARGAIN ALERT! ${bestDeal.name} is deeply discounted today!";
      _notificationTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showDealNotification = true;
          });
        }
        // Auto hide
        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showDealNotification = false;
            });
          }
        });
      });
    }
  }

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

          // Deal Notification Overlay
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            top: _showDealNotification ? 80 : -100,
            left: MediaQuery.of(context).size.width / 2 - 140,
            child: _buildNotificationBanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showDealNotification = false;
          _activeApp = 'Deals';
        });
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2E1E3E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shopping_cart_checkout,
              color: Colors.purpleAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DealSniper',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dealItemMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  'Bank',
                  Icons.account_balance_wallet_outlined,
                  Colors.amber,
                ),
                _buildAppIcon(
                  'VPN',
                  Icons.vpn_lock_outlined,
                  _isVpnOn ? Colors.greenAccent : Colors.grey,
                ),
                _buildAppIcon(
                  'Browser',
                  Icons.public_outlined,
                  Colors.orangeAccent,
                ),
                _buildAppIcon('Profile', Icons.person_outline, Colors.orange),
                _buildAppIcon(
                  'Bank',
                  Icons.account_balance_wallet_outlined,
                  Colors.green,
                ),
                _buildAppIcon(
                  'Deals',
                  Icons.local_offer_outlined,
                  Colors.purple,
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
      case 'Deals':
        return _DealSniperApp(onBack: closeApp, items: _allItemConfigs);
      case 'Settings':
        return _SettingsApp(onBack: closeApp);
      case 'VPN':
        return _VpnApp(
          isOn: _isVpnOn,
          onToggle: (v) => setState(() => _isVpnOn = v),
          onBack: closeApp,
        );
      case 'Browser':
        return _BrowserApp(onBack: closeApp);
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
                ListTile(
                  leading: const Icon(Icons.save_alt, color: Colors.white),
                  title: const Text(
                    'Export Save Data',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    final userState = Provider.of<UserState>(
                      context,
                      listen: false,
                    );
                    if (userState.currentUser != null) {
                      SaveService.exportSaveData(
                        context,
                        userState.currentUser!,
                        (loading) {},
                      );
                    }
                  },
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

class _DealSniperApp extends StatelessWidget {
  final VoidCallback onBack;
  final List<ShopItem> items;

  const _DealSniperApp({required this.onBack, required this.items});

  @override
  Widget build(BuildContext context) {
    final gameTime = TimeService().currentGameTime;

    // Calculate current multipliers and sort
    final deals = items.where((i) => i.category != 'mystery_box').map((item) {
      final mult = MarketService.getPriceMultiplier(item.id, gameTime);
      return {'item': item, 'multiplier': mult};
    }).toList();

    // Sort so biggest deals (lowest multiplayer) are at the top, biggest scams at bottom
    deals.sort(
      (a, b) =>
          (a['multiplier'] as double).compareTo(b['multiplier'] as double),
    );

    return Container(
      color: const Color(0xFF1E1E2E),
      child: Column(
        children: [
          _AppHeader(title: 'DealSniper', onBack: onBack),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: deals.length,
              itemBuilder: (context, index) {
                final item = deals[index]['item'] as ShopItem;
                final mult = deals[index]['multiplier'] as double;

                Color multColor = Colors.white;
                String sentiment = '';
                if (mult <= 0.75) {
                  multColor = Colors.greenAccent;
                  sentiment = 'STEAL!';
                } else if (mult >= 1.25) {
                  multColor = Colors.redAccent;
                  sentiment = 'RIPOFF';
                } else if (mult < 1.0) {
                  multColor = Colors.lightGreen;
                  sentiment = 'Good';
                } else {
                  multColor = Colors.orangeAccent;
                  sentiment = 'Bad';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E2E3E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: multColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Icon(
                          Icons.shopping_bag,
                          color: multColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Market: ${(mult * 100).round()}%',
                              style: TextStyle(
                                color: multColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: multColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sentiment,
                          style: TextStyle(
                            color: multColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BankApp extends StatelessWidget {
  final VoidCallback onBack;
  const _BankApp({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    final user = userState.currentUser;
    if (user == null) return const SizedBox();

    return Column(
      children: [
        _AppHeader(title: 'Taka Bank', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildBalanceCard(
                'Taka (Tk.)',
                user.money,
                user.bankTaka,
                Colors.amber,
                (amt) => userState.addMoney(-amt),
                (amt) => userState.addMoney(amt),
                (amt) => userState.updateBankBalance(tk: amt),
                (amt) => userState.updateBankBalance(tk: -amt),
              ),
              const SizedBox(height: 16),
              _buildAssetCard(
                'Gold Bars',
                'gold_bar',
                user.inventory['gold_bar'] ?? 0,
                user.bankGold,
                Colors.orange,
                (qty) => userState.updateBankBalance(gold: qty),
                (qty) => userState.updateBankBalance(gold: -qty),
                userState,
              ),
              const SizedBox(height: 16),
              _buildAssetCard(
                'Diamonds',
                'diamond',
                user.inventory['diamond'] ?? 0,
                user.bankDiamond,
                Colors.cyanAccent,
                (qty) => userState.updateBankBalance(diamond: qty),
                (qty) => userState.updateBankBalance(diamond: -qty),
                userState,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(
    String label,
    int pocket,
    int bank,
    Color color,
    Function(int) decPocket,
    Function(int) addPocket,
    Function(int) addBank,
    Function(int) decBank,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountColumn('Pocket', pocket, color),
              const Icon(Icons.compare_arrows, color: Colors.white24),
              _amountColumn('Vault', bank, color),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: pocket > 0
                      ? () {
                          addBank(pocket);
                          decPocket(pocket);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: const Text(
                    'DEPOSIT ALL',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: bank > 0
                      ? () {
                          addPocket(bank);
                          decBank(bank);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                  ),
                  child: const Text(
                    'WITHDRAW ALL',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(
    String label,
    String itemId,
    int pocket,
    int bank,
    Color color,
    Function(int) addBank,
    Function(int) decBank,
    UserState userState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountColumn('Pocket', pocket, color),
              const Icon(Icons.inventory_2_outlined, color: Colors.white24),
              _amountColumn('Vault', bank, color),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: pocket > 0
                      ? () {
                          addBank(pocket);
                          userState.addLoot(itemId, -pocket);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: const Text(
                    'STORE ALL',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: bank > 0
                      ? () {
                          decBank(bank);
                          userState.addLoot(itemId, bank);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                  ),
                  child: const Text(
                    'FETCH ALL',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountColumn(String label, int val, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        Text(
          val.toString(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _VpnApp extends StatelessWidget {
  final bool isOn;
  final Function(bool) onToggle;
  final VoidCallback onBack;
  const _VpnApp({
    required this.isOn,
    required this.onToggle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AppHeader(title: 'VPN Secure', onBack: onBack),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOn ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                size: 80,
                color: isOn ? Colors.greenAccent : Colors.white24,
              ),
              const SizedBox(height: 24),
              Text(
                isOn ? 'VPN ACTIVE' : 'VPN DISCONNECTED',
                style: TextStyle(
                  color: isOn ? Colors.greenAccent : Colors.white54,
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOn ? 'Your IP is masked.' : 'Your connection is public.',
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
              const SizedBox(height: 48),
              Switch(
                value: isOn,
                onChanged: onToggle,
                activeColor: Colors.greenAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrowserApp extends StatefulWidget {
  final VoidCallback onBack;
  const _BrowserApp({required this.onBack});

  @override
  State<_BrowserApp> createState() => _BrowserAppState();
}

class _BrowserAppState extends State<_BrowserApp> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDarkWeb = false;

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    return Column(
      children: [
        _AppHeader(title: 'Explorer', onBack: widget.onBack),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Enter URL...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
                size: 18,
              ),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onSubmitted: (val) {
              if (val.trim().toLowerCase() == 'darkweb.com') {
                setState(() => _isDarkWeb = true);
              } else {
                setState(() => _isDarkWeb = false);
              }
            },
          ),
        ),
        Expanded(
          child: _isDarkWeb
              ? _buildDarkWeb(userState)
              : const Center(
                  child: Text(
                    '404 Page Not Found',
                    style: TextStyle(color: Colors.white24),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDarkWeb(UserState userState) {
    final vpnOn =
        (context.findAncestorStateOfType<_PhoneScreenState>()?._isVpnOn ??
        false);

    if (!vpnOn) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, color: Colors.redAccent, size: 48),
            SizedBox(height: 16),
            Text(
              'ACCESS DENIED',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'A VPN connection is required to access this domain.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, color: Colors.purpleAccent, size: 64),
          const SizedBox(height: 24),
          const Text(
            'WELCOME TO THE DEPTHS',
            style: TextStyle(
              color: Colors.purpleAccent,
              fontFamily: 'PressStart2P',
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              userState.setBlackMarketUnlocked(true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Black Market access granted for this session.',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
            ),
            child: const Text('UNLOCK BLACK MARKET ACCESS'),
          ),
        ],
      ),
    );
  }
}
