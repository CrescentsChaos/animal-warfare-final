import 'package:flutter/material.dart';
import 'package:animal_warfare/theme.dart';

class CaptureNetOverlay extends StatefulWidget {
  final int shakeCount;
  final bool isSuccess;
  final bool isFailed;
  final LayerLink? link;
  final VoidCallback onComplete;

  const CaptureNetOverlay({
    super.key,
    required this.shakeCount,
    required this.isSuccess,
    required this.isFailed,
    required this.onComplete,
    this.link,
  });

  @override
  State<CaptureNetOverlay> createState() => _CaptureNetOverlayState();
}

class _CaptureNetOverlayState extends State<CaptureNetOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;
  int _lastShake = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.0), weight: 1),
    ]).animate(_controller);

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(CaptureNetOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeCount > _lastShake) {
      _lastShake = widget.shakeCount;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _shakeAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inner Net Glow
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (widget.isSuccess
                                      ? AppColors.highlightColor
                                      : widget.isFailed
                                      ? Colors.red
                                      : Colors.cyan)
                                  .withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  // The Net Icon
                  Icon(
                    Icons.grid_4x4_rounded,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  // Outer Net Border
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Shake Number Indicator
                  if (widget.shakeCount > 0 &&
                      !widget.isFailed &&
                      !widget.isSuccess)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${widget.shakeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'PressStart2P',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (widget.link != null) {
      return CompositedTransformFollower(
        link: widget.link!,
        followerAnchor: Alignment.center,
        targetAnchor: Alignment.center,
        child: SizedBox(
          width: 0,
          height: 0,
          child: OverflowBox(
            minWidth: 300,
            maxWidth: 300,
            minHeight: 300,
            maxHeight: 300,
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}
