import 'dart:convert';
import 'dart:io';

import 'package:desktop_lyric/component/desktop_lyric_body.dart';
import 'package:desktop_lyric/component/desktop_lyric_color_dialog.dart';
import 'package:desktop_lyric/component/font_selector_dialog.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

@visibleForTesting
Map<String, dynamic>? parseConfigWindowArgs(List<String> args) {
  if (!args.contains('--config-window')) return null;

  final configIndex = args.indexOf('--config-window');
  String configType = 'font';
  if (configIndex != -1 && configIndex + 1 < args.length) {
    final candidateType = args[configIndex + 1].trim().toLowerCase();
    if (candidateType == 'color' || candidateType == 'font') {
      configType = candidateType;
    }
  }

  Map<String, dynamic>? configPayload;
  for (final arg in args) {
    final trimmed = arg.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = json.decode(trimmed);
        if (decoded is Map<String, dynamic>) {
          configPayload = decoded;
          break;
        }
      } catch (_) {}
    }
  }

  return <String, dynamic>{
    'isConfigWindow': true,
    'configType': configType,
    ...?configPayload,
  };
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final configPayload = parseConfigWindowArgs(args);
  if (configPayload != null) {
    isConfigSubWindow = true;
    _runConfigApp(configPayload);
    return;
  }

  DesktopLyricController.initWithArgs(args);

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 180),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.show();
  });

  runApp(const DesktopLyricApp());
}

