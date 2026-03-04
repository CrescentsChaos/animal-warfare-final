import 'package:animal_warfare/game/biome_weather.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'dart:math' as math;

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  /// Gets the current weather for a specific biome.
  Weather getCurrentWeather(String biomeName) {
    final gameTime = TimeService().currentGameTime;
    return BiomeWeatherTable.getRandomWeatherForBiome(
      biomeName,
      seed: _generateSeed(
        biomeName,
        gameTime.year,
        gameTime.month,
        gameTime.day,
      ),
    );
  }

  /// Gets the current temperature for a specific biome and weather.
  double getTemperature(String biomeName, Weather weather, {int? seed}) {
    final random = seed != null ? math.Random(seed) : math.Random();

    // Base temperature ranges (Celsius)
    double baseTemp;
    final biome = biomeName.toLowerCase();

    if (biome.contains('volcano'))
      baseTemp = 45.0 + random.nextDouble() * 15.0;
    else if (biome.contains('desert'))
      baseTemp = 35.0 + random.nextDouble() * 12.0;
    else if (biome.contains('savanna'))
      baseTemp = 28.0 + random.nextDouble() * 7.0;
    else if (biome.contains('jungle') || biome.contains('rainforest'))
      baseTemp = 26.0 + random.nextDouble() * 6.0;
    else if (biome.contains('mangrove') || biome.contains('swamp'))
      baseTemp = 24.0 + random.nextDouble() * 6.0;
    else if (biome.contains('urban'))
      baseTemp = 22.0 + random.nextDouble() * 8.0;
    else if (biome.contains('coastal'))
      baseTemp = 20.0 + random.nextDouble() * 10.0;
    else if (biome.contains('coral reef') || biome.contains('kelp forest'))
      baseTemp = 18.0 + random.nextDouble() * 6.0;
    else if (biome.contains('river') ||
        biome.contains('lake') ||
        biome.contains('ocean'))
      baseTemp = 15.0 + random.nextDouble() * 10.0;
    else if (biome.contains('mountain'))
      baseTemp = 5.0 + random.nextDouble() * 15.0;
    else if (biome.contains('cave'))
      baseTemp = 12.0 + random.nextDouble() * 4.0; // Stable
    else if (biome.contains('taiga'))
      baseTemp = -5.0 + random.nextDouble() * 15.0;
    else if (biome.contains('tundra'))
      baseTemp = -15.0 + random.nextDouble() * 20.0;
    else if (biome.contains('polar') || biome.contains('frozen ocean'))
      baseTemp = -40.0 + random.nextDouble() * 20.0;
    else if (biome.contains('deep sea'))
      baseTemp = 2.0 + random.nextDouble() * 3.0; // Very cold and stable
    else
      baseTemp = 20.0 + random.nextDouble() * 5.0; // Default

    // Weather Offsets
    double offset = 0;
    switch (weather) {
      case Weather.sunny:
        offset = 5.0;
        break;
      case Weather.rain:
        offset = -3.0;
        break;
      case Weather.heavyRain:
        offset = -5.0;
        break;
      case Weather.thunderstorm:
        offset = -4.0;
        break;
      case Weather.snowstorm:
        offset = -10.0;
        break;
      case Weather.hail:
        offset = -8.0;
        break;
      case Weather.sandstorm:
        offset = 2.0;
        break;
      case Weather.fog:
        offset = -2.0;
        break;
      case Weather.windstorm:
        offset = -5.0;
        break;
      default:
        offset = 0;
    }

    return baseTemp + offset;
  }

  /// Gets a 3-day forecast for a specific biome (including today).
  List<WeatherForecast> getForecast(String biomeName) {
    final gameTime = TimeService().currentGameTime;
    final List<WeatherForecast> forecast = [];

    for (int i = 0; i < 4; i++) {
      final baseDate = DateTime(gameTime.year, gameTime.month, gameTime.day);
      final forecastDate = baseDate.add(Duration(days: i));
      final seed = _generateSeed(
        biomeName,
        forecastDate.year,
        forecastDate.month,
        forecastDate.day,
      );

      final weather = BiomeWeatherTable.getRandomWeatherForBiome(
        biomeName,
        seed: seed,
      );

      final temp = getTemperature(biomeName, weather, seed: seed);

      forecast.add(
        WeatherForecast(
          date: forecastDate,
          weather: weather,
          temperatureCelsius: temp,
          isToday: i == 0,
        ),
      );
    }

    return forecast;
  }

  int _generateSeed(String biome, int year, int month, int day) {
    return biome.hashCode ^ (year * 10000 + month * 100 + day);
  }
}

class WeatherForecast {
  final DateTime date;
  final Weather weather;
  final double temperatureCelsius;
  final bool isToday;

  WeatherForecast({
    required this.date,
    required this.weather,
    required this.temperatureCelsius,
    this.isToday = false,
  });

  double get temperatureFahrenheit => (temperatureCelsius * 9 / 5) + 32;

  String get dayLabel {
    if (isToday) return "TODAY";
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  String get formattedTemp =>
      "${temperatureCelsius.toStringAsFixed(1)}°C / ${temperatureFahrenheit.toStringAsFixed(1)}°F";
}
