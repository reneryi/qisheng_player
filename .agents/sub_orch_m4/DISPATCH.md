# Milestone 4 Sub-Orchestrator Dispatch

## Working Directory
`e:\PyCharmSave\qisheng_player\.agents\sub_orch_m4`

## Scope: Milestone 4 — MainLayoutFrame Insets Smooth Animation
- Scope files: `PROJECT.md`, `ORIGINAL_REQUEST.md`, `e:\PyCharmSave\qisheng_player\.agents\explorer_survey_3\report.md`
- Mission:
  1. Refactor `lib/component/main_layout_frame.dart` to replace static `Padding` and `Positioned` with `AnimatedPadding` and `AnimatedPositioned` (duration 220ms, `Curves.easeOutCubic`).
  2. Smooth transitions for `topInset`, `sideInset`, `bottomInset`, and `dockInset` when window state changes between maximized, normal, and fullscreen.
  3. Ensure no jitter or unnecessary layout calculation when dragging or resizing windows smoothly.
  4. Execute Explorer -> Worker -> Reviewers (2) -> Challengers (2) -> Forensic Auditor -> Gate loop.
  5. Verify with `flutter test test/component/main_layout_frame_test.dart` and `flutter analyze`. Write `handoff.md` upon completion.
