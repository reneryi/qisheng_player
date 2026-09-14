import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/build_index_state_view.dart';
import 'package:qisheng_player/src/rust/api/tag_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BuildIndexStateView Lifecycle and Error Handling (R3)', () {
    testWidgets('cancels stream subscription upon dispose and suppresses onDone callback',
        (WidgetTester tester) async {
      final controller = StreamController<IndexActionState>.broadcast();
      bool whenIndexBuiltCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildIndexStateView(
              indexPath: Directory('fake_index'),
              folders: const ['fake_folder'],
              whenIndexBuilt: () {
                whenIndexBuiltCalled = true;
              },
              streamOverride: controller.stream,
            ),
          ),
        ),
      );

      // Verify stream is actively updating UI
      controller.add(
        const IndexActionState(progress: 0.5, message: 'indexing...'),
      );
      await tester.pump();
      expect(find.text('indexing...'), findsOneWidget);

      // Unmount / dispose widget before stream completes
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );
      await tester.pump();

      // Emit stream done after unmounting
      await controller.close();
      await tester.pump();

      // Callback must not have been executed on disposed widget
      expect(whenIndexBuiltCalled, isFalse);
    });

    testWidgets('safely handles stream onError without uncaught exceptions',
        (WidgetTester tester) async {
      final controller = StreamController<IndexActionState>.broadcast();
      bool whenIndexBuiltCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildIndexStateView(
              indexPath: Directory('fake_index'),
              folders: const ['fake_folder'],
              whenIndexBuilt: () {
                whenIndexBuiltCalled = true;
              },
              streamOverride: controller.stream,
            ),
          ),
        ),
      );

      // Emit error through stream
      controller.addError(
        const FileSystemException('Access denied', '/path/to/folder'),
      );
      await tester.pump();

      // UI should not crash and whenIndexBuilt should not be triggered on error
      expect(whenIndexBuiltCalled, isFalse);

      await controller.close();
      await tester.pump();
    });
  });
}
