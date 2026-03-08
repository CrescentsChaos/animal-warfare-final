// lib/models/weather.dart

enum Weather {
  none,
  clear, // Default, no effects
  rain, // aquatic boost, Fire reduced
  heavyRain, // Stronger rain effects
  snowstorm, // Ice boost, speed reduced
  hail, // Chip damage for all except Cryo
  fog, // Reduced accuracy
  sunny, // Fire boost, aquatic reduced
  intenseSun, // aquatic unusable
  sandstorm, // Chip damage, Rock boost
  windstorm, // Flying boost, accuracy down
  strongWinds, // Weather-based moves unusable
  thunderstorm, // Electric boost, paralysis chance
}

class WeatherEffect {
  final Weather weather;
  final int duration; // in turns

  const WeatherEffect({required this.weather, this.duration = 5});

  String get description {
    switch (weather) {
      case Weather.clear:
        return 'The sky cleared up!';
      case Weather.rain:
        return 'It started to rain!';
      case Weather.heavyRain:
        return 'A downpour began!';
      case Weather.snowstorm:
        return 'It started to snow!';
      case Weather.hail:
        return 'It started to hail!';
      case Weather.fog:
        return 'Fog rolled in!';
      case Weather.sunny:
        return 'The temperature is scorching!';
      case Weather.intenseSun:
        return 'The sunlight turned extremely harsh!';
      case Weather.sandstorm:
        return 'A sandstorm kicked up!';
      case Weather.windstorm:
        return 'Strong winds blow!';
      case Weather.strongWinds:
        return 'Mysterious strong winds are protecting the field!';
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
        return 'The rain stopped.';
      case Weather.snowstorm:
        return 'The snowstorm stopped.';
      case Weather.hail:
        return 'The hail subsided.';
      case Weather.fog:
        return 'The fog lifted.';
      case Weather.sunny:
      case Weather.intenseSun:
        return 'The temperature cooled down.';
      case Weather.sandstorm:
        return 'The sandstorm subsided.';
      case Weather.windstorm:
      case Weather.strongWinds:
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
        if (moveType == 'aquatic')
          return weather == Weather.heavyRain ? 1.8 : 1.5;
        if (moveType == 'blaze')
          return weather == Weather.heavyRain ? 0.3 : 0.5;
        break;
      case Weather.sunny:
      case Weather.intenseSun:
        if (moveType == 'blaze')
          return weather == Weather.intenseSun ? 2.0 : 1.6;
        if (moveType == 'aquatic')
          return weather == Weather.intenseSun ? 0.0 : 0.4;
        break;
      case Weather.snowstorm:
        if (moveType == 'cryo') return 1.3;
        break;
      case Weather.hail:
        if (moveType == 'cryo') return 1.5;
        break;
      case Weather.sandstorm:
        if (moveType == 'rock') return 1.3;
        break;
      case Weather.windstorm:
      case Weather.strongWinds:
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
      case Weather.hail:
      case Weather.sandstorm:
        return 0.85;
      case Weather.windstorm:
        return 0.9;
      default:
        return 1.0;
    }
  }
}
