import 'package:flutter/material.dart';
import 'package:animal_warfare/game/time_service.dart';

class GameClockWidget extends StatefulWidget {
  final Color highlightColor;

  const GameClockWidget({Key? key, required this.highlightColor})
    : super(key: key);

  @override
  State<GameClockWidget> createState() => _GameClockWidgetState();
}

class _GameClockWidgetState extends State<GameClockWidget> {
  late GameTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = TimeService().currentGameTime;
    TimeService().start();
  }

  void _showCalendarOverlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: widget.highlightColor, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "IN-GAME CALENDAR",
          style: TextStyle(
            color: widget.highlightColor,
            fontFamily: 'PressStart2P',
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, color: widget.highlightColor, size: 48),
            const SizedBox(height: 16),
            Text(
              _currentTime.dayName.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentTime.formattedDate.toUpperCase(),
              style: TextStyle(
                color: widget.highlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Weather changes each day at midnight.",
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'PressStart2P',
                fontSize: 8,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CLOSE",
              style: TextStyle(
                color: widget.highlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameTime>(
      stream: TimeService().timeStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _currentTime = snapshot.data!;
        }

        final isNight = _currentTime.hour >= 18 || _currentTime.hour < 6;
        final icon = isNight ? Icons.nightlight_round : Icons.wb_sunny;

        return GestureDetector(
          onTap: () => _showCalendarOverlay(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.highlightColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: widget.highlightColor, size: 14),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentTime.formattedTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Day ${_currentTime.day}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'PressStart2P',
                        fontSize: 6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
