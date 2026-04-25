import 'dart:io';

import 'package:coriander_player/app_settings.dart';
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

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: context.motion.pageTransitionDuration,
          curve: context.motion.normal,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.backgroundGradient,
            ),
          ),
        ),
        IgnorePointer(
          child: Stack(
            children: [
              _BackgroundGlow(
                alignment: const Alignment(-0.86, -0.94),
                size: 560,
                color: theme.dominantColor.withValues(alpha: 0.2),
              ),
              _BackgroundGlow(
                alignment: const Alignment(0.94, 0.86),
                size: 460,
                color: theme.glassTint.withValues(alpha: 0.14),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: AppSettings.instance.backgroundVersion,
          builder: (context, _, __) {
            final bgPath = AppSettings.instance.backgroundImagePath;
            if (bgPath == null || bgPath.isEmpty) {
              return const SizedBox.shrink();
            }

            final file = File(bgPath);
            if (!file.existsSync()) {
              return const SizedBox.shrink();
            }

            return IgnorePointer(
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
                  ColoredBox(
                    color: Color.alphaBlend(
                      theme.glassTint.withValues(alpha: 0.12),
                      chrome.windowScrim,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: color.a * 0.32),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
