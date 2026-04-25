import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/component/ui/liquid_gradient_background.dart';
import 'package:coriander_player/theme/app_theme_extensions.dart';
import 'package:coriander_player/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

double resolveMainLayoutDockInset({
  required bool reserveDockSpace,
  required bool hasOverlay,
  required double dockHeight,
  required double shellGap,
}) {
  return reserveDockSpace && hasOverlay ? dockHeight + shellGap * 2 : 0.0;
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
    final dockInset = resolveMainLayoutDockInset(
      reserveDockSpace: reserveDockSpace,
      hasOverlay: overlay != null,
      dockHeight: chrome.dockHeight,
      shellGap: chrome.shellGap,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const _MainLayoutBackground(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            chrome.shellGap,
            16,
            chrome.shellGap,
            0,
          ),
          child: Column(
            children: [
              titleBar,
              SizedBox(height: chrome.shellGap),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: dockInset),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
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
            left: chrome.shellGap,
            right: chrome.shellGap,
            bottom: chrome.shellGap,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
                child: overlay!,
              ),
            ),
          ),
      ],
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
        final hasCustomBackground = file != null;

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: LiquidGradientBackground(
                backgroundColors: theme.backgroundGradient,
                paletteColors: [
                  ...theme.albumPalette.colors,
                  theme.glassTint,
                ],
                effectsLevel: theme.uiEffectsLevel,
                tintOnly: hasCustomBackground,
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
    if (!file.existsSync()) return null;
    return file;
  }
}

class _UserBackgroundImage extends StatelessWidget {
  const _UserBackgroundImage({
    required this.file,
    required this.tint,
  });

  final File file;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
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
}
