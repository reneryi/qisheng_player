import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/ui/app_section.dart';
import 'package:qisheng_player/component/ui/app_surface.dart';

void main() {
  testWidgets('AppSection lays settings out as a continuous document section',
      (tester) async {
    var didSave = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ListView(
            children: [
              AppSection(
                title: '播放行为',
                description: '设置常用播放偏好。',
                children: [
                  const Text('第一项'),
                  FilledButton(
                    onPressed: () => didSave = true,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('播放行为'), findsOneWidget);
    expect(find.text('设置常用播放偏好。'), findsOneWidget);
    expect(find.text('第一项'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.byType(AppSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ClipRRect), findsNothing);

    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(didSave, isTrue);
  });
}


