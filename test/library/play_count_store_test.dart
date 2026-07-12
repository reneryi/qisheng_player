import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/library/play_count_store.dart';

void main() {
  test('PlayCountStore debounces repeated saves', () async {
    final persisted = <Map<String, int>>[];
    final store = PlayCountStore.forTesting(
      saveDebounceDuration: const Duration(milliseconds: 10),
      persist: (counts) async => persisted.add(counts),
    );

    await store.increaseByPath('song.flac');
    await store.increaseByPath('song.flac');
    await store.increaseByPath('song.flac');

    expect(store.getByPath('song.flac'), 3);
    expect(persisted, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(persisted, hasLength(1));
    expect(persisted.single['song.flac'], 3);
  });

  test('PlayCountStore save flushes a pending debounce', () async {
    final persisted = <Map<String, int>>[];
    final store = PlayCountStore.forTesting(
      saveDebounceDuration: const Duration(seconds: 1),
      persist: (counts) async => persisted.add(counts),
    );

    await store.increaseByPath('song.flac');
    await store.save();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(persisted, hasLength(1));
    expect(persisted.single['song.flac'], 1);
  });
}
