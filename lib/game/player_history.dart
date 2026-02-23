import 'package:animal_warfare/models/move.dart';

class PlayerAction {
  final bool isSwitch;
  final Move? move;
  final int? switchIndex;

  const PlayerAction({required this.isSwitch, this.move, this.switchIndex});
}

class PlayerHistory {
  final List<PlayerAction> actions = [];

  Move? get lastMove {
    for (final action in actions.reversed) {
      if (!action.isSwitch && action.move != null) return action.move;
    }
    return null;
  }

  bool get isSpammingLastMove {
    if (actions.length < 3) return false;
    final last = lastMove;
    if (last == null) return false;

    int count = 0;
    for (final action in actions.reversed) {
      if (!action.isSwitch && action.move?.name == last.name) {
        count++;
      } else if (action.isSwitch) {
        continue;
      } else {
        break;
      }
    }
    return count >= 3;
  }

  double get aggressionRatio {
    if (actions.isEmpty) return 0.5;
    int attacks = 0;
    int total = 0;
    for (final action in actions) {
      if (action.isSwitch) continue;
      total++;
      if (action.move != null && action.move!.baseDamage > 0) {
        attacks++;
      }
    }
    if (total == 0) return 0.5;
    return attacks / total;
  }

  void recordMove(Move move) {
    actions.add(PlayerAction(isSwitch: false, move: move));
  }

  void recordSwitch(int index) {
    actions.add(PlayerAction(isSwitch: true, switchIndex: index));
  }
}
