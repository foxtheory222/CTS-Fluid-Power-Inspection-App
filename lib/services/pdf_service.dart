import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants.dart';
import '../features/pdf_report/pdf_report_models.dart';

class PdfService {
  PdfService({this.compress = true});

  final bool compress;

  static const String reportTitle = AppConstants.reportTitle;

  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy h:mm a');

  Future<Uint8List> generateInspectionReportBytes(
    InspectionReportData data, {
    bool includeLogoAsset = true,
  }) async {
    final theme = await _loadReportTheme();
    final document = pw.Document(
      title: reportTitle,
      author: 'CTS Fluid Power',
      subject: reportTitle,
      keywords: <String>[
        'CTS Fluid Power',
        'inspection',
        'report',
        data.documentNumber,
        data.workOrderNumber,
        data.customerReference,
        data.assetName,
        data.technicianName,
        'Private & confidential',
        if (data.criticalCount > 0) 'Lockout/Tagout',
      ].join(', '),
      compress: compress,
      theme: theme,
    );

    final resolvedLogo = includeLogoAsset
        ? await _resolveLogoImage(data)
        : null;
    final resolvedSignature = await _resolveSignatureImage(data.signature);
    final resolvedCustomerSignature = await _resolveSignatureImage(
      data.customerSignature,
    );
    final photoAssets = await _resolvePhotos(data.allPhotos);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 34),
        build: (_) => <pw.Widget>[
          _buildCoverPage(data, resolvedLogo),
          pw.NewPage(),
          _buildFlaggedSummaryPage(data),
          pw.NewPage(),
          ..._buildDetailPages(data, photoAssets),
          pw.NewPage(),
          _buildFollowUpPage(data),
          pw.NewPage(),
          _buildSignaturePage(
            data,
            resolvedLogo,
            resolvedSignature,
            resolvedCustomerSignature,
          ),
          pw.NewPage(),
          ..._buildMediaSummaryPages(photoAssets),
        ],
        footer: _buildFooter,
        textDirection: pw.TextDirection.ltr,
      ),
    );

    return document.save();
  }

  Future<pw.ThemeData> _loadReportTheme() async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final medium = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Medium.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PublicSans-Bold.ttf'),
    );
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: medium,
      boldItalic: bold,
      fontFallback: <pw.Font>[regular],
    );
  }

  Future<File> generateInspectionReportFile(
    InspectionReportData data, {
    required Directory outputDirectory,
    bool includeLogoAsset = true,
  }) async {
    final bytes = await generateInspectionReportBytes(
      data,
      includeLogoAsset: includeLogoAsset,
    );
    final fileName = buildReportFileName(data);
    final file = File(p.join(outputDirectory.path, fileName));
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String buildReportFileName(InspectionReportData data) {
    final safeCustomer = _sanitizeFilePart(data.customer);
    final safeWorkOrder = _sanitizeFilePart(data.workOrderNumber);
    return 'CTS_Fluid_Power_Inspection_Report_${data.documentNumber}_${safeCustomer}_$safeWorkOrder.pdf';
  }

  pw.Widget _buildCoverPage(InspectionReportData data, pw.ImageProvider? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Container(
                  width: 110,
                  height: 54,
                  margin: const pw.EdgeInsets.only(right: 16),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                )
              else
                _brandMark(),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _eyebrow('CTS Fluid Power'),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      reportTitle,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Professional field inspection record',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(data.statusLabel, _statusColor(data.status)),
            ],
          ),
          pw.SizedBox(height: 18),
          _summaryBand(data),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: _infoCard('Inspection Summary', [
                  _kv('Document number', data.documentNumber),
                  _kv('Customer', data.customer),
                  _kv('Work order', data.workOrderNumber),
                  _kv('Customer reference / PO', data.customerReference),
                  _kv('Asset / equipment', data.assetName),
                  _kv('Location / site', data.siteLocation),
                  _kv('Technician', data.technicianName),
                  _kv('Servicing shop', data.servicingShop),
                  _kv(
                    'Inspection date/time',
                    _formatDateTime(data.inspectionDateTime),
                  ),
                  _kv('Created', _formatDateTime(data.createdAt)),
                  if (data.completedAt != null)
                    _kv('Completed', _formatDateTime(data.completedAt!)),
                  if (data.emailedAt != null)
                    _kv('Emailed', _formatDateTime(data.emailedAt!)),
                ]),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 3,
                child: _infoCard('Counts', [
                  _kv('Flagged items', data.flaggedItemCount.toString()),
                  _kv('At Risk', data.atRiskCount.toString()),
                  _kv('Unsatisfactory', data.unsatisfactoryCount.toString()),
                  _kv('Critical', data.criticalCount.toString()),
                  _kv('Action items', data.actionItems.length.toString()),
                  _kv('Photos', data.photoCount.toString()),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          if (data.criticalCount > 0)
            _warningBanner(
              'Critical / Out of Service condition identified. Lockout/Tagout required. Unit must not be operated until corrective action is complete.',
              PdfColors.red800,
            ),
          if (data.finalTechComments != null &&
              data.finalTechComments!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _infoCard('Final Tech Comments', [
              pw.Text(
                data.finalTechComments!.trim(),
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildFlaggedSummaryPage(InspectionReportData data) {
    final flaggedRows = <List<String>>[];
    final flaggedItems = <InspectionReportItem>[];
    for (final section in data.sections) {
      for (final item in section.items) {
        if (!item.isFlagged) {
          continue;
        }
        flaggedItems.add(item);
        flaggedRows.add([
          section.title,
          item.label,
          item.conditionRating?.label ?? '-',
          _truncate(item.comment?.trim().isEmpty == true ? null : item.comment),
          item.photos.length.toString(),
        ]);
      }
    }

    return _pageSection('Flagged Items and Action-Required Summary', [
      if (data.criticalCount > 0)
        _warningBanner(
          'Critical / Out of Service condition identified. Lockout/Tagout required. Unit must not be operated until corrective action is complete.',
          PdfColors.red800,
        ),
      if (flaggedItems.isEmpty)
        _emptyState('No flagged items were recorded on this inspection.'),
      if (flaggedItems.isNotEmpty)
        _table(
          headers: const ['Section', 'Item', 'Condition', 'Comment', 'Photos'],
          rows: flaggedRows,
        ),
      pw.SizedBox(height: 10),
      _infoCard('Action Items', [
        if (data.actionItems.isEmpty)
          _emptyState('No action items recorded.')
        else
          ...data.actionItems.map(
            (item) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: _softBoxDecoration(),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          item.title,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                      ),
                      if (item.isAutoGenerated)
                        _statusPill('Auto', PdfColors.teal700),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    item.description,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  if (item.partsRequired != null &&
                      item.partsRequired!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Parts required: ${item.partsRequired}',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ]),
    ]);
  }

  List<pw.Widget> _buildDetailPages(
    InspectionReportData data,
    List<_ResolvedPhoto> photoAssets,
  ) {
    final pages = <pw.Widget>[];
    for (final section in data.sections) {
      pages.add(
        _pageSection(section.title, [
          if (section.subtitle != null && section.subtitle!.trim().isNotEmpty)
            pw.Text(
              section.subtitle!,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
            ),
          if (section.items.isEmpty)
            _emptyState('No entries recorded in this section.'),
          ...section.items.map(
            (item) => _itemCard(
              sectionTitle: section.title,
              item: item,
              photoAssets: photoAssets,
            ),
          ),
        ]),
      );
      if (section != data.sections.last) {
        pages.add(pw.NewPage());
      }
    }
    return pages;
  }

  pw.Widget _buildFollowUpPage(InspectionReportData data) {
    return _pageSection('Follow-Up Repairs and Quoting', [
      _infoCard('Additional Parts / Repairs Required', [
        if (data.actionItems.isEmpty)
          _emptyState('No follow-up items or quoting notes were recorded.')
        else
          ...data.actionItems.map(
            (item) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: _softBoxDecoration(),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.title,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    item.description,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ]),
      pw.SizedBox(height: 10),
      _infoCard('Final Technician Comments', [
        if (data.finalTechComments == null ||
            data.finalTechComments!.trim().isEmpty)
          _emptyState('No final comments were entered.')
        else
          pw.Text(
            data.finalTechComments!.trim(),
            style: const pw.TextStyle(fontSize: 10.5),
          ),
      ]),
    ]);
  }

  pw.Widget _buildSignaturePage(
    InspectionReportData data,
    pw.ImageProvider? logo,
    pw.ImageProvider? signature,
    pw.ImageProvider? customerSignature,
  ) {
    return _pageSection('Sign-off', [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 5,
            child: _infoCard('Signoff Details', [
              _kv('Technician', data.technicianName),
              _kv('Completion status', data.statusLabel),
              _kv(
                'Completed',
                data.completedAt == null
                    ? 'Not completed'
                    : _formatDateTime(data.completedAt!),
              ),
              _kv(
                'Emailed',
                data.emailedAt == null
                    ? 'Not emailed'
                    : _formatDateTime(data.emailedAt!),
              ),
              if (data.criticalCount > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: _warningBanner(
                    'Critical / Out of Service condition identified. Lockout/Tagout required. Unit must not be operated until corrective action is complete.',
                    PdfColors.red800,
                  ),
                ),
            ]),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            flex: 4,
            child: _signatureCard(
              title: 'Technician Signature',
              signature: data.signature,
              image: signature,
              fallbackSigner: data.technicianName,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      _signatureCard(
        title: 'Customer Signature',
        signature: data.customerSignature,
        image: customerSignature,
        fallbackSigner: data.customer,
      ),
      pw.SizedBox(height: 12),
      if (logo != null)
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: _softBoxDecoration(),
          child: pw.Row(
            children: [
              pw.Container(
                width: 96,
                height: 40,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Text(
                  'Private & confidential - generated by CTS Fluid Power Inspection App.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  pw.Widget _signatureCard({
    required String title,
    required InspectionReportSignature? signature,
    required pw.ImageProvider? image,
    required String fallbackSigner,
  }) {
    return _infoCard(title, [
      if (image != null)
        pw.Container(
          height: 100,
          padding: const pw.EdgeInsets.all(8),
          decoration: _signatureDecoration(),
          child: pw.Image(image, fit: pw.BoxFit.contain),
        )
      else
        _emptyState('No signature was captured.'),
      pw.SizedBox(height: 8),
      _kv('Signer', signature?.signerName ?? fallbackSigner),
      _kv(
        'Signed at',
        signature == null
            ? 'Not captured'
            : _formatDateTime(signature.signedAt),
      ),
    ]);
  }

  List<pw.Widget> _buildMediaSummaryPages(List<_ResolvedPhoto> photoAssets) {
    if (photoAssets.isEmpty) {
      return [
        _pageSection('Media Summary', [
          _emptyState('No photos were attached to this inspection.'),
        ]),
      ];
    }

    final widgets = <pw.Widget>[];
    for (var index = 0; index < photoAssets.length; index += 4) {
      final chunk = photoAssets.skip(index).take(4).toList(growable: false);
      widgets.add(
        _pageSection(index == 0 ? 'Media Summary' : 'Media Summary (continued)', [
          pw.Text(
            'Photos are grouped by inspection item and shown with captions for quick field review.',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: chunk.map(_mediaCard).toList(growable: false),
          ),
        ]),
      );
      if (index + 4 < photoAssets.length) {
        widgets.add(pw.NewPage());
      }
    }
    return widgets;
  }

  pw.Widget _itemCard({
    required String sectionTitle,
    required InspectionReportItem item,
    required List<_ResolvedPhoto> photoAssets,
  }) {
    final photos = photoAssets
        .where(
          (photo) =>
              photo.photo.sectionTitle == sectionTitle &&
              photo.photo.itemLabel == item.label,
        )
        .toList(growable: false);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: _cardDecoration(item.conditionRating),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.label,
                      style: pw.TextStyle(
                        fontSize: 11.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      item.value,
                      style: pw.TextStyle(
                        fontSize: 10.2,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.conditionRating != null)
                _statusPill(
                  item.conditionRating!.label,
                  _conditionColor(item.conditionRating!).shade,
                ),
            ],
          ),
          if (item.helperText != null &&
              item.helperText!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              item.helperText!.trim(),
              style: pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.blueGrey700,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
          if (item.comment != null && item.comment!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Comment: ${item.comment!.trim()}',
              style: const pw.TextStyle(fontSize: 9.8),
            ),
          ] else if (item.isFlagged) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Flagged items require a comment and at least one photo.',
              style: pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.red800,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
          if (item.tags.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.tags
                  .map(
                    (tag) => _miniTag(
                      tag,
                      PdfColors.blueGrey100,
                      PdfColors.blueGrey900,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (photos.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Photos (${photos.length})',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: photos
                  .take(4)
                  .map(_thumbnailCard)
                  .toList(growable: false),
            ),
            if (photos.length > 4) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                '+${photos.length - 4} more photo(s) included in the media summary pages.',
                style: pw.TextStyle(
                  fontSize: 9.3,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  pw.Widget _thumbnailCard(_ResolvedPhoto photo) {
    return pw.Container(
      width: 112,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 76,
            width: 112,
            decoration: _photoDecoration(),
            child: pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(photo.image, fit: pw.BoxFit.cover),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            photo.photo.caption.isNotEmpty
                ? photo.photo.caption
                : 'Untitled photo',
            style: pw.TextStyle(fontSize: 8.8, color: PdfColors.blueGrey800),
            maxLines: 2,
          ),
          pw.Text(
            photo.photo.sectionTitle,
            style: pw.TextStyle(fontSize: 7.8, color: PdfColors.blueGrey600),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  pw.Widget _mediaCard(_ResolvedPhoto photo) {
    return pw.Container(
      width: 250,
      padding: const pw.EdgeInsets.all(8),
      decoration: _softBoxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 150,
            decoration: _photoDecoration(),
            child: pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(photo.image, fit: pw.BoxFit.cover),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            photo.photo.caption.isNotEmpty
                ? photo.photo.caption
                : 'Untitled photo',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          _kv('Section', photo.photo.sectionTitle),
          _kv('Item', photo.photo.itemLabel),
          if (photo.photo.capturedAt != null)
            _kv('Captured', _formatDateTime(photo.photo.capturedAt!)),
          _kv('Order', photo.photo.sortOrder.toString()),
        ],
      ),
    );
  }

  pw.Widget _pageSection(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ),
              pw.Container(
                height: 4,
                width: 96,
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal700,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _infoCard(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: _softBoxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _summaryBand(InspectionReportData data) {
    return pw.Row(
      children: [
        _summaryTile(
          'Flagged',
          data.flaggedItemCount.toString(),
          PdfColors.orange700,
        ),
        pw.SizedBox(width: 8),
        _summaryTile(
          'At Risk',
          data.atRiskCount.toString(),
          PdfColors.amber800,
        ),
        pw.SizedBox(width: 8),
        _summaryTile(
          'Unsat.',
          data.unsatisfactoryCount.toString(),
          PdfColors.deepOrange700,
        ),
        pw.SizedBox(width: 8),
        _summaryTile(
          'Critical',
          data.criticalCount.toString(),
          PdfColors.red800,
        ),
        pw.SizedBox(width: 8),
        _summaryTile(
          'Actions',
          data.actionItems.length.toString(),
          PdfColors.teal800,
        ),
        pw.SizedBox(width: 8),
        _summaryTile(
          'Photos',
          data.photoCount.toString(),
          PdfColors.blueGrey800,
        ),
      ],
    );
  }

  pw.Widget _summaryTile(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _statusPill(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8.8,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _miniTag(String label, PdfColor background, PdfColor foreground) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8.2,
          color: foreground,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _warningBanner(String message, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        border: pw.Border.all(color: color, width: 1.2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        message,
        style: pw.TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _emptyState(String message) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: _softBoxDecoration(),
      child: pw.Text(
        message,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColors.blueGrey700,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.7),
      columnWidths: {
        for (var i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          children: headers
              .map(
                (header) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: row
                .map(
                  (value) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      value,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(
            fontSize: 9.8,
            color: PdfColors.blueGrey800,
          ),
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  pw.Widget _brandMark() {
    return pw.Container(
      width: 110,
      height: 54,
      margin: const pw.EdgeInsets.only(right: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(
          'CTS',
          style: pw.TextStyle(
            fontSize: 22,
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  pw.Widget _eyebrow(String label) {
    return pw.Text(
      label.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 8.5,
        color: PdfColors.teal800,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        'Private & confidential  |  Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey600),
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) => _footer(context);

  pw.BoxDecoration _softBoxDecoration() {
    return pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.8),
      borderRadius: pw.BorderRadius.circular(8),
    );
  }

  pw.BoxDecoration _cardDecoration(ReportConditionRating? rating) {
    if (rating == null) {
      return pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.blueGrey100, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      );
    }

    final palette = _conditionColor(rating);
    return pw.BoxDecoration(
      color: palette.background,
      border: pw.Border.all(color: palette.shade, width: 1),
      borderRadius: pw.BorderRadius.circular(8),
    );
  }

  pw.BoxDecoration _signatureDecoration() {
    return pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.blueGrey200, width: 1),
      borderRadius: pw.BorderRadius.circular(8),
    );
  }

  pw.BoxDecoration _photoDecoration() {
    return pw.BoxDecoration(
      color: PdfColors.blueGrey50,
      border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
      borderRadius: pw.BorderRadius.circular(6),
    );
  }

  String _formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime.toLocal());

  String _truncate(String? value, {int maxLength = 80}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '-';
    }
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - 3)}...';
  }

  static String _sanitizeFilePart(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return sanitized.isEmpty ? 'Inspection' : sanitized;
  }

  PdfColor _statusColor(InspectionReportStatus status) {
    switch (status) {
      case InspectionReportStatus.draft:
        return PdfColors.blueGrey700;
      case InspectionReportStatus.inProgress:
        return PdfColors.orange700;
      case InspectionReportStatus.complete:
        return PdfColors.teal800;
      case InspectionReportStatus.emailed:
        return PdfColors.blue800;
    }
  }

  _ConditionPalette _conditionColor(ReportConditionRating rating) {
    switch (rating) {
      case ReportConditionRating.satisfactory:
        return const _ConditionPalette(PdfColors.green50, PdfColors.green700);
      case ReportConditionRating.monitor:
        return const _ConditionPalette(PdfColors.amber50, PdfColors.amber700);
      case ReportConditionRating.unsatisfactory:
        return const _ConditionPalette(
          PdfColors.orange50,
          PdfColors.deepOrange700,
        );
      case ReportConditionRating.critical:
        return const _ConditionPalette(PdfColors.red50, PdfColors.red700);
    }
  }

  Future<pw.ImageProvider?> _resolveLogoImage(InspectionReportData data) async {
    final branding = data.branding;
    if (branding.logoBytes != null) {
      if (img.decodeImage(branding.logoBytes!) != null) {
        return pw.MemoryImage(branding.logoBytes!);
      }
      return null;
    }

    final assetPath = branding.logoAssetPath ?? 'assets/logo/cts_logo.png';
    try {
      final bytes = await rootBundle.load(assetPath);
      final rawBytes = bytes.buffer.asUint8List();
      if (img.decodeImage(rawBytes) != null) {
        return pw.MemoryImage(rawBytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<pw.ImageProvider?> _resolveSignatureImage(
    InspectionReportSignature? signature,
  ) async {
    if (signature == null) {
      return null;
    }
    if (signature.bytes != null) {
      if (img.decodeImage(signature.bytes!) != null) {
        return pw.MemoryImage(signature.bytes!);
      }
      return null;
    }
    if (signature.filePath != null && signature.filePath!.isNotEmpty) {
      final file = File(signature.filePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (img.decodeImage(bytes) != null) {
          return pw.MemoryImage(bytes);
        }
      }
    }
    return null;
  }

  Future<List<_ResolvedPhoto>> _resolvePhotos(
    List<InspectionReportPhoto> photos,
  ) async {
    final resolved = <_ResolvedPhoto>[];
    for (final photo in photos) {
      Uint8List? bytes;
      if (photo.bytes != null) {
        bytes = photo.bytes;
      } else if (photo.filePath != null && photo.filePath!.isNotEmpty) {
        final file = File(photo.filePath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      if (img.decodeImage(bytes) == null) {
        continue;
      }
      resolved.add(_ResolvedPhoto(photo: photo, image: pw.MemoryImage(bytes)));
    }
    return resolved;
  }
}

class _ResolvedPhoto {
  const _ResolvedPhoto({required this.photo, required this.image});

  final InspectionReportPhoto photo;
  final pw.ImageProvider image;
}

class _ConditionPalette {
  const _ConditionPalette(this.background, this.shade);

  final PdfColor background;
  final PdfColor shade;
}
