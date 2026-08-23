import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/app_shutdown.dart';

void main() {
  test('并发退出只关闭和保存一次，并在关闭播放器后保存状态', () async {
    final events = <String>[];
    final playerClosed = Completer<void>();
    var closeCalls = 0;
    var settingsSaveCalls = 0;
    var librarySaveCalls = 0;
    final coordinator = AppShutdownCoordinator(
      closePlayer: () async {
        closeCalls++;
        events.add('close:start');
        await playerClosed.future;
        events.add('close:end');
      },
      persistState: [
        () async {
          settingsSaveCalls++;
          events.add('save:settings');
        },
        () async {
          librarySaveCalls++;
          events.add('save:library');
        },
      ],
    );

    final first = coordinator.shutdown();
    final second = coordinator.shutdown();
    await Future<void>.delayed(Duration.zero);

    expect(closeCalls, 1);
    expect(settingsSaveCalls, 0);
    expect(librarySaveCalls, 0);

    playerClosed.complete();
    await Future.wait([first, second]);

    expect(closeCalls, 1);
    expect(settingsSaveCalls, 1);
    expect(librarySaveCalls, 1);
    expect(events.first, 'close:start');
    expect(events[1], 'close:end');
    expect(events.skip(2), containsAll(['save:settings', 'save:library']));
  });

  test('单项退出操作失败时仍继续执行其他保存任务', () async {
    var successfulSaves = 0;
    final coordinator = AppShutdownCoordinator(
      closePlayer: () async => throw StateError('close failed'),
      persistState: [
        () async => throw StateError('save failed'),
        () async => successfulSaves++,
      ],
    );

    await coordinator.shutdown();

    expect(successfulSaves, 1);
  });
}
