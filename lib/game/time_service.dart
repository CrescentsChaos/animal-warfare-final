import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents the in-game time.
class GameTime {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  const GameTime({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toJson() => {
    'year': year,
    'month': month,
    'day': day,
    'hour': hour,
    'minute': minute,
  };

  factory GameTime.fromJson(Map<String, dynamic> json) => GameTime(
    year: json['year'] as int,
    month: json['month'] as int,
    day: json['day'] as int,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
  );

  /// 1-based day of the week (1 = Monday, 7 = Sunday)
  int get weekday {
    // Simple Zeller's congruence or just calculate based on total days since epoch
    // For simplicity, let's derive it from the total days passed.
    // 1970-01-01 was a Thursday (4).
    final totalDays = _daysSinceEpoch;
    return ((totalDays + 3) % 7) + 1;
  }

  // Calculate days since epoch roughly (not 100% accurate for all leap years,
  // but good enough for game logic if we assume a standard calendar).
  int get _daysSinceEpoch {
    // Use a DateTime to leverage Dart's accurate calendar math
    return DateTime.utc(year, month, day).difference(DateTime.utc(1970)).inDays;
  }

  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  String get formattedDate {
    return "$monthName $day, $year";
  }

  String get dayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String get monthName {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  /// Use this seed for deterministic daily events (like weather)
  int get dailySeed => year * 10000 + month * 100 + day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameTime &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode =>
      year.hashCode ^
      month.hashCode ^
      day.hashCode ^
      hour.hashCode ^
      minute.hashCode;
}

class TimeService {
  static final TimeService _instance = TimeService._internal();

  factory TimeService() => _instance;

  TimeService._internal() {
    _loadOffset();
  }

  Future<void> _loadOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt('game_time_offset_minutes') ?? 0;
    _gameTimeOffset = Duration(minutes: minutes);
  }

  Future<void> _saveOffset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('game_time_offset_minutes', _gameTimeOffset.inMinutes);
  }

  // 1 real hour = 4 in-game hours.
  // So the speed multiplier is 4.
  static const int speedMultiplier = 4;

  // The base epoch we use to align in-game time and real-world time.
  // Using a fixed point ensures every player is on the exact same in-game schedule.
  static final DateTime _baseRealTime = DateTime.utc(2024, 1, 1);
  static final DateTime _baseGameTime = DateTime.utc(2024, 1, 1);

  final StreamController<GameTime> _timeController =
      StreamController<GameTime>.broadcast();

  Timer? _timer;

  /// Accumulated time offset from sleeping / time skips.
  /// This only ever increases, so the clock never goes backward.
  Duration _gameTimeOffset = Duration.zero;

  Stream<GameTime> get timeStream => _timeController.stream;

  GameTime get currentGameTime => _calculateGameTime(DateTime.now().toUtc());

  /// Gets the current in-game time as a DateTime object.
  DateTime get currentInGameDateTime {
    final Duration realElapsed = DateTime.now().toUtc().difference(_baseRealTime);
    final int gameElapsedMicroseconds = realElapsed.inMicroseconds * speedMultiplier;
    return _baseGameTime.add(Duration(microseconds: gameElapsedMicroseconds)).add(_gameTimeOffset);
  }

  /// Advances in-game time by [hours] hours permanently.
  void advanceTime(int hours) {
    _gameTimeOffset += Duration(hours: hours);
    _saveOffset();
    _timeController.add(currentGameTime);
  }

  void start() {
    if (_timer != null) return;

    // Tick every real-world second (which is 4 game-world seconds).
    // So to update the minute clock smoothly, we can just tick every second to be safe,
    // or every 15 real seconds (1 game minute). Let's do every real second for smoothness.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _timeController.add(currentGameTime);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  GameTime _calculateGameTime(DateTime currentRealTime) {
    // How much real time has passed since our base?
    final Duration realElapsed = currentRealTime.difference(_baseRealTime);

    // Scale the elapsed time by the multiplier
    final int gameElapsedMicroseconds =
        realElapsed.inMicroseconds * speedMultiplier;

    // Add to base game time, then apply any permanent offset from sleeping
    final DateTime gameDateTime = _baseGameTime
        .add(Duration(microseconds: gameElapsedMicroseconds))
        .add(_gameTimeOffset);

    return GameTime(
      year: gameDateTime.year,
      month: gameDateTime.month,
      day: gameDateTime.day,
      hour: gameDateTime.hour,
      minute: gameDateTime.minute,
    );
  }
}
