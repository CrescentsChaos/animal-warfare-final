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
  typhoon, // Aquatic/Flying boost, heavy chip
  tornado, // Flying boost, heavy chip, accuracy down
  hurricane, // Extreme rain/wind, heavy chip
  tsunami, // Extreme aquatic boost, non-aquatic chip
  earthquake, // Earth boost, non-flying chip
  volcanoEruption, // Blaze boost, non-blaze chip
  blizzard, // Cryo boost, non-cryo chip
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
      case Weather.typhoon:
        return 'A massive typhoon is spinning!';
      case Weather.tornado:
        return 'A terrifying tornado is sweeping the field!';
      case Weather.hurricane:
        return 'A powerful hurricane is raging!';
      case Weather.tsunami:
        return 'A colossal tsunami is crashing!';
      case Weather.earthquake:
        return 'The earth is shaking violently!';
      case Weather.volcanoEruption:
        return 'The volcano is erupting!';
      case Weather.blizzard:
        return 'A freezing blizzard is blinding everyone!';
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
      case Weather.typhoon:
      case Weather.hurricane:
        return 'The storm cleared.';
      case Weather.tornado:
        return 'The tornado dissipated.';
      case Weather.tsunami:
        return 'The waters receded.';
      case Weather.earthquake:
        return 'The ground stopped shaking.';
      case Weather.volcanoEruption:
        return 'The eruption subsided.';
      case Weather.blizzard:
        return 'The blizzard stopped.';
      default:
        return '';
    }
  }

  // Damage multiplier for specific move types
  double getDamageMultiplier(String moveType) {
    switch (weather) {
      case Weather.rain:
      case Weather.heavyRain:
        if (moveType == 'aquatic') {
          return weather == Weather.heavyRain ? 1.8 : 1.5;
        }
        if (moveType == 'blaze') {
          return weather == Weather.heavyRain ? 0.3 : 0.5;
        }
        break;
      case Weather.sunny:
      case Weather.intenseSun:
        if (moveType == 'blaze') {
          return weather == Weather.intenseSun ? 2.0 : 1.6;
        }
        if (moveType == 'aquatic') {
          return weather == Weather.intenseSun ? 0.0 : 0.4;
        }
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
      case Weather.typhoon:
        if (moveType == 'aquatic' || moveType == 'flying') return 1.5;
        if (moveType == 'blaze') return 0.5;
        break;
      case Weather.tornado:
        if (moveType == 'flying') return 1.8;
        break;
      case Weather.hurricane:
        if (moveType == 'aquatic' || moveType == 'flying') return 1.8;
        if (moveType == 'blaze') return 0.2;
        break;
      case Weather.tsunami:
        if (moveType == 'aquatic') return 2.0;
        if (moveType == 'blaze') return 0.0;
        if (moveType == 'earth') return 0.5;
        break;
      case Weather.earthquake:
        if (moveType == 'earth') return 1.5;
        break;
      case Weather.volcanoEruption:
        if (moveType == 'blaze') return 1.8;
        if (moveType == 'aquatic') return 0.5;
        break;
      case Weather.blizzard:
        if (moveType == 'cryo') return 1.8;
        if (moveType == 'blaze') return 0.5;
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
        return 0.95;
      case Weather.windstorm:
        return 0.9;
      case Weather.typhoon:
      case Weather.hurricane:
      case Weather.blizzard:
        return 0.7;
      case Weather.tornado:
        return 0.6;
      default:
        return 1.0;
    }
  }
}
