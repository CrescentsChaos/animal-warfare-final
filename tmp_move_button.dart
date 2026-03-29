Widget _buildMoveButton(DoubleBattleManager bm, Move move, bool isNarrow) {
    final org = (bm.currentState == DoubleBattleState.selectingForSlot1)
        ? bm.playerSlot1!
        : bm.playerSlot2!;
    final isLocked =
        org.isChoiceLocked &&
        org.lockedMove != null &&
        move.name != org.lockedMove!.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLocked ? null : () => _onMoveSelected(move, bm),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isLocked
                ? Colors.grey.shade900
                : move.type.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLocked
                  ? Colors.grey.shade700
                  : move.type.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: isLocked
                ? []
                : [
                    BoxShadow(
                      color: move.type.color.withValues(alpha: 0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: isNarrow ? 4 : 6,
                decoration: BoxDecoration(
                  color: isLocked ? Colors.grey.shade600 : move.type.color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(6),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          move.name.toUpperCase(),
                          style: TextStyle(
                            color: isLocked ? Colors.grey : Colors.white,
                            fontSize: isNarrow ? 8 : 10,
                            fontFamily: 'PressStart2P',
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isLocked
                              ? Colors.grey.shade800
                              : move.type.color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isLocked
                                ? Colors.grey.shade600
                                : move.type.color.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          move.type.name.toUpperCase(),
                          style: TextStyle(
                            color: isLocked
                                ? Colors.grey.shade400
                                : Colors.white,
                            fontSize: 7,
                            fontFamily: 'PressStart2P',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }