# Milestone 1 Sub-Orchestrator Dispatch

## Working Directory
`e:\PyCharmSave\qisheng_player\.agents\sub_orch_m1`

## Scope: Milestone 1 — Vinyl Removal & Pure Cover Layout
- Scope files: `PROJECT.md`, `ORIGINAL_REQUEST.md`, `e:\PyCharmSave\qisheng_player\.agents\explorer_survey_1\report.md`
- Mission:
  1. Complete removal of `lib/component/ui/vinyl_record_player_view.dart`.
  2. Clean `showVinylRecord` from `lib/app_settings.dart` and `AppSettings.readFromJson`/`toJson`.
  3. Remove `ShowVinylRecordSwitch` from `lib/page/settings_page/theme_settings.dart` and mount point in `lib/page/settings_page/page.dart`.
  4. Remove unused imports in `lib/page/now_playing_page/page.dart` and the `if (showVinyl)` branch in `lib/page/now_playing_page/component_views.dart`.
  5. Ensure standard pure album art layout operates without regressions.
  6. Execute Explorer -> Worker -> Reviewers (2) -> Challengers (2) -> Forensic Auditor -> Gate loop.
  7. Verify with `flutter analyze` and tests. Write `handoff.md` upon completion.
