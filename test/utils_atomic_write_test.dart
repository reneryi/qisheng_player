import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/utils.dart';

void main() {
  test('atomicWriteString replaces the target contents', () async {
    final dir = await Directory.systemTemp.createTemp('qisheng_atomic_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}settings.json';
    await File(path).writeAsString('old');

    await atomicWriteString(path, 'new');

    expect(await File(path).readAsString(), 'new');
  });

  test('atomicWriteString keeps the old file when commit is interrupted',
      () async {
    final dir = await Directory.systemTemp.createTemp('qisheng_atomic_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}settings.json';
    await File(path).writeAsString('old');

    await expectLater(
      atomicWriteStringWithBeforeCommit(path, 'partial', () {
        throw StateError('simulated interruption');
      }),
      throwsStateError,
    );

    expect(await File(path).readAsString(), 'old');
    expect(
      dir.listSync().where((entry) => entry.path.endsWith('.tmp')),
      isEmpty,
    );
  });
}
