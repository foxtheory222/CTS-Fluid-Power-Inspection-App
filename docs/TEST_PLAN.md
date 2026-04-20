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
- Local inspection persistence and PDF file generation.

### Widget Tests
- Dashboard state rendering.
- Section navigation.
- Required-field and flagged-item prompts.
- Review screen validation summaries.
- Signature and completion UI.

### Integration Tests
- New inspection to completion.
- Photo capture or photo service fallback.
- PDF generation and file existence.
- Email/share handoff confirmation.
- Duplicate and local persistence flow.

### Regression Scope
- Re-run the full unit, widget, and emulator flow after changes to persistence, validation, sharing, navigation, or report generation.
- Verify logo assets and bundled sample media continue to resolve.

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
18. Search and duplicate the inspection.

## Regression Fixture Expectations
- Test data should exercise clean, flagged, and critical states.
- Test data should include local photos, a drawn signature, and a generated PDF path.
- Fixture data should be deterministic so document-number assertions remain stable.
