import 'package:flutter/material.dart';
import 'package:qisheng_player/navigation_state.dart';

class NowPlayingShellUnderlay extends StatefulWidget {
  const NowPlayingShellUnderlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NowPlayingShellUnderlay> createState() =>
      _NowPlayingShellUnderlayState();
}

class _NowPlayingShellUnderlayState extends State<NowPlayingShellUnderlay> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    final navigation = AppNavigationState.instance;
    _hidden = navigation.nowPlayingPageActive;
    navigation.addListener(_handleNavigationChange);
  }

  void _handleNavigationChange() {
    final active = AppNavigationState.instance.nowPlayingPageActive;
    if (_hidden != active && mounted) {
      setState(() => _hidden = active);
    }
  }

  @override
  void dispose() {
    AppNavigationState.instance.removeListener(_handleNavigationChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const ValueKey('now-playing-shell-underlay-pointer'),
      ignoring: _hidden,
      child: AnimatedOpacity(
        key: const ValueKey('now-playing-shell-underlay-opacity'),
        opacity: _hidden ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: _hidden ? Curves.easeOutCubic : Curves.easeInOutCubic,
        child: TickerMode(
          key: const ValueKey('now-playing-shell-underlay-ticker'),
          enabled: !_hidden,
          child: widget.child,
        ),
      ),
    );
  }
}
