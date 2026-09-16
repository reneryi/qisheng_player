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

  test('atomicWriteString cleans up .bak after successful write', () async {
    final dir = await Directory.systemTemp.createTemp('qisheng_atomic_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}settings.json';
    await File(path).writeAsString('initial_data');

    await atomicWriteString(path, 'updated_data');

    expect(await File(path).readAsString(), 'updated_data');
    expect(File('$path.bak').existsSync(), isFalse);
    expect(
      dir.listSync().where((entry) => entry.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('atomicWriteString retries up to 5 times with exponential backoff on rename contention',
      () async {
    final dir = await Directory.systemTemp.createTemp('qisheng_atomic_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}settings.json';
    await File(path).writeAsString('initial_data');

    int attempts = 0;
    await atomicWriteStringForTesting(
      path,
      'updated_data',
      onRename: (temp, target, attempt) async {
        attempts++;
        if (attempt < 3) {
          throw const FileSystemException('Windows file lock simulation', '', OSError('Locked', 32));
        }
        await temp.rename(target.path);
      },
    );

    expect(attempts, 4); // Succeeded on 4th attempt (attempt index 3)
    expect(await File(path).readAsString(), 'updated_data');
    expect(File('$path.bak').existsSync(), isFalse);
  });

  test('atomicWriteString rolls back from .bak when all 5 rename retries are exhausted without truncating',
      () async {
    final dir = await Directory.systemTemp.createTemp('qisheng_atomic_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}settings.json';
    const originalContent = 'critical_untruncated_data';
    await File(path).writeAsString(originalContent);

    int attempts = 0;
    await expectLater(
      atomicWriteStringForTesting(
        path,
        'new_data_that_fails',
        onRename: (temp, target, attempt) async {
          attempts++;
          // Simulate target file corrupted/truncated mid-operation or rename lock
          if (target.existsSync()) {
            await target.writeAsString('', flush: true); // simulate corruption
          }
          throw const FileSystemException('Persistent antivirus lock', '', OSError('Locked', 32));
        },
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(attempts, 5);
    // Verified: original content is restored from .bak and NOT left as 0 bytes!
    expect(await File(path).readAsString(), originalContent);
    expect(
      dir.listSync().where((entry) => entry.path.endsWith('.tmp')),
      isEmpty,
    );
  });
}
