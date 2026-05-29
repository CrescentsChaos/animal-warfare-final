import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/services/weather_service.dart';
import 'dart:async';

class SurvivalStatusWidget extends StatefulWidget {
  final String biomeName;

  const SurvivalStatusWidget({super.key, required this.biomeName});

  @override
  State<SurvivalStatusWidget> createState() => _SurvivalStatusWidgetState();
}

class _SurvivalStatusWidgetState extends State<SurvivalStatusWidget> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Update every second to check for effect expiration
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    if (userState.currentUser == null) return const SizedBox.shrink();

    final severity = WeatherService().getEnvironmentalSeverity(widget.biomeName);
    
    // Only show if extreme
    if (severity == EnvironmentalSeverity.comfortable) return const SizedBox.shrink();

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (severity) {
      case EnvironmentalSeverity.freezing:
        statusColor = Colors.lightBlueAccent;
        statusIcon = Icons.ac_unit;
        statusText = 'FREEZING';
        break;
      case EnvironmentalSeverity.cold:
        statusColor = Colors.blue;
        statusIcon = Icons.ac_unit;
        statusText = 'COLD';
        break;
      case EnvironmentalSeverity.hot:
        statusColor = Colors.orange;
        statusIcon = Icons.local_fire_department;
        statusText = 'HOT';
        break;
      case EnvironmentalSeverity.scorching:
        statusColor = Colors.redAccent;
        statusIcon = Icons.local_fire_department;
        statusText = 'SCORCHING';
        break;
      default:
        statusColor = Colors.white;
        statusIcon = Icons.thermostat;
        statusText = 'COMFORTABLE';
    }

    // Check for active protection
    bool isProtected = false;
    for (var effect in userState.currentUser!.activeSurvivalEffects) {
      if (severity == EnvironmentalSeverity.freezing || severity == EnvironmentalSeverity.cold) {
         if (effect.mitigatesSeverity == EnvironmentalSeverity.freezing) {
             isProtected = true;
         }
      }
      if (severity == EnvironmentalSeverity.scorching || severity == EnvironmentalSeverity.hot) {
         if (effect.mitigatesSeverity == EnvironmentalSeverity.scorching) {
             isProtected = true;
         }
      }
    }

    if ((severity == EnvironmentalSeverity.freezing || severity == EnvironmentalSeverity.cold) && 
        (userState.currentUser!.inventory['thermal_coat'] ?? 0) > 0) {
      isProtected = true;
    }
    if ((severity == EnvironmentalSeverity.scorching || severity == EnvironmentalSeverity.hot) && 
        (userState.currentUser!.inventory['cooling_vest'] ?? 0) > 0) {
      isProtected = true;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProtected ? Colors.greenAccent : statusColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isProtected ? Icons.shield : statusIcon,
            color: isProtected ? Colors.greenAccent : statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isProtected ? 'PROTECTED' : statusText,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: isProtected ? Colors.greenAccent : statusColor,
            ),
          ),
          if (!isProtected) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}
