import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum EventOutcome { loot, battle, nothing }

class ExplorationEventDialog extends StatelessWidget {
  final String title;
  final String description;
  final Map<String, EventOutcome> options;
  
  const ExplorationEventDialog({
    super.key,
    required this.title,
    required this.description,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3F2A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDAA520), width: 3),
          boxShadow: const [
             BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFDAA520),
                fontFamily: 'PressStart2P',
                fontSize: 16,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ...options.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E8B57),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFDAA520), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(entry.value);
                  },
                  child: Text(entry.key.toUpperCase()),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
