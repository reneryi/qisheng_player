import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

bool shouldShowTooltips({
  required bool isWindows,
  required bool semanticsEnabled,
}) {
  return !(isWindows && semanticsEnabled);
}

/// Avoids a Flutter Windows AXTree race caused by Tooltip overlay removal
/// while an accessibility client is consuming semantics updates.
class WindowsAccessibilityTooltipGuard extends StatefulWidget {
  const WindowsAccessibilityTooltipGuard({
    super.key,
    required this.child,
    this.isWindowsForTesting,
    this.semanticsEnabledForTesting,
  });

  final Widget child;
  final bool? isWindowsForTesting;
  final bool? semanticsEnabledForTesting;

  @override
  State<WindowsAccessibilityTooltipGuard> createState() =>
      _WindowsAccessibilityTooltipGuardState();
}

class _WindowsAccessibilityTooltipGuardState
    extends State<WindowsAccessibilityTooltipGuard> {
  @override
  void initState() {
    super.initState();
    SemanticsBinding.instance.addSemanticsEnabledListener(_handleChange);
  }

  @override
  void dispose() {
    SemanticsBinding.instance.removeSemanticsEnabledListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TooltipVisibility(
      visible: shouldShowTooltips(
        isWindows: widget.isWindowsForTesting ?? Platform.isWindows,
        semanticsEnabled: widget.semanticsEnabledForTesting ??
            SemanticsBinding.instance.semanticsEnabled,
      ),
      child: widget.child,
    );
  }
}
