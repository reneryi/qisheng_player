# Progress — Milestone 2

Last visited: 2026-09-01T17:39:25+08:00

## Current Status: Completed & Verified

### Completed Tasks:
1. [x] Read Explorer 2 report & handoff, plus existing implementation files.
2. [x] Analyze current `lib/component/now_playing_artwork_hero.dart`, `lib/component/bottom_player_bar.dart`, `lib/page/now_playing_page/component_views.dart`.
3. [x] Check existing tests (`test/component/now_playing_artwork_hero_test.dart`, `test/page/now_playing_content_test.dart`, `test/component/bottom_player_bar_test.dart`, `test/e2e/`).
4. [x] Implement `lib/component/now_playing_artwork_hero.dart`:
   - Single unified `NowPlayingArtworkCard` (1:1 square, handles image, placeholder, radius, shadow, elevation)
   - Single-layer `nowPlayingArtworkFlightShuttleBuilder` with smooth dynamic `BorderRadius` and `BoxShadow` lerping
   - Arc-based `NowPlayingArtworkRectTween` with restrained physical parabolic curvature
   - Universal `NowPlayingArtworkHeroFrame` container with internal `RepaintBoundary`
5. [x] Implement `lib/component/bottom_player_bar.dart`:
   - Clean Hero subtree in `_TrackCover` using `NowPlayingArtworkCard`
6. [x] Implement `lib/page/now_playing_page/component_views.dart`:
   - Remove `FittedBox(fit: BoxFit.scaleDown)` wrapping `Column` in `_ImmersiveArtworkStage`
   - Decouple `_NowPlayingArtwork`: Hero contains pure `NowPlayingArtworkCard`; gestures (`GestureDetector`), 3D tilt `Transform`, and ambient glow are on the outside of Hero.
   - Clean up any vinyl record leftovers.
7. [x] Update / add tests in `test/component/now_playing_artwork_hero_test.dart`.
8. [x] Run `flutter analyze` (0 errors, 0 warnings).
9. [x] Run `flutter test test/e2e/` (248/248 passed) and full `flutter test` (531/531 passed).
10. [x] Write `handoff.md` and notify parent.
