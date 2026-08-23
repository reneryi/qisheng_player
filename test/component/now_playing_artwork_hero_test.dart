import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';

void main() {
  test('artwork hero arc keeps exact endpoints and a restrained apex', () {
    final tween = NowPlayingArtworkRectTween(
      begin: const Rect.fromLTWH(20, 700, 56, 56),
      end: const Rect.fromLTWH(300, 120, 420, 420),
    );

    expect(tween.lerp(0), tween.begin);
    expect(tween.lerp(1), tween.end);

    final linearMidpoint = Rect.lerp(tween.begin, tween.end, 0.5)!;
    final curvedMidpoint = tween.lerp(0.5)!;
    expect(curvedMidpoint.top, lessThan(linearMidpoint.top));
    expect(
      linearMidpoint.top - curvedMidpoint.top,
      lessThanOrEqualTo(40.01),
    );
  });
}