void _runConfigApp(Map<String, dynamic> payload) {
  final isDarkMode = payload['isDarkMode'] as bool? ?? false;
  DesktopLyricController.instance.isDarkMode.value = isDarkMode;

  final themeMap = payload['theme'] as Map<String, dynamic>?;
  if (themeMap != null) {
    DesktopLyricController.instance.theme.value = ThemeChangedMessage(
      themeMap['primary'] as int? ?? Colors.blue.toARGB32(),
      themeMap['surfaceContainer'] as int? ?? Colors.white.toARGB32(),
      themeMap['onSurface'] as int? ?? Colors.black.toARGB32(),
    );
  }

  final rawInstalledFonts = payload['installedFonts'] as List<dynamic>?;
  if (rawInstalledFonts != null) {
    DesktopLyricController.instance.installedFonts.value =
        rawInstalledFonts.whereType<String>().toList();
  }

  final playerFontFamily = payload['playerFontFamily'] as String?;
  DesktopLyricController.instance.playerFontFamily.value = playerFontFamily;
  DesktopLyricController.instance.currentFontFamily.value = playerFontFamily;

  final lyricLineMap = payload['lyricLine'] as Map<String, dynamic>?;
  if (lyricLineMap != null) {
    DesktopLyricController.instance.lyricLine.value = LyricLineChangedMessage(
      lyricLineMap['lyric'] as String? ?? '预览歌词 Preview Lyric',
      Duration.zero,
      lyricLineMap['translation'] as String?,
    );
  }

  final followPlayerFont = payload['followPlayerFont'] as bool? ?? true;
  final lyricFontFamily = payload['lyricFontFamily'] as String?;
  final hasSpecifiedColor = payload['hasSpecifiedColor'] as bool? ?? false;
  final specifiedColorVal = payload['specifiedColor'] as int?;

  TEXT_DISPLAY_CONTROLLER.initializeFromInitArgs(
    playerFont: playerFontFamily,
    savedFont: lyricFontFamily,
    followPlayer: followPlayerFont,
    hasSpecifiedColor: hasSpecifiedColor,
    specifiedColor: specifiedColorVal != null ? Color(specifiedColorVal) : null,
  );

  if (payload['lyricFontSize'] != null) {
    TEXT_DISPLAY_CONTROLLER.lyricFontSize =
        (payload['lyricFontSize'] as num).toDouble();
  }
  if (payload['translationFontSize'] != null) {
    TEXT_DISPLAY_CONTROLLER.translationFontSize =
        (payload['translationFontSize'] as num).toDouble();
  }
  if (payload['showTranslation'] != null) {
    TEXT_DISPLAY_CONTROLLER.showTranslation =
        payload['showTranslation'] as bool;
  }

  final configType = payload['configType'] as String? ?? 'font';
  final isColor = configType == 'color';
  final dialogSize = isColor ? const Size(720, 580) : const Size(600, 640);

  final windowOptions = WindowOptions(
    size: dialogSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(DesktopLyricConfigApp(configType: configType));
}

class DesktopLyricApp extends StatelessWidget {
  const DesktopLyricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DesktopLyricController.instance.isDarkMode,
      builder: (context, isDarkMode, _) => MultiProvider(
        providers: [
          ValueListenableProvider.value(
            value: DesktopLyricController.instance.isDarkMode,
          ),
          ValueListenableProvider.value(
            value: DesktopLyricController.instance.theme,
          ),
          ChangeNotifierProvider.value(
            value: TEXT_DISPLAY_CONTROLLER,
          ),
        ],
        child: ValueListenableBuilder<ThemeChangedMessage>(
          valueListenable: DesktopLyricController.instance.theme,
          builder: (context, currentTheme, _) {
            final primaryColor = Color(currentTheme.primary);
            final surfaceColor = Color(currentTheme.surfaceContainer);
            final onSurfaceColor = Color(currentTheme.onSurface);

            return MaterialApp(
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: primaryColor.computeLuminance() > 0.45
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  surface: surfaceColor,
                  onSurface: onSurfaceColor.computeLuminance() < 0.6
                      ? onSurfaceColor
                      : const Color(0xFF191C1E),
                ),
                iconTheme: IconThemeData(
                  color: onSurfaceColor.computeLuminance() < 0.6
                      ? onSurfaceColor
                      : const Color(0xFF191C1E),
                  fill: 1.0,
                  weight: 600,
                  grade: 0.25,
                  opticalSize: 24,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: ColorScheme.dark(
                  primary: primaryColor,
                  onPrimary: primaryColor.computeLuminance() > 0.55
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  surface: surfaceColor,
                  onSurface: onSurfaceColor.computeLuminance() > 0.4
                      ? onSurfaceColor
                      : Colors.white,
                ),
                iconTheme: IconThemeData(
                  color: onSurfaceColor.computeLuminance() > 0.4
                      ? onSurfaceColor
                      : Colors.white,
                  fill: 1.0,
                  weight: 600,
                  grade: 0.25,
                  opticalSize: 24,
                ),
              ),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: supportedLocales,
              home: const DesktopLyricBody(),
            );
          },
        ),
      ),
    );
  }

  final supportedLocales = const [
    Locale.fromSubtags(languageCode: 'zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale.fromSubtags(
        languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
    Locale.fromSubtags(
        languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
    Locale.fromSubtags(
        languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK'),
    Locale("en", "US"),
  ];
}

class DesktopLyricConfigApp extends StatelessWidget {
  final String configType;

  const DesktopLyricConfigApp({
    super.key,
    required this.configType,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DesktopLyricController.instance.isDarkMode,
      builder: (context, isDarkMode, _) => MultiProvider(
        providers: [
          ValueListenableProvider.value(
            value: DesktopLyricController.instance.isDarkMode,
          ),
          ValueListenableProvider.value(
            value: DesktopLyricController.instance.theme,
          ),
          ChangeNotifierProvider.value(
            value: TEXT_DISPLAY_CONTROLLER,
          ),
        ],
        child: ValueListenableBuilder<ThemeChangedMessage>(
          valueListenable: DesktopLyricController.instance.theme,
          builder: (context, currentTheme, _) {
            final primaryColor = Color(currentTheme.primary);
            final surfaceColor = Color(currentTheme.surfaceContainer);
            final onSurfaceColor = Color(currentTheme.onSurface);

            return MaterialApp(
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: primaryColor.computeLuminance() > 0.45
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  surface: surfaceColor,
                  onSurface: onSurfaceColor.computeLuminance() < 0.6
                      ? onSurfaceColor
                      : const Color(0xFF191C1E),
                ),
                iconTheme: IconThemeData(
                  color: onSurfaceColor.computeLuminance() < 0.6
                      ? onSurfaceColor
                      : const Color(0xFF191C1E),
                  fill: 1.0,
                  weight: 600,
                  grade: 0.25,
                  opticalSize: 24,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: ColorScheme.dark(
                  primary: primaryColor,
                  onPrimary: primaryColor.computeLuminance() > 0.55
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  surface: surfaceColor,
                  onSurface: onSurfaceColor.computeLuminance() > 0.4
                      ? onSurfaceColor
                      : Colors.white,
                ),
                iconTheme: IconThemeData(
                  color: onSurfaceColor.computeLuminance() > 0.4
                      ? onSurfaceColor
                      : Colors.white,
                  fill: 1.0,
                  weight: 600,
                  grade: 0.25,
                  opticalSize: 24,
                ),
              ),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [
                Locale.fromSubtags(languageCode: 'zh'),
                Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
                Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
                Locale.fromSubtags(
                    languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
                Locale.fromSubtags(
                    languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
                Locale.fromSubtags(
                    languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK'),
                Locale("en", "US"),
              ],
              navigatorObservers: [
                _ConfigWindowNavigatorObserver(),
              ],
              home: _ConfigWindowHome(configType: configType),
            );
          },
        ),
      ),
    );
  }
}

/// 全局配置子窗口退出回调（单元测试可通过该钩子拦截 exit）
@visibleForTesting
void Function()? configWindowCloserOverride;

bool _isConfigWindowClosing = false;

@visibleForTesting
void resetConfigWindowClosingForTesting() {
  _isConfigWindowClosing = false;
}

/// 彻底关闭独立配置子窗口并终结进程，防止透明画布遮挡并释放全局焦点
Future<void> closeConfigWindow() async {
  if (_isConfigWindowClosing) return;
  _isConfigWindowClosing = true;

  try {
    stdout.writeln(json.encode({
      'type': 'ConfigWindowClosed',
      'message': <String, dynamic>{},
    }));
    await stdout.flush().timeout(const Duration(milliseconds: 100));
  } catch (_) {}

  if (configWindowCloserOverride != null) {
    configWindowCloserOverride!();
    return;
  }

  try {
    // 1. 立即隐匿物理窗口，杜绝任何残余透明区域继续拦截鼠标与滚轮点击
    await windowManager.hide().timeout(const Duration(milliseconds: 150));
  } catch (_) {}

  try {
    await windowManager.destroy().timeout(const Duration(milliseconds: 150));
  } catch (_) {}

  exit(0);
}

class _ConfigWindowNavigatorObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // 仅在根路由被弹出时彻底销毁配置子窗口，子级路由（如下拉菜单、子弹窗）弹出时不误关窗口
    if (previousRoute == null) {
      closeConfigWindow();
    }
  }
}

class _ConfigWindowHome extends StatefulWidget {
  final String configType;

  const _ConfigWindowHome({required this.configType});

  @override
  State<_ConfigWindowHome> createState() => _ConfigWindowHomeState();
}

class _ConfigWindowHomeState extends State<_ConfigWindowHome> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    closeConfigWindow();
  }

  @override
  Widget build(BuildContext context) {
    final Widget dialogChild = widget.configType == 'color'
        ? const DesktopLyricColorDialog()
        : const LyricFontSelectorDialog();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () async {
          final nav = Navigator.of(context);
          final popped = await nav.maybePop();
          if (!popped) {
            await closeConfigWindow();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: closeConfigWindow,
                  child: const SizedBox.expand(),
                ),
              ),
              Center(child: dialogChild),
            ],
          ),
        ),
      ),
    );
  }
}

