# Test Plan

## Strategy
Use a fix-test-fix loop:
1. Write or update the smallest test that describes the behavior.
2. Implement the change.
3. Re-run the same test.
4. Expand to related regression coverage.
5. Run the full suite before release.

## Required Command Set
- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter test --coverage` when practical
- `flutter build apk --debug`
- `flutter build apk --release` when the environment supports it
- `flutter test integration_test` on an Android tablet emulator

## Execution Order
1. Run `flutter pub get` after dependency changes.
2. Run `dart format .` before review.
3. Run `flutter analyze` to catch static issues early.
4. Run targeted `flutter test` files first.
5. Run `flutter test --coverage` when regression scope is broad enough to justify it.
6. Run the integration flow on a connected Android tablet emulator.
7. Run APK builds once tests are green.

## Coverage Areas
### Unit Tests
- Document numbering.
- Validation rules.
- Status transitions.
- Action item creation and updates.
- Search and duplicate rules.
- Export/import metadata handling.

### Widget Tests
- Dashboard state rendering.
- Section navigation.
- Required-field and flagged-item prompts.
- Review screen validation summaries.
- Signature and completion UI.
- Primary-route rendering at 412x915 portrait, 800x600, 1280x800, and 1600x1000.
- Dashboard, editor, list, detail, actions, and settings at 150% text scaling.
- Android tap-target, accessible-label, and text-contrast guidelines.
- Recipient validation and share-handoff confirmation.

### Integration Tests
- New inspection to completion.
- Photo capture or photo service fallback.
- PDF generation and file existence.
- Email/share handoff confirmation.
- Duplicate, export, and import flow.

### Regression Tests
- Clean pass inspection.
- Inspection with At Risk items.
- Inspection with Unsatisfactory items.
- Inspection with Critical / Out of Service items.
- Inspection with many photos.
- Inspection with hose replacement entries.
- Exported and re-imported inspection.
- Placeholder logo and sample media asset availability.

## Automated Matrix

| Area | States exercised |
| --- | --- |
| Record status | Draft, in progress, complete, emailed |
| Findings | Clean, monitor/at risk, unsatisfactory, critical/out of service |
| Evidence | No photo, camera/gallery photo, removed photo, many photos, signature retained/cleared |
| Persistence | New, edit, duplicate, reload, export, import, document conflict |
| Handoff | PDF generation, recipient history, share launch, explicit emailed confirmation |
| Layout | 412x915 portrait, 800x600, 1280x800, 1600x1000, 150% text scaling |
| Accessibility | Touch targets, labels, contrast, responsive overflow checks |

The host-side matrix runs with `flutter test`. Platform channels such as the camera, Android share sheet, file picker, and SQLite device storage still require the connected-device integration pass.

## Emulator Acceptance Flow
1. Launch the app.
2. Open the dashboard.
3. Create a new inspection.
4. Fill the required header fields.
5. Complete each fixed section.
6. Add a photo.
7. Trigger an At Risk validation path.
8. Trigger a Critical validation path and acknowledge lockout/tagout.
9. Add a structured hose replacement entry.
10. Capture the operational and follow-up information.
11. Add final comments.
12. Enter technician name and signature.
13. Complete the inspection.
14. Generate the PDF.
15. Open or share the PDF.
16. Confirm emailed status.
17. Return to the dashboard and verify counts.
18. Search, duplicate, export, and import the inspection.

Run both device suites on the connected Android tablet:

```sh
flutter test integration_test/production_app_smoke_test.dart -d <tablet-device-id>
flutter test integration_test/app_flow_test.dart -d <tablet-device-id>
```

## Regression Fixture Expectations
- Seeded fixtures should exercise clean, flagged, critical, and export/import states.
- Fixtures should include local photos, a drawn signature, and at least one generated PDF path.
- Fixture data should be deterministic so document-number assertions remain stable.
