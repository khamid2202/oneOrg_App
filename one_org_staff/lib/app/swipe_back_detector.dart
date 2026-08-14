import 'package:flutter/material.dart';

class SwipeBackDetector extends StatefulWidget {
  const SwipeBackDetector({
    super.key,
    required this.child,
    required this.onSwipeBack,
    this.edgeWidth = 40.0,
    this.swipeThreshold = 0.3,
    this.enabled = true,
    this.underneathChild,
  });

  final Widget child;
  final VoidCallback onSwipeBack;
  final double edgeWidth;
  final double swipeThreshold;
  final bool enabled;
  final Widget? underneathChild;

  @override
  State<SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

class _SwipeBackDetectorState extends State<SwipeBackDetector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isDraggingFromLeftEdge = false;
  double _screenWidth = 0.0;

  /// Screens nest these detectors — the landing shell wraps every tab, and a
  /// tab (My Class) wraps its own list/detail pair. Both must be able to claim
  /// a drag that starts at the very edge so the *innermost* one wins the
  /// gesture arena and only one step of back navigation happens. That is why
  /// the recognizer lives in an edge strip pinned to `left: 0` rather than on a
  /// full-bleed detector filtering by `globalPosition`: a detector inset by its
  /// page padding never sees an x < 20 drag at all, so the outer shell used to
  /// win by default and jump straight to the dashboard.

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    // The strip's hit area *is* the edge test, so anything that reaches this
    // handler started at the edge. Checking `globalPosition` here as well used
    // to break the tablet layout, where the page is centred and its left edge
    // sits far past `edgeWidth` in global coordinates.
    _isDraggingFromLeftEdge = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingFromLeftEdge || _screenWidth <= 0) return;
    _animationController.value += details.delta.dx / _screenWidth;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDraggingFromLeftEdge) return;
    _isDraggingFromLeftEdge = false;

    final double velocity = details.primaryVelocity ?? 0.0;
    if (_animationController.value > widget.swipeThreshold || velocity > 300) {
      _animationController.forward().then((_) {
        widget.onSwipeBack();
        _animationController.value = 0.0;
      });
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.underneathChild ?? widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure against the page, not the window: the landing shell caps
        // content at 820px on tablets, and the drag threshold should be a
        // fraction of what actually slides.
        _screenWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.underneathChild != null)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      if (_animationController.value == 0.0) {
                        return const SizedBox.shrink();
                      }
                      final parallax =
                          -30.0 * (1.0 - _animationController.value);
                      return Transform.translate(
                        offset: Offset(parallax, 0.0),
                        child: child,
                      );
                    },
                    child: widget.underneathChild,
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final translation = _animationController.value * _screenWidth;
                final theme = Theme.of(context);
                return Transform.translate(
                  offset: Offset(translation, 0.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      boxShadow: [
                        if (_animationController.value > 0.0)
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.24 * (1.0 - _animationController.value),
                            ),
                            blurRadius: 16,
                            spreadRadius: 1,
                            offset: const Offset(-6, 0),
                          ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              child: widget.child,
            ),

            // Translucent so taps still reach whatever sits under the strip;
            // only a horizontal drag is claimed. Pinned to the page's left
            // edge, which is what lets a nested detector compete for — and,
            // being deeper in the tree, win — the same edge drag.
            Positioned(
              left: 0.0,
              top: 0.0,
              bottom: 0.0,
              width: widget.edgeWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                onHorizontalDragCancel: () {
                  if (_isDraggingFromLeftEdge) {
                    _isDraggingFromLeftEdge = false;
                    _animationController.reverse();
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
