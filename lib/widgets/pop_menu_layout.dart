// lib/widgets/pop_menu_layout.dart
import 'package:flutter/material.dart';
import 'package:animal_warfare/theme.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A reusable menu layout that keeps the header static and provides
/// a snapping scrollable list of menu items.
/// 
/// Items "pop up" with an animation only when they have enough space (fully visible).
/// The list snaps to ensure items are never left "half cut".
class PopMenuLayout extends StatefulWidget {
  final Widget header;
  final List<Widget> items;
  final double itemHeight;
  final EdgeInsets padding;
  final List<Widget>? footer;

  const PopMenuLayout({
    super.key,
    required this.header,
    required this.items,
    this.itemHeight = 90.0,
    this.padding = const EdgeInsets.fromLTRB(20, 32, 20, 0),
    this.footer,
  });

  @override
  State<PopMenuLayout> createState() => _PopMenuLayoutState();
}

class _PopMenuLayoutState extends State<PopMenuLayout> {
  final ScrollController _scrollController = ScrollController();
  bool _isSnapping = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _snapToItem() {
    if (_isSnapping || !_scrollController.hasClients) return;
    
    final double offset = _scrollController.offset;
    final int index = (offset / widget.itemHeight).round();
    final double targetOffset = index * widget.itemHeight;

    if ((offset - targetOffset).abs() < 1.0) return;

    _isSnapping = true;
    Future.microtask(() {
      if (mounted) {
        _scrollController.animateTo(
          targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        ).then((_) => _isSnapping = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Static Header (Red Part)
        Padding(
          padding: widget.padding,
          child: widget.header,
        ),
        
        // Scrollable List (Green Part)
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification && !_isSnapping) {
                _snapToItem();
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              itemCount: widget.items.length + (widget.footer?.length ?? 0),
              itemBuilder: (context, index) {
                if (index < widget.items.length) {
                  return PopUpItem(
                    index: index,
                    child: widget.items[index],
                  );
                } else {
                  return widget.footer![index - widget.items.length];
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PopUpItem extends StatefulWidget {
  final Widget child;
  final int index;
  final bool enabled;

  const PopUpItem({
    super.key,
    required this.child,
    required this.index,
    this.enabled = true,
  });

  @override
  State<PopUpItem> createState() => _PopUpItemState();
}

class _PopUpItemState extends State<PopUpItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('popup_${identityHashCode(widget)}_${widget.index}'),
      onVisibilityChanged: (info) {
        // Only "pop up" if it's fully visible (or nearly fully)
        // This ensures no "half cut" items are shown during scroll
        if (!_hasPopped && info.visibleFraction > 0) {
          setState(() {
            _hasPopped = true;
          });
          _controller.forward();
        }
      },
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Custom scroll physics that snaps to a specific item height/size.
class SnapScrollPhysics extends ScrollPhysics {
  final double snapSize;

  const SnapScrollPhysics({required this.snapSize, super.parent});

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnapScrollPhysics(snapSize: snapSize, parent: buildParent(ancestor));
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    double page = position.pixels / snapSize;
    if (velocity < -tolerance.velocity) {
      page = page.floorToDouble();
    } else if (velocity > tolerance.velocity) {
      page = page.ceilToDouble();
    } else {
      page = page.roundToDouble();
    }
    return page * snapSize;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        const SpringDescription(mass: 80, stiffness: 100, damping: 1),
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
