# CTS Fluid Power Inspection App

CTS Fluid Power Inspection App is an offline-only Flutter tablet application for fluid power inspection reporting in the field. It is designed for Android tablets in landscape orientation and stores all data locally on the device.

## What It Does
- Create, edit, duplicate, search, export, and import inspection records.
- Capture inspection photos, technician signature, and section-specific findings.
- Generate a branded PDF report locally.
- Hand off the PDF through the device email or share flow.
- Keep all inspection data local with no login and no cloud dependency.

## UI Direction
- The tablet UI was implemented directly in Flutter using the approved industrial visual direction because the design MCP service was not exposed in this workspace.
- The current shell uses a deep navy surface, slate navigation, safety orange accents, Public Sans headings, and Inter body text.
- Use local SQLite storage for indexed records and self-contained ZIP restore bundles for export/import.

## Repository Docs
- [Product Spec](docs/PRODUCT_SPEC.md)
- [UI Spec](docs/UI_SPEC.md)
- [Data Model](docs/DATA_MODEL.md)
- [Test Plan](docs/TEST_PLAN.md)
- [Release Checklist](docs/RELEASE_CHECKLIST.md)
- [Agent Workflow](AGENTS.md)

## Expected Stack
- Flutter stable
- Dart stable
- Android tablet target
- Local SQLite persistence
- Riverpod for state management
- go_router for navigation
- Local file storage for photos, signatures, PDFs, and export bundles

## Assets
- `assets/logo/cts_logo.png` is the default brand logo slot.
- `assets/demo/sample_photo_1.jpg` and `assets/demo/sample_photo_2.jpg` are local sample media assets.
- If the final logo is unavailable, the placeholder logo asset remains in place until it is replaced.
- Fonts are stored locally under `assets/fonts/`.

## Local Setup
1. Install the Flutter stable SDK.
2. Install Android Studio and the Android SDK.
3. Create or open an Android tablet emulator, preferably in landscape mode.
4. Run `flutter pub get`.
5. Run `dart format .`.
6. Run `flutter analyze`.
7. Run `flutter test`.

## Run On Emulator
1. Start a tablet emulator such as Pixel Tablet.
2. Verify the emulator is in landscape orientation.
3. Launch the app with `flutter run`.
4. Complete the inspection flow described in [Test Plan](docs/TEST_PLAN.md).

## Build
- Debug APK: `flutter build apk --debug`
- Release APK: `flutter build apk --release`

## Testing
- Unit, widget, and integration coverage is required.
- Run `flutter test integration_test/app_flow_test.dart` on a connected Android tablet emulator for the end-to-end flow.
- Run the full regression flow after changes to validation, persistence, PDF generation, export/import, or navigation.
- If the integration test is updated, re-run it on a tablet emulator before release.

## Storage And Data
- The app stores inspections in local SQLite and keeps photos, PDFs, and export files on disk.
- Export/import uses a local ZIP bundle with a versioned JSON manifest, photos, signatures, and any generated PDF so an inspection can be restored offline.
- No cloud service, API key, or server connection is required for V1.
