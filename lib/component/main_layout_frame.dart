import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/ui/liquid_gradient_background.dart';
import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:qisheng_player/theme_provider.dart';
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
              const _MainLayoutBackground(),
              Padding(
                padding: EdgeInsets.fromLTRB(shellGap, topInset, shellGap, 0),
                child: Column(
                  children: [
                    titleBar,
                    if (titleBar is! SizedBox)
                      _SilentShellGap(height: shellGap),
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
                  left: shellGap,
                  right: shellGap,
                  bottom: shellGap + chrome.dockHeight,
                  child: _SilentDockGap(height: shellGap),
                ),
              if (overlay != null)
                Positioned(
                  left: shellGap,
                  right: shellGap,
                  bottom: shellGap,
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

class _SilentShellGap extends StatelessWidget {
  const _SilentShellGap({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: const AbsorbPointer(child: SizedBox.expand()),
      );
}

class _SilentDockGap extends StatelessWidget {
  const _SilentDockGap({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    if (height <= 0) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const AbsorbPointer(child: SizedBox.expand()),
    );
  }
}

class _MainLayoutBackground extends StatelessWidget {
  const _MainLayoutBackground();

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    final theme = context.watch<ThemeProvider>();
    return ValueListenableBuilder<int>(
      valueListenable: AppSettings.instance.backgroundVersion,
      builder: (context, _, __) {
        final file = _resolveBackgroundFile();
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: LiquidGradientBackground(
                backgroundColors: theme.backgroundGradient,
                paletteColors: [...theme.albumPalette.colors, theme.glassTint],
                effectsLevel: theme.uiEffectsLevel,
                tintOnly: file != null,
                transitionDuration: context.motion.pageTransitionDuration,
                transitionCurve: context.motion.normal,
              ),
            ),
            if (file != null)
              _UserBackgroundImage(
                file: file,
                tint: Color.alphaBlend(
                  theme.glassTint.withValues(alpha: 0.1),
                  chrome.windowScrim,
                ),
              ),
          ],
        );
      },
    );
  }

  File? _resolveBackgroundFile() {
    final bgPath = AppSettings.instance.backgroundImagePath;
    if (bgPath == null || bgPath.isEmpty) return null;
    final file = File(bgPath);
    return file.existsSync() ? file : null;
  }
}

class _UserBackgroundImage extends StatelessWidget {
  const _UserBackgroundImage({required this.file, required this.tint});
  final File file;
  final Color tint;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: AppSettings.instance.backgroundImageOpacity,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              ColoredBox(color: tint),
            ],
          ),
        ),
      );
}
