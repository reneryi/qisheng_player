import 'package:flutter/material.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/window_controls.dart';

double resolveMainLayoutDockInset({
  required bool reserveDockSpace,
  required bool hasOverlay,
  required double dockHeight,
  required double shellGap,
}) {
  if (reserveDockSpace && hasOverlay) return dockHeight + shellGap * 2;
  return reserveDockSpace ? shellGap : 0.0;
}

class MainLayoutFrame extends StatelessWidget {
  const MainLayoutFrame({
    super.key,
    required this.titleBar,
    required this.child,
    this.overlay,
    this.maxWidth,
    this.contentPadding,
    this.reserveDockSpace = true,
  });

  final Widget titleBar;
  final Widget child;
  final Widget? overlay;
  final double? maxWidth;
  final EdgeInsetsGeometry? contentPadding;
  final bool reserveDockSpace;

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    final resolvedMaxWidth = maxWidth ?? chrome.shellContentMaxWidth;
    return ValueListenableBuilder<WindowLayoutMode>(
      valueListenable: WindowControls.layoutMode,
      builder: (context, _, __) {
        final shellGap = WindowControls.shellGap;
        final topInset = 12.0 +
            (WindowControls.layoutMode.value == WindowLayoutMode.maximized
                ? 8.0
                : 0.0);
        final dockInset = resolveMainLayoutDockInset(
          reserveDockSpace: reserveDockSpace,
          hasOverlay: overlay != null,
          dockHeight: chrome.dockHeight,
          shellGap: shellGap,
        );
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4.0, topInset, 4.0, 0),
                child: Column(
                  children: [
                    titleBar,
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: dockInset),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: resolvedMaxWidth),
                            child: Padding(
                              padding: contentPadding ?? EdgeInsets.zero,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (overlay != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
                      child: overlay!,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
