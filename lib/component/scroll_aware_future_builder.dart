import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ScrollAwareFutureBuilder<T> extends StatefulWidget {
  final Future<T> Function() future;
  final Object? futureKey;
  final AsyncWidgetBuilder<T> builder;

  const ScrollAwareFutureBuilder({
    super.key,
    required this.future,
    this.futureKey,
    required this.builder,
  });

  @override
  State<ScrollAwareFutureBuilder<T>> createState() =>
      _ScrollAwareFutureBuilderState<T>();
}

class _ScrollAwareFutureBuilderState<T>
    extends State<ScrollAwareFutureBuilder<T>> {
  Future<T>? _future;
  int _generation = 0;
  bool _retryScheduled = false;

  Object get _effectiveFutureKey => widget.futureKey ?? widget.future;

  @override
  void initState() {
    super.initState();
    _restartDeferredFuture();
  }

  @override
  void didUpdateWidget(covariant ScrollAwareFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFutureKey = oldWidget.futureKey ?? oldWidget.future;
    if (oldFutureKey != _effectiveFutureKey) {
      _restartDeferredFuture();
    }
  }

  void _restartDeferredFuture() {
    _generation++;
    _retryScheduled = false;
    _future = null;
    _scheduleCreateFuture(_generation);
  }

  void _scheduleCreateFuture(int generation) {
    if (_retryScheduled) return;
    _retryScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      scheduleMicrotask(() {
        if (!mounted || generation != _generation) return;
        _retryScheduled = false;
        _createDeferredFuture(generation);
      });
    });
  }

  void _createDeferredFuture(int generation) {
    if (!mounted || generation != _generation) return;

    if (Scrollable.recommendDeferredLoadingForContext(context)) {
      _scheduleCreateFuture(generation);
      return;
    }

    final future = widget.future();
    if (!mounted || generation != _generation) return;
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<T>(
      future: _future,
      builder: widget.builder,
    );
  }
}
