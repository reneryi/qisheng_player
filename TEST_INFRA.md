# Qisheng Player E2E Test Infrastructure Specification

## 1. Architecture Overview: 4-Tier Test Pyramid

To ensure the highest standard of quality, motion fluidity, and layout stability across the Qisheng Player Transition & Layout Refactor, the End-to-End (E2E) test suite is structured into a rigorous 4-Tier testing pyramid:

```
                  ┌─────────────────────────────────────────┐
                  │ Tier 4: Real-World Application Scenarios│  (Comprehensive End-to-End User Journeys)
                  ├─────────────────────────────────────────┤
                  │ Tier 3: Cross-Feature Combinations      │  (Pairwise & Multi-Feature Interactions)
                  ├─────────────────────────────────────────┤
                  │ Tier 2: Boundary & Corner Cases         │  (≥5 Boundary Cases per Feature = 55+ Tests)
                  ├─────────────────────────────────────────┤
                  │ Tier 1: Feature Coverage                │  (≥5 Isolated Cases per Feature = 55+ Tests)
                  └─────────────────────────────────────────┘
```

All test cases are implemented using Flutter's official test harness (`package:flutter_test`), providing deterministic frame pumping, ticker simulation, geometry validation, gesture injection, and widget tree inspection.

---

## 2. Feature Inventory & Coverage Mapping

The 11 core refactored features defined in `PROJECT.md` are systematically covered across all 4 tiers:

| # | Feature | Milestone | Tier 1 (Coverage) | Tier 2 (Boundary) | Tier 3 (Cross) | Tier 4 (Real-World) |
|---|---------|-----------|-------------------|-------------------|----------------|---------------------|
| 1 | **Vinyl Code Clean Removal** | M1 | T1.1.1 ~ T1.1.5 | T2.1.1 ~ T2.1.5 | T3.1, T3.5 | Journey A, C |
| 2 | **Vinyl Settings & Pref Clean** | M1 | T1.2.1 ~ T1.2.5 | T2.2.1 ~ T2.2.5 | T3.2, T3.6 | Journey A, B |
| 3 | **Pure Cover Layout Standardization** | M1 | T1.3.1 ~ T1.3.5 | T2.3.1 ~ T2.3.5 | T3.1, T3.3 | Journey A, B, C |
| 4 | **Hero Subtree Alignment & Decoupling** | M2 | T1.4.1 ~ T1.4.5 | T2.4.1 ~ T2.4.5 | T3.3, T3.4 | Journey A, D |
| 5 | **Flight Shuttle & Tween Geometry Refactor** | M2 | T1.5.1 ~ T1.5.5 | T2.5.1 ~ T2.5.5 | T3.4, T3.7 | Journey A, D |
| 6 | **Coordinate Stability (No FittedBox)** | M2 | T1.6.1 ~ T1.6.5 | T2.6.1 ~ T2.6.5 | T3.3, T3.8 | Journey B, D |
| 7 | **Shell Transition & Scale Push-back** | M3 | T1.7.1 ~ T1.7.5 | T2.7.1 ~ T2.7.5 | T3.2, T3.5 | Journey A, D |
| 8 | **Staged Reveal Timeline Choreography** | M3 | T1.8.1 ~ T1.8.5 | T2.8.1 ~ T2.8.5 | T3.6, T3.7 | Journey A, C |
| 9 | **120fps GPU Texture Caching & Optimization** | M3 | T1.9.1 ~ T1.9.5 | T2.9.1 ~ T2.9.5 | T3.7, T3.8 | Journey B, C |
| 10 | **MainLayoutFrame Animated Insets** | M4 | T1.10.1 ~ T1.10.5 | T2.10.1 ~ T2.10.5 | T3.8, T3.1 | Journey B, D |
| 11 | **Comprehensive E2E Verification & Hardening** | M5 | T1.11.1 ~ T1.11.5 | T2.11.1 ~ T2.11.5 | T3.1 ~ T3.8 | Full Journeys |

---

## 3. Tier Specifications

### Tier 1: Feature Coverage (Isolated Functional Verification)
Each feature possesses at least 5 isolated, independent test cases verifying its primary happy path, property invariants, and contract compliance:
- **Feature 1 (Vinyl Removal)**: Verifies that legacy vinyl widgets are completely unreferenced, pure cover is the sole presentation, and no vinyl artifacts load.
- **Feature 2 (Settings Clean)**: Verifies preference defaults, serialization/deserialization without `showVinylRecord`, absence of toggles in settings UI, and setting mutation stability.
- **Feature 3 (Pure Cover Standardization)**: Verifies 1:1 aspect ratio, responsive sizing in small/large screens, image fallback placeholder, and multi-resolution cover selection.
- **Feature 4 (Hero Subtree Alignment)**: Verifies symmetry of `nowPlayingArtworkHeroTag`, identical child framing (`NowPlayingArtworkHeroFrame`), gesture outer isolation, and background glow detachment.
- **Feature 5 (Flight Shuttle & RectTween)**: Verifies `NowPlayingArtworkRectTween` endpoint precision, upward parabolic arc apex constraint, single-layer alpha/shadow interpolation, and non-stack flight shuttle rendering.
- **Feature 6 (Coordinate Stability)**: Verifies absence of `FittedBox` on Hero targets, exact coordinate preservation under layout changes, and stable render transform matrices.
- **Feature 7 (Shell Transition)**: Verifies single underlay transition driver, `Interval(0.0, 0.48)` opacity curve, `Scale: 1.0 -> 0.96` spatial push-back, and pointer ignore gating.
- **Feature 8 (Staged Reveal Timeline)**: Verifies the 6-stage interval timeline (Hero 0.0~1.0, AppBar 0.12~0.48, Title/Artist 0.24~0.68, Metadata 0.30~0.75, Lyric 0.34~0.90, Controls >=0.82) and entrance lyric scroll locking.
- **Feature 9 (120fps GPU Texture Caching)**: Verifies `RepaintBoundary` wrapping on blur/glow and visualizer layers, performance mode fallback, and ticker dormancy when backgrounded.
- **Feature 10 (MainLayoutFrame Animated Insets)**: Verifies 220ms `Curves.easeOutCubic` animated padding for `topInset`, `sideInset`, `bottomInset`, and `dockInset` calculation under all layout modes.
- **Feature 11 (Hardening & Verification)**: Verifies contract validation suites, memory leak safety, null safety checks, and zero-exception resilience.

