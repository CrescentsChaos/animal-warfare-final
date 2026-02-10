// lib/models/weather.dart

enum Weather {
  none,
  clear,        // Default, no effects
  rain,         // Water boost, Fire reduced
  heavyRain,    // Stronger rain effects
  drizzle,      // Light rain
  snow,         // Ice boost, speed reduced
  blizzard,     // Heavy snow + chip damage
  fog,          // Reduced accuracy
  heatwave,     // Fire boost, Water reduced
  sandstorm,    // Chip damage, Rock boost
  windstorm,    // Flying boost, accuracy down
  thunderstorm, // Electric boost, paralysis chance
}

class WeatherEffect {
  final Weather weather;
  final int duration; // in turns

  const WeatherEffect({
    required this.weather,
    this.duration = 5,
  });

  String get description {
    switch (weather) {
      case Weather.clear:
        return 'The sky cleared up!';
      case Weather.rain:
        return 'It started to rain!';
      case Weather.heavyRain:
        return 'A downpour began!';
      case Weather.drizzle:
        return 'It\'s drizzling.';
      case Weather.snow:
        return 'It started to snow!';
      case Weather.blizzard:
        return 'A blizzard struck!';
      case Weather.fog:
        return 'Fog rolled in!';
      case Weather.heatwave:
        return 'The temperature is scorching!';
      case Weather.sandstorm:
        return 'A sandstorm kicked up!';
      case Weather.windstorm:
        return 'Strong winds blow!';
      case Weather.thunderstorm:
        return 'A thunderstorm rumbles!';
      default:
        return '';
    }
  }

  String get endMessage {
    switch (weather) {
      case Weather.rain:
      case Weather.heavyRain:
      case Weather.drizzle:
        return 'The rain stopped.';
      case Weather.snow:
        return 'The snow stopped.';
      case Weather.blizzard:
        return 'The blizzard subsided.';
      case Weather.fog:
        return 'The fog lifted.';
      case Weather.heatwave:
        return 'The temperature cooled down.';
      case Weather.sandstorm:
        return 'The sandstorm subsided.';
      case Weather.windstorm:
        return 'The winds calmed.';
      case Weather.thunderstorm:
        return 'The storm passed.';
      default:
        return '';
    }
  }

  // Damage multiplier for specific move types
  double getDamageMultiplier(String moveType) {
    switch (weather) {
      case Weather.rain:
      case Weather.heavyRain:
        if (moveType == 'water') return weather == Weather.heavyRain ? 1.8 : 1.5;
        if (moveType == 'fire') return weather == Weather.heavyRain ? 0.3 : 0.5;
        break;
      case Weather.drizzle:
        if (moveType == 'water') return 1.2;
        if (moveType == 'fire') return 0.8;
        break;
      case Weather.heatwave:
        if (moveType == 'fire') return 1.6;
        if (moveType == 'water') return 0.4;
        break;
      case Weather.snow:
        if (moveType == 'ice') return 1.3;
        break;
      case Weather.blizzard:
        if (moveType == 'ice') return 1.5;
        break;
      case Weather.sandstorm:
        if (moveType == 'rock') return 1.3;
        break;
      case Weather.windstorm:
        if (moveType == 'flying') return 1.4;
        break;
      case Weather.thunderstorm:
        if (moveType == 'electric') return 1.5;
        break;
      default:
        break;
    }
    return 1.0;
  }

  // Accuracy modifier (multiplier, e.g., 0.8 = 80% accuracy)
  double get accuracyModifier {
    switch (weather) {
      case Weather.fog:
        return 0.7;
      case Weather.blizzard:
      case Weather.sandstorm:
        return 0.85;
      case Weather.windstorm:
        return 0.9;
      default:
        return 1.0;
    }
  }
}
