import 'dart:math' as math;

import 'package:qisheng_player/window_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef WindowDragStartCallback = Future<void> Function();

class WindowDragRegion extends StatefulWidget {
  const WindowDragRegion({
    super.key,
    required this.child,
    this.dragThreshold = 5,
    this.onStartDragging,
    this.onDoubleTap,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final double dragThreshold;
  final WindowDragStartCallback? onStartDragging;
  final VoidCallback? onDoubleTap;
  final HitTestBehavior behavior;

  @override
  State<WindowDragRegion> createState() => _WindowDragRegionState();
}

class _WindowDragRegionState extends State<WindowDragRegion> {
  int? _activePointer;
  Offset? _pointerDownPosition;
  bool _dragStarted = false;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  Future<void> _startDragging() async {
    await (widget.onStartDragging ?? WindowControls.startDragging)();
  }

  bool _isPrimaryMouseButton(PointerEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0;
  }

  void _resetPointerState() {
    _activePointer = null;
    _pointerDownPosition = null;
    _dragStarted = false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isPrimaryMouseButton(event)) return;

    if (widget.onDoubleTap != null) {
      final now = DateTime.now();
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) <= const Duration(milliseconds: 350) &&
          _lastTapPosition != null &&
          (event.position - _lastTapPosition!).distance <=
              widget.dragThreshold * 2) {
        _lastTapTime = null;
        _lastTapPosition = null;
        _resetPointerState();
        widget.onDoubleTap!();
        return;
      }
      _lastTapTime = now;
      _lastTapPosition = event.position;
    }

    _activePointer = event.pointer;
    _pointerDownPosition = event.position;
    _dragStarted = false;
  }

  Future<void> _handlePointerMove(PointerMoveEvent event) async {
    if (_activePointer != event.pointer ||
        _pointerDownPosition == null ||
        _dragStarted ||
        !_isPrimaryMouseButton(event)) {
      return;
    }

    final delta = event.position - _pointerDownPosition!;
    final distance = math.sqrt(delta.dx * delta.dx + delta.dy * delta.dy);
    if (distance < widget.dragThreshold) return;

    _lastTapTime = null;
    _lastTapPosition = null;
    _dragStarted = true;
    await _startDragging();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer == event.pointer) {
      _resetPointerState();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer == event.pointer) {
      _resetPointerState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}