### Tier 2: Boundary & Corner Cases
Each feature is tested against at least 5 boundary, edge, and extreme scenarios:
- Extreme screen resolutions (ultrawide 3840×1080, compact 320×480, zero/infinite viewport bounds).
- Null, missing, corrupt, or gigantic cover images and metadata.
- Rapid concurrent state mutations (rapid play/pause/skip during active Hero flights).
- Extreme animation interruptions (instant route popping mid-transition).
- Rapid window maximization and restore toggling while lyrics are scrolling.
- Zero-duration and infinite audio tracks, extreme seek positions (negative, beyond track length).
- Audio format badges with empty, malformed, or unusual codec data.
- Lyric zooming extremes (font scale 0.5x to 2.5x clamping, empty lyrics, single-line lyrics, 10,000-line lyrics).

### Tier 3: Cross-Feature Combinations
Pairwise and cross-cutting interaction tests verifying stability when multiple subsystems execute simultaneously:
- **T3.1**: Window maximize transition occurring simultaneously with Hero flight transition.
- **T3.2**: Shell underlay fade & scale push-back combined with theme change (Dark ↔ Light).
- **T3.3**: Track switch triggered mid-flight while Hero is interpolating coordinates.
- **T3.4**: 3D pan drag gesture on cover artwork during window resize and staged reveal.
- **T3.5**: Rapid push-pop navigation storm (opening and closing NowPlayingPage 10 times in quick succession).
- **T3.6**: Auto-hide bottom player bar timer expiration combined with lyric scale pinch-zoom.
- **T3.7**: Spectrum visualizer high-frequency updates concurrent with cover breath glow animation and RepaintBoundary caching.
- **T3.8**: Dock inset dynamic recalculation with overlay bar appearance/disappearance in maximized layout mode.

### Tier 4: Real-World Application Scenarios
End-to-End journeys validating complete user flows:
- **Journey A (Full Playback & Immersion Cycle)**: User starts on library page -> taps play on a song -> bottom player bar renders cover & animated track marquee -> taps cover -> smooth Hero flight into `NowPlayingPage` -> 6-stage reveal sequence completes -> lyric view synchronizes -> taps back button -> smooth reverse Hero flight back to shell.
- **Journey B (Window Management & Interaction Flow)**: App starts in windowed mode -> user maximizes window (smooth insets interpolate) -> navigates to `NowPlayingPage` -> performs 3D pan tilt on album art -> spring physics returns art -> controls auto-hide after 5s -> user clicks bottom screen area to wake controls -> restores window.
- **Journey C (Continuous Playback & Mode Switching)**: User listens in `NowPlayingPage` -> skips through playlist -> covers smoothly cross-fade -> audio metadata badges update -> spectrum bars pulse -> toggles theme modes -> toggles spectrum visibility -> scrolls lyric stream.
- **Journey D (Stress & Extreme Navigation Flow)**: Heavy rapid multi-route traversal between Audio Details, Playlist Details, Search Results, and NowPlayingPage under low-end and high-end graphics effect modes.

---

## 4. Test Suite File Structure

```
test/
└── e2e/
    ├── e2e_test_helpers.dart              # Test harness, fake controllers, mock data, and pumping utilities
    ├── tier1_feature_coverage_test.dart   # Tier 1: 55+ isolated feature test cases
    ├── tier2_boundary_corner_test.dart    # Tier 2: 55+ boundary & extreme corner case tests
    ├── tier3_cross_feature_test.dart      # Tier 3: Pairwise & multi-feature combination tests
    ├── tier4_real_world_scenario_test.dart# Tier 4: End-to-end full application user journeys
    └── all_e2e_test.dart                  # Master test runner aggregating Tiers 1-4
```

---

## 5. Execution & Verification Commands

```powershell
# Run the complete E2E test suite
flutter test test/e2e/all_e2e_test.dart

# Run individual tiers
flutter test test/e2e/tier1_feature_coverage_test.dart
flutter test test/e2e/tier2_boundary_corner_test.dart
flutter test test/e2e/tier3_cross_feature_test.dart
flutter test test/e2e/tier4_real_world_scenario_test.dart

# Verify static analysis compliance
flutter analyze test/e2e/
```
