import 'package:desktop_lyric/component/desktop_lyric_body.dart';
import 'package:desktop_lyric/desktop_lyric_controller.dart';
import 'package:desktop_lyric/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_lyric/component/foreground.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  DesktopLyricController.initWithArgs(args);

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 134),
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
