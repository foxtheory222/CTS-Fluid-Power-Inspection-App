# Release Checklist

## Product
- V1 scope matches the approved spec.
- No cloud, login, GPS, or scoring features are present.
- All customer-facing text is clean and consistent.
- The app remains offline-only and local-only throughout the workflow.

## Functionality
- New, edit, duplicate, and search flows work.
- Completion validation blocks incomplete inspections.
- Critical items require lockout/tagout acknowledgement.
- PDF generation succeeds and stores a local file.
- Email/share handoff works and emailed status updates only after confirmation.
- Photos, signatures, and local file paths are stable.
- Visible controls map to working flows only.
- Logo and sample media assets resolve correctly in the app shell.

## Quality
- `dart format .` passes.
- `flutter analyze` passes.
- `flutter test` passes.
- `flutter test integration_test` passes on a tablet emulator.
- `flutter build apk --debug` passes.
- `flutter build apk --release` passes when supported by the environment.

## Release Artifacts
- APK is generated and verified.
- A sample inspection and generated PDF are available for QA.
- Documentation is current:
  - `README.md`
  - `docs/PRODUCT_SPEC.md`
  - `docs/UI_SPEC.md`
  - `docs/DATA_MODEL.md`
  - `docs/TEST_PLAN.md`
  - `docs/RELEASE_CHECKLIST.md`

## Final Check
- The app runs end to end on an Android tablet emulator.
- No known blockers remain.
- The release is ready for customer validation.
