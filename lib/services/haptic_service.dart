// lib/services/haptic_service.dart
//
// Thin wrapper around Flutter's HapticFeedback so all screens call a
// single consistent API. Just import this and call HapticService.light() etc.

import 'package:flutter/services.dart';

class HapticService {
  HapticService._();

  /// Subtle tick — nav taps, list item taps, toggle state changes.
  static void light() => HapticFeedback.lightImpact();

  /// Medium bump — card selections, confirm actions, slider snaps.
  static void medium() => HapticFeedback.mediumImpact();

  /// Strong impact — destructive actions (delete, logout), error states.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Tiny selection click — scrolling pickers, radio buttons, tabs.
  static void select() => HapticFeedback.selectionClick();
}
