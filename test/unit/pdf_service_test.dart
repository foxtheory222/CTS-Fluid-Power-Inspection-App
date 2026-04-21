import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cts_fluid_power_inspection_app/features/pdf_report/pdf_report_models.dart';
import 'package:cts_fluid_power_inspection_app/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List photoOne;
  late Uint8List photoTwo;
  late Uint8List signatureBytes;

  setUpAll(() async {
    photoOne = _buildTestJpegBytes(0xFF1B4D8A);
    photoTwo = _buildTestJpegBytes(0xFF2B9AE2);
    signatureBytes = photoOne;
  });

  InspectionReportData buildReport({
    InspectionReportBranding branding = const InspectionReportBranding(),
  }) {
    return InspectionReportData(
      documentNumber: '20260418-0001',
      customer: 'North/West Hydraulics: Plant #1',
      workOrderNumber: 'WO-7788',
      customerReference: 'PO-4421',
      assetName: 'HPU-42 Main System',
      siteLocation: 'Edmonton Service Bay 3',
      technicianName: 'Alex Technician',
      servicingShop: 'CTS Edmonton',
      inspectionDateTime: DateTime(2026, 4, 18, 9, 30),
      createdAt: DateTime(2026, 4, 18, 9, 12),
      completedAt: DateTime(2026, 4, 18, 12, 5),
      emailedAt: DateTime(2026, 4, 18, 12, 15),
      status: InspectionReportStatus.emailed,
      finalTechComments:
          'Unit inspected offline. Tank cleaning and hose replacement recommended on next visit.',
      criticalAcknowledged: true,
      signature: InspectionReportSignature(
        bytes: signatureBytes,
        signerName: 'Alex Technician',
        signedAt: DateTime(2026, 4, 18, 12, 00),
      ),
      sections: [
        InspectionReportSection(
          key: 'job_asset_identification',
          title: 'Job & Asset Identification',
          subtitle: 'Inspection header and as-found photos.',
          items: [
            InspectionReportItem(
              label: 'Customer / Site Name',
              value: 'North/West Hydraulics',
              helperText: 'Mandatory header field.',
              photos: [
                InspectionReportPhoto(
                  bytes: photoOne,
                  caption: 'Unit wide shot',
                  sectionTitle: 'Job & Asset Identification',
                  itemLabel: 'Customer / Site Name',
                  capturedAt: DateTime(2026, 4, 18, 9, 15),
                ),
              ],
            ),
          ],
        ),
        InspectionReportSection(
          key: 'fluid_tank_service',
          title: 'Fluid & Tank Service',
          items: [
            InspectionReportItem(
              label: 'Tank Integrity',
              value: 'Minor rust and paint wear',
              conditionRating: ReportConditionRating.monitor,
              comment:
                  'Monitor corrosion around lower seam. Keep under review.',
              helperText: 'Flagged items require a comment and a photo.',
              photos: [
                InspectionReportPhoto(
                  bytes: photoTwo,
                  caption: 'Tank seam rust',
                  sectionTitle: 'Fluid & Tank Service',
                  itemLabel: 'Tank Integrity',
                  capturedAt: DateTime(2026, 4, 18, 10, 5),
                ),
                InspectionReportPhoto(
                  bytes: photoOne,
                  caption: 'Nameplate and tank area',
                  sectionTitle: 'Fluid & Tank Service',
                  itemLabel: 'Tank Integrity',
                  capturedAt: DateTime(2026, 4, 18, 10, 6),
                ),
              ],
            ),
            InspectionReportItem(
              label: 'Fluid Clarity',
              value: 'Milky / contaminated',
              conditionRating: ReportConditionRating.unsatisfactory,
              comment: 'Sample indicates contamination. Plan fluid change.',
              photos: [
                InspectionReportPhoto(
                  bytes: photoTwo,
                  caption: 'Fluid sample',
                  sectionTitle: 'Fluid & Tank Service',
                  itemLabel: 'Fluid Clarity',
                  capturedAt: DateTime(2026, 4, 18, 10, 20),
                ),
              ],
            ),
          ],
        ),
        InspectionReportSection(
          key: 'hose_connection_inspection',
          title: 'Hose & Connection Inspection',
          items: [
            InspectionReportItem(
              label: 'Overall Hose Condition',
              value: 'Critical wear noted on return line',
              conditionRating: ReportConditionRating.critical,
              comment:
                  'LOTO required. Replace return line assembly before start-up.',
              helperText:
                  'Identify the hose, failure type, and parts needed to build the replacement.',
              tags: const ['Return line', 'LOTO'],
              photos: [
                InspectionReportPhoto(
                  bytes: photoOne,
                  caption: 'Return line abrasion',
                  sectionTitle: 'Hose & Connection Inspection',
                  itemLabel: 'Overall Hose Condition',
                  capturedAt: DateTime(2026, 4, 18, 10, 45),
                ),
              ],
            ),
          ],
        ),
      ],
      actionItems: [
        const InspectionReportActionItem(
          title: 'Replace contaminated fluid and filter set',
          description:
              'Schedule service for fluid change, filter replacement, and flush.',
          partsRequired: 'Hydraulic fluid, return filter, breather',
          isAutoGenerated: true,
          conditionRating: ReportConditionRating.unsatisfactory,
        ),
        const InspectionReportActionItem(
          title: 'Replace return hose assembly',
          description:
              'Build new return hose with proper fittings and route to minimize abrasion.',
          partsRequired: 'Hose, ends, clamps, sleeve',
          isAutoGenerated: true,
          conditionRating: ReportConditionRating.critical,
        ),
      ],
      branding: branding,
    );
  }

  test('buildReportFileName sanitizes customer and work order', () {
    final data = buildReport();

    final fileName = PdfService.buildReportFileName(data);

    expect(
      fileName,
      'CTS_Fluid_Power_Inspection_Report_20260418-0001_North West Hydraulics Plant #1_WO-7788.pdf',
    );
  });

  test(
    'generateInspectionReportBytes renders report content and critical warning text',
    () async {
      final service = PdfService(compress: false);
      final data = buildReport();

      final bytes = await service.generateInspectionReportBytes(data);
      final pdfText = latin1.decode(bytes);

      expect(bytes, isNotEmpty);
      expect(pdfText, contains(PdfService.reportTitle));
      expect(pdfText, contains('Lockout/Tagout'));
      expect(pdfText, contains('WO-7788'));
      expect(pdfText, contains('PO-4421'));
      expect(pdfText, contains('HPU-42'));
      expect(pdfText, contains('Private'));
      expect(pdfText, contains('confidential'));
      expect(pdfText, contains('Alex'));
    },
  );

  test('generateInspectionReportBytes adds logo image when present', () async {
    final service = PdfService(compress: false);
    final withoutLogo = await service.generateInspectionReportBytes(
      buildReport(branding: const InspectionReportBranding()),
      includeLogoAsset: false,
    );
    final withExplicitLogo = await service.generateInspectionReportBytes(
      buildReport(branding: InspectionReportBranding(logoBytes: photoTwo)),
      includeLogoAsset: true,
    );

    expect(
      withExplicitLogo.lengthInBytes,
      greaterThan(withoutLogo.lengthInBytes),
    );
  });

  test('generateInspectionReportFile writes a non-empty pdf to disk', () async {
    final service = PdfService(compress: false);
    final tempDir = await Directory.systemTemp.createTemp(
      'cts_pdf_service_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = await service.generateInspectionReportFile(
      buildReport(),
      outputDirectory: tempDir,
    );

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(1000));
    expect(
      file.path,
      contains('CTS_Fluid_Power_Inspection_Report_20260418-0001_'),
    );
  });

  test(
    'generateInspectionReportFile writes a QA pdf to build output',
    () async {
      final service = PdfService(compress: false);
      final outputDirectory = Directory('build/qa_reports');
      await outputDirectory.create(recursive: true);

      final file = await service.generateInspectionReportFile(
        buildReport(),
        outputDirectory: outputDirectory,
      );

      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(1000));
    },
  );
}

Uint8List _buildTestJpegBytes(int colorValue) {
  final image = img.Image(width: 80, height: 80);
  final primary = img.ColorUint32.rgba(
    (colorValue >> 16) & 0xFF,
    (colorValue >> 8) & 0xFF,
    colorValue & 0xFF,
    255,
  );
  final secondary = img.ColorUint32.rgba(255, 255, 255, 255);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixel(x, y, x.isEven ? primary : secondary);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}
