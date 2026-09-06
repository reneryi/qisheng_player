import 'package:qisheng_player/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

class AppComponentThemes {
  const AppComponentThemes._();

  static const Size _minInteractiveSize = Size(44, 44);

  static FilledButtonThemeData filledButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    return FilledButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200), // 丝滑动画
        minimumSize: const WidgetStatePropertyAll(_minInteractiveSize),
        enableFeedback: false,
        // 鐜颁唬绠€绾︼細鏇村鏉剧殑鎸夐挳鍐呰竟璺?
        padding: _pressablePadding(
          const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          visuals,
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return 0;
          if (states.contains(WidgetState.pressed)) return 1.2;
          if (states.contains(WidgetState.hovered)) return 4.2;
          return 2.2;
        }),
        shadowColor: _resolveGlowShadow(accents, visuals),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.42);
          }
          return accents.onAccent;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accent;
          }
          if (states.contains(WidgetState.hovered)) {
            return Color.lerp(accents.accentContainer, accents.accent, 0.2)!;
          }
          return accents.accentContainer;
        }),
        overlayColor: WidgetStatePropertyAll(accents.hoverTint),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusXxl),
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: accents.accentFocusRing.withValues(
                alpha:
                    accents.accentFocusRing.a * visuals.buttonFocusRingOpacity,
              ),
              width: 1.5,
            );
          }
          return BorderSide(color: accents.accentSoft.withValues(alpha: 0.12));
        }),
      ),
    );
  }

  static TextButtonThemeData textButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    return TextButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200), // 丝滑动画
        minimumSize: const WidgetStatePropertyAll(_minInteractiveSize),
        enableFeedback: false,
        // 鐜颁唬绠€绾︼細鏇村鏉剧殑鏂囧瓧鎸夐挳
        padding: _pressablePadding(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          visuals,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accent;
          }
          return scheme.onSurface;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return accents.accentSoft;
          }
          return Colors.transparent;
        }),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return 2.0;
          if (states.contains(WidgetState.pressed)) return 0.8;
          return 0;
        }),
        shadowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return accents.accentGlow.withValues(
              alpha: accents.accentGlow.a * visuals.buttonGlowOpacity * 0.8,
            );
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accentGlow.withValues(
              alpha: accents.accentGlow.a * visuals.buttonGlowOpacity * 0.38,
            );
          }
          return Colors.transparent;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusXxl),
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: accents.accentFocusRing.withValues(
                alpha:
                    accents.accentFocusRing.a * visuals.buttonFocusRingOpacity,
              ),
              width: 1.4,
            );
          }
          return const BorderSide(color: Colors.transparent);
        }),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200), // 丝滑动画
        minimumSize: const WidgetStatePropertyAll(_minInteractiveSize),
        enableFeedback: false,
        // 鐜颁唬绠€绾︼細鏇村鏉剧殑杞粨鎸夐挳
        padding: _pressablePadding(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          visuals,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.4);
          }
          return scheme.onSurface;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return accents.accentSoft.withValues(alpha: 0.82);
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accentSoft.withValues(alpha: 0.58);
          }
          return surfaces.surfaceInset.withValues(alpha: surfaces.panelAlpha);
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(
                color: surfaces.strokeSubtle.withValues(alpha: 0.42));
          }
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: accents.accentFocusRing.withValues(
                alpha:
                    accents.accentFocusRing.a * visuals.buttonFocusRingOpacity,
              ),
              width: 1.5,
            );
          }
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(color: accents.accent.withValues(alpha: 0.76));
          }
          return BorderSide(
              color: surfaces.strokeStrong.withValues(alpha: 0.72));
        }),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return 2.8;
          if (states.contains(WidgetState.pressed)) return 1;
          return 0.6;
        }),
        shadowColor: _resolveGlowShadow(accents, visuals),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusXxl),
          ),
        ),
      ),
    );
  }

  static ElevatedButtonThemeData elevatedButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200), // 丝滑动画
        minimumSize: const WidgetStatePropertyAll(_minInteractiveSize),
        enableFeedback: false,
        // 鐜颁唬绠€绾︼細鏇村鏉剧殑娴捣鎸夐挳
        padding: _pressablePadding(
          const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          visuals,
        ),
        foregroundColor: WidgetStatePropertyAll(accents.onAccent),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accent;
          }
          return accents.accentContainer;
        }),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return 0;
          if (states.contains(WidgetState.pressed)) return 1.1;
          if (states.contains(WidgetState.hovered)) return 4.4;
          return 2.4;
        }),
        shadowColor: _resolveGlowShadow(accents, visuals),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusXxl),
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: accents.accentFocusRing.withValues(
                alpha:
                    accents.accentFocusRing.a * visuals.buttonFocusRingOpacity,
              ),
              width: 1.4,
            );
          }
          return BorderSide(color: accents.accentSoft.withValues(alpha: 0.12));
        }),
      ),
    );
  }

  static IconButtonThemeData iconButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(_minInteractiveSize),
        fixedSize: const WidgetStatePropertyAll(_minInteractiveSize),
        enableFeedback: false,
        padding: _pressablePadding(const EdgeInsets.all(10), visuals),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return accents.accent;
          }
          return scheme.onSurface;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accents.accentSoft.withValues(alpha: 0.58);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: isDark ? 0.12 : 0.08);
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.08),
        ),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: accents.accentFocusRing.withValues(
                alpha:
                    accents.accentFocusRing.a * visuals.buttonFocusRingOpacity,
              ),
              width: 1.4,
            );
          }
          return BorderSide.none;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusXxl),
          ),
        ),
      ),
    );
  }

  static InputDecorationTheme inputDecorationTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
  ) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(surfaces.radiusXxl),
      borderSide: BorderSide(color: surfaces.strokeSubtle),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: surfaces.surfaceInset.withValues(alpha: surfaces.panelAlpha),
      // Input padding.
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.58)),
      prefixIconColor: scheme.onSurface.withValues(alpha: 0.72),
      suffixIconColor: scheme.onSurface.withValues(alpha: 0.72),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.82)),
      ),
    );
  }

  // 现代简约：对话框使用更大圆角和柔和阴影
  static DialogThemeData dialogTheme(
    AppSurfaceTokens surfaces,
  ) {
    return DialogThemeData(
      backgroundColor: surfaces.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surfaces.radiusXxl),
      ),
      shadowColor: surfaces.shadowColor,
      elevation: 12,
    );
  }

  static MenuThemeData menuTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Color.alphaBlend(
            scheme.primary.withValues(
              alpha: isDark ? 0.12 : 0.06,
            ),
            surfaces.surfaceFloating.withValues(alpha: isDark ? 0.94 : 0.96),
          ),
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.0,
            ),
          ),
        ),
        elevation: const WidgetStatePropertyAll(10),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
        ),
      ),
    );
  }

  // 菜单项按钮的全局主题配置，完全移除所有物理黑边描边，使用半透明胶囊高亮和圆角
  static MenuButtonThemeData menuButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return MenuButtonThemeData(
      style: ButtonStyle(
        enableFeedback: false,
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        // 彻底移除描边，消除黑边割裂感
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        // 悬停 (Hover) 与聚焦 (Focus) 时呈现温润半透明胶囊高亮
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: isDark ? 0.22 : 0.16);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return scheme.primary.withValues(
              alpha: isDark ? 0.14 : 0.09,
            );
          }
          return Colors.transparent;
        }),
        // 按下时字体呈高亮品牌色，默认状态下保持 onSurface 颜色
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary;
          }
          return scheme.onSurface;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary;
          }
          return scheme.onSurface.withValues(alpha: 0.85);
        }),
        // 8px 微圆角胶囊设计
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  static TabBarThemeData tabBarTheme(
    ColorScheme scheme,
    AppAccentTokens accents,
  ) {
    return TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorColor: accents.accent,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.5),
      overlayColor: WidgetStatePropertyAll(accents.hoverTint),
    );
  }

  static SegmentedButtonThemeData segmentedButtonTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200), // 丝滑动画
        minimumSize: const WidgetStatePropertyAll(_minInteractiveSize),
        enableFeedback: false,
        // 分段按钮宽松舒适内边距
        padding: _pressablePadding(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          visuals,
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accents.accentContainer;
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.surfaceContainerHigh;
          }
          return scheme.surfaceContainerLow;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accents.onAccent;
          }
          return scheme.onSurface;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: accents.accentFocusRing.withValues(
                alpha:
                    accents.accentFocusRing.a * visuals.buttonFocusRingOpacity,
              ),
              width: 1.4,
            );
          }
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: accents.accent.withValues(alpha: 0.52));
          }
          return BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          );
        }),
        // 分段按钮圆润胶囊
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surfaces.radiusXl),
          ),
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected) &&
              states.contains(WidgetState.hovered)) {
            return 3;
          }
          if (states.contains(WidgetState.selected)) return 1.6;
          return 0;
        }),
        shadowColor: _resolveGlowShadow(accents, visuals),
      ),
    );
  }

  static WidgetStateProperty<EdgeInsetsGeometry> _pressablePadding(
    EdgeInsets base,
    AppVisualTokens visuals,
  ) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return EdgeInsets.fromLTRB(
          base.left,
          base.top + visuals.buttonPressOffset,
          base.right,
          base.bottom - visuals.buttonPressOffset,
        );
      }
      return base;
    });
  }

  static WidgetStateProperty<Color?> _resolveGlowShadow(
    AppAccentTokens accents,
    AppVisualTokens visuals,
  ) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.pressed)) {
        return accents.accentGlow.withValues(
          alpha: accents.accentGlow.a *
              visuals.buttonGlowOpacity *
              visuals.buttonPressedGlowScale,
        );
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return accents.accentGlow.withValues(
          alpha: accents.accentGlow.a *
              visuals.buttonGlowOpacity *
              visuals.buttonHoverGlowScale,
        );
      }
      return accents.accentGlow.withValues(
        alpha: accents.accentGlow.a * visuals.buttonGlowOpacity,
      );
    });
  }

  static ScrollbarThemeData scrollbarTheme(
    ColorScheme scheme,
    AppSurfaceTokens surfaces,
    AppAccentTokens accents,
  ) {
    return ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.dragged)) {
          return true;
        }
        return null;
      }),
      thickness: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.dragged)) {
          return 8.0;
        }
        return 6.0;
      }),
      radius: const Radius.circular(4.0),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return accents.accent.withValues(alpha: 0.75);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.onSurface.withValues(alpha: 0.38);
        }
        return scheme.onSurface.withValues(alpha: 0.18);
      }),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      crossAxisMargin: 2.0,
      mainAxisMargin: 4.0,
      minThumbLength: 36.0,
      interactive: true,
    );
  }
}
