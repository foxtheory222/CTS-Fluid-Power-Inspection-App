# AGENTS.md

## Purpose
This repository contains the CTS Fluid Power Inspection App, an offline-only Android tablet app for field inspections. These notes define the working rules, architecture direction, test loop, and release criteria for the codebase and its docs.

## Current Implementation Direction
- Flutter stable on Android tablets, with landscape-first layouts.
- Riverpod for state management.
- `go_router` for navigation.
- Local SQLite persistence for indexed inspection data.
- JSON aggregate bundles for export/import and inspection restore.
- Local files for photos, signatures, generated PDFs, and exported archives.
- No cloud dependency, no login, no GPS, and no score calculation in V1.

## Working Rules
- Keep the app offline-first and local-only.
- Do not add customer-facing references to internal tooling or design workflows.
- Preserve document numbers permanently.
- Do not leave TODOs, placeholders, dead flows, or untested paths.
- Prefer small, reviewable changes over broad rewrites.
- Do not revert changes made by others unless explicitly instructed.
- Keep docs aligned with the current code and package stack.

## Implementation Rules
- Keep UI tablet-first, wide-layout, and readable in landscape.
- Centralize document-number generation, status transitions, validation, and file-path logic.
- Store generated PDFs and captured media in inspection-scoped local folders.
- Ensure edits to emailed inspections clear emailed status until the report is sent again.
- Keep exports importable without network access.
- Use placeholder sample assets when the final brand asset is not available.

## Test Commands
- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter test --coverage`
- `flutter test integration_test/app_flow_test.dart`
- `flutter build apk --debug`
- `flutter build apk --release`

## Fix-Test-Fix Loop
1. Read the relevant spec document before changing behavior.
2. Write or update the smallest test that describes the change.
3. Implement the smallest coherent fix.
4. Re-run the targeted test immediately.
5. Expand to related unit, widget, regression, and integration coverage.
6. Re-run the broader suite until clean.
7. Verify the tablet emulator flow when UI, navigation, or storage behavior changes.

## Coding Rules
- Keep the data model deterministic and locally reproducible.
- Treat completion validation as a hard gate, not a hint.
- Keep email handoff as a device-share or mail-app flow, with local recipient history.
- Keep PDF generation local and deterministic.
- Keep media handling resumable, inspection-scoped, and file-system backed.
- Never assume network availability for any V1 workflow.

## Testing Rules
- Every behavior change needs coverage at the most appropriate level.
- Unit tests should cover document numbering, validation, status transitions, action item logic, and persistence rules.
- Widget tests should cover navigation, form states, and review/completion behavior.
- Integration tests should cover the end-to-end tablet flow.
- Regression tests should cover seeded inspection fixtures and import/export cases.

## Definition Of Done
- App launches on an Android tablet emulator in landscape mode.
- Dashboard, inspection editor, PDF generation, email handoff, export/import, search, duplicate, and edit flows work end to end.
- Completion validation blocks incomplete inspections and allows valid ones.
- Generated PDFs exist locally and are readable.
- All requested automated tests pass.
- The Android build succeeds.
- Documentation is current and consistent with implemented behavior.
