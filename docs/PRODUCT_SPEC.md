# Product Spec

## Product
CTS Fluid Power Inspection App is a production-ready Android tablet app for fluid power inspection reporting. It replaces a manual field workflow with an offline inspection, photo capture, signoff, PDF generation, and email handoff flow.

## Implementation Direction
- Flutter stable on Android tablets.
- Riverpod for state management.
- `go_router` for navigation.
- Local SQLite storage for indexed inspection data.
- JSON aggregate bundles for export/import and inspection restore.
- Local file storage for photos, signatures, and generated PDFs.
- Default brand and sample assets live in `assets/logo/` and `assets/demo/`.

## V1 Goals
- Create new inspections.
- Edit previous inspections.
- Duplicate previous inspections without copying photos or signatures.
- Save all data locally.
- Search inspections locally.
- Generate a professional PDF report.
- Export and import individual inspections.
- Hand off the PDF through the device email or share flow.

## V1 Scope
### In Scope
- Offline-only operation.
- Local document numbering in `YYYYMMDD-0001` format.
- Dashboard with draft, in-progress, complete, emailed, and critical counts.
- Fixed inspection form with eight sections.
- Required comments and photos for flagged responses.
- Auto-created action items from flagged responses.
- Technician signoff with typed name, drawn signature, and timestamp.
- Local recent-recipient and customer-email mapping storage.
- Local export/import of inspection bundles.

### Out Of Scope
- Login or accounts.
- Cloud sync.
- Web dashboard.
- GPS capture.
- Score calculation.
- Multi-template editing in V1.
- Manager approval workflow in V1.

## Status Model
- Draft: created but not meaningfully started or missing required details.
- In Progress: saved responses exist but completion validation is not satisfied.
- Complete: completion validation passes and signoff is captured.
- Emailed: the PDF was handed off and the user confirmed it was emailed or sent.

## Core Rules
- Editing an emailed inspection clears emailed status and timestamp until it is sent again.
- Critical / Out of Service items require comment, photo, action item, and lockout/tagout acknowledgement.
- Flagged items include Monitor / At Risk, Unsatisfactory, and Critical / Out of Service.
- The app must never require internet access to work.
- Duplicate inspections must receive a new document number and new created timestamp.

## Inspection Flow
1. Create inspection and auto-generate document number.
2. Enter header/job details.
3. Complete each fixed inspection section.
4. Capture photos and comments where needed.
5. Review validation issues.
6. Capture technician name and signature.
7. Complete the inspection.
8. Generate the PDF.
9. Hand off the PDF for email or sharing.
10. Optionally mark the report as emailed after confirmation.

## Success Criteria
- The inspection can be completed end to end on an Android tablet.
- Required validation blocks incomplete records.
- Photos, signatures, PDFs, export bundles, and imports all work offline.
- Search and duplicate behaviors are correct and deterministic.
