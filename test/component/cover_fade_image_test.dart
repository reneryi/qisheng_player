import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/component/cover_fade_image.dart';

/// 1x1 透明 PNG（可被测试环境解码）。
const List<int> kTransparentImageBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  Widget buildHost({
    ImageProvider? provider,
    int index = 0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CoverFadeImage(
            provider: provider,
            index: index,
            width: 48,
            height: 48,
          ),
        ),
      ),
    );
  }

  testWidgets('shows placeholder when provider is null', (tester) async {
    await tester.pumpWidget(buildHost());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.broken_image), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CoverFadeImage),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('shows image after decode and fades in', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildHost(
            provider: MemoryImage(Uint8List.fromList(kTransparentImageBytes))),
      );
      // 等待真实异步解码完成
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Symbols.broken_image), findsNothing);
  });

  testWidgets('stagger delay scales with index but caps at 200ms', (
    tester,
  ) async {
    await tester.pumpWidget(buildHost(index: 100));
    // 100 * 25 = 2500ms → 应被截断到 200ms，因此 250ms 时占位已结束
    await tester.pump(const Duration(milliseconds: 250));
    // provider 为 null 时延迟结束直接显示占位（不再处于“未就绪”阶段）
    expect(find.byIcon(Symbols.broken_image), findsOneWidget);
  });
}
