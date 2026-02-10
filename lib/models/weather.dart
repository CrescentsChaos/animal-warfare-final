// lib/models/weather.dart

enum Weather {
  none,
  rain,      // Boosts Water, weak Fire
  harshSun,  // Boosts Fire, weak Water
  hail,      // Damages non-Ice
  sandstorm, // Damages non-Rock/Ground/Steel
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
      case Weather.rain:
        return 'It started to rain!';
      case Weather.harshSun:
        return ' The sunlight turned harsh!';
      case Weather.hail:
        return 'It started to hail!';
      case Weather.sandstorm:
        return 'A sandstorm kicked up!';
      default:
        return '';
    }
  }

  String get endMessage {
    switch (weather) {
      case Weather.rain:
        return 'The rain stopped.';
      case Weather.harshSun:
        return 'The harsh sunlight faded.';
      case Weather.hail:
        return 'The hail stopped.';
      case Weather.sandstorm:
        return 'The sandstorm subsided.';
      default:
        return '';
    }
  }
}
