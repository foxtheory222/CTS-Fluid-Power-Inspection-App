import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'theme.dart';
import '../data/models/inspection_enums.dart';
import 'workspace_models.dart';

class AppWorkspaceController extends ChangeNotifier {
  AppWorkspaceController() : _inspections = _seedInspections();

  final List<InspectionSummary> _inspections;
  String _searchQuery = '';
  InspectionStatus? _statusFilter;

  String get searchQuery => _searchQuery;
  InspectionStatus? get statusFilter => _statusFilter;

  List<InspectionSummary> get inspections => List.unmodifiable(_inspections);

  List<InspectionSummary> get filteredInspections {
    final query = _searchQuery.trim().toLowerCase();
    return _inspections
        .where((inspection) {
          final matchesQuery =
              query.isEmpty || inspection.searchableText.contains(query);
          final matchesStatus =
              _statusFilter == null || inspection.status == _statusFilter;
          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
  }

  List<DashboardMetric> get dashboardMetrics => [
    DashboardMetric(
      label: 'Draft',
      value: _inspections
          .where((item) => item.status == InspectionStatus.draft)
          .length
          .toString(),
      icon: Icons.description_outlined,
      color: CtsPalette.slate,
      subtitle: 'Ready to continue',
    ),
    DashboardMetric(
      label: 'In Progress',
      value: _inspections
          .where((item) => item.status == InspectionStatus.inProgress)
          .length
          .toString(),
      icon: Icons.play_circle_outline,
      color: CtsPalette.orange,
      subtitle: 'Actively being filled out',
    ),
    DashboardMetric(
      label: 'Complete',
      value: _inspections
          .where((item) => item.status == InspectionStatus.complete)
          .length
          .toString(),
      icon: Icons.verified_outlined,
      color: CtsPalette.success,
      subtitle: 'Validated and signed',
    ),
    DashboardMetric(
      label: 'Emailed',
      value: _inspections
          .where((item) => item.status == InspectionStatus.emailed)
          .length
          .toString(),
      icon: Icons.mark_email_read_outlined,
      color: CtsPalette.info,
      subtitle: 'Handed off to the customer',
    ),
    DashboardMetric(
      label: 'Critical',
      value: _inspections
          .where((item) => item.criticalCount > 0)
          .length
          .toString(),
      icon: Icons.warning_amber_rounded,
      color: CtsPalette.danger,
      subtitle: 'LOTO attention required',
    ),
    DashboardMetric(
      label: 'Photos',
      value: _inspections
          .fold<int>(0, (sum, item) => sum + item.photoCount)
          .toString(),
      icon: Icons.photo_library_outlined,
      color: CtsPalette.orangeSoft,
      subtitle: 'Stored locally on device',
    ),
  ];

  InspectionSummary? inspectionById(String id) {
    for (final inspection in _inspections) {
      if (inspection.id == id) {
        return inspection;
      }
    }
    return null;
  }

  List<InspectionSummary> get recentInspections {
    final copy = List<InspectionSummary>.of(_inspections);
    copy.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
    return copy.take(6).toList(growable: false);
  }

  List<InspectionActionItemView> get openActionItems =>
      _inspections.expand((item) => item.actionItems).toList(growable: false);

  void setSearchQuery(String value) {
    if (value == _searchQuery) {
      return;
    }
    _searchQuery = value;
    notifyListeners();
  }

  void setStatusFilter(InspectionStatus? status) {
    if (status == _statusFilter) {
      return;
    }
    _statusFilter = status;
    notifyListeners();
  }

  InspectionSummary createInspection() {
    final now = DateTime.now();
    final documentNumber = _nextDocumentNumberForDate(now);
    final inspection = InspectionSummary(
      id: _makeId(documentNumber),
      documentNumber: documentNumber,
      customer: '',
      workOrderNumber: '',
      customerReference: '',
      assetName: '',
      siteLocation: '',
      technicianName: '',
      servicingShop: '',
      inspectionDateTime: now,
      createdAt: now,
      status: InspectionStatus.draft,
      sections: _defaultSections(),
      actionItems: [],
      photos: [],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: now,
    );
    _inspections.insert(0, inspection);
    notifyListeners();
    return inspection;
  }

  InspectionSummary duplicateInspection(InspectionSummary source) {
    final now = DateTime.now();
    final documentNumber = _nextDocumentNumberForDate(now);
    final clone = source.copyWith(
      id: _makeId(documentNumber),
      documentNumber: documentNumber,
      status: InspectionStatus.draft,
      createdAt: now,
      inspectionDateTime: now,
      completedAt: null,
      emailedAt: null,
      finalTechComments: null,
      criticalAcknowledged: false,
      generatedPdfPath: null,
      sections: _defaultSections(),
      actionItems: [],
      photos: [],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: now,
    );
    _inspections.insert(0, clone);
    notifyListeners();
    return clone;
  }

  void replaceInspection(InspectionSummary updated) {
    final index = _inspections.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      _inspections[index] = updated;
      notifyListeners();
    }
  }

  String _nextDocumentNumberForDate(DateTime date) {
    final dayStamp = DateFormat('yyyyMMdd').format(date);
    final matches = _inspections
        .where((item) => item.documentNumber.startsWith('$dayStamp-'))
        .length;
    final sequence = matches + 1;
    return '$dayStamp-${sequence.toString().padLeft(4, '0')}';
  }

  String _makeId(String documentNumber) {
    return 'inspection_${documentNumber.replaceAll('-', '_')}';
  }

  static List<InspectionSummary> _seedInspections() {
    final today = DateTime(2026, 4, 20, 8, 30);
    final yesterday = today.subtract(const Duration(days: 1));
    final inspection1 = InspectionSummary(
      id: 'inspection_20260420_0001',
      documentNumber: '20260420-0001',
      customer: 'Moraine Quarry',
      workOrderNumber: 'WO-48912',
      customerReference: 'PO-55412',
      assetName: 'HPU-12 Main Press',
      siteLocation: 'East Pit Service Bay',
      technicianName: 'R. Ellis',
      servicingShop: 'CTS Edmonton Service',
      inspectionDateTime: today,
      createdAt: today,
      status: InspectionStatus.complete,
      sections: _defaultSections(
        atRisk: 1,
        unsat: 1,
        critical: 0,
        photoCount: 5,
      ),
      actionItems: [
        InspectionActionItemView(
          title: 'Replace return hose at manifold',
          description:
              'Cracking near the fitting on hose H-12 was flagged during the inspection.',
          conditionRating: ConditionRating.unsatisfactory,
          sourceSection: 'Hose & Connection Inspection',
          sourceItem: 'Hose replacement entry',
          partsRequired: 'Hose assembly, two JIC fittings, crimp sleeves',
        ),
      ],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'As-found unit overview',
          sectionTitle: 'Job & Asset Identification',
          itemLabel: 'HPU wide shot',
          capturedAt: DateTime(2026, 4, 20, 8, 45),
        ),
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_2.jpg',
          caption: 'Tank nameplate close-up',
          sectionTitle: 'Component Tracking',
          itemLabel: 'Main Pump',
          capturedAt: DateTime(2026, 4, 20, 9, 10),
        ),
      ],
      flaggedCount: 2,
      atRiskCount: 1,
      unsatisfactoryCount: 1,
      criticalCount: 0,
      photoCount: 5,
      lastUpdatedAt: today.add(const Duration(minutes: 32)),
      completedAt: today.add(const Duration(hours: 1, minutes: 14)),
      finalTechComments:
          'Unit operating within service limits after hose replacement planning.',
      generatedPdfPath:
          '/storage/emulated/0/Download/CTS_Fluid_Power_Inspection_Report_20260420-0001.pdf',
    );

    final inspection2 = InspectionSummary(
      id: 'inspection_20260420_0002',
      documentNumber: '20260420-0002',
      customer: 'North Basin Processing',
      workOrderNumber: 'WO-48921',
      customerReference: 'JOB-7745',
      assetName: 'Transfer Pump Skid 04',
      siteLocation: 'North Tank Farm',
      technicianName: 'K. Morgan',
      servicingShop: 'CTS Calgary Service',
      inspectionDateTime: today.add(const Duration(hours: 2)),
      createdAt: today.add(const Duration(hours: 2)),
      status: InspectionStatus.emailed,
      sections: _defaultSections(
        atRisk: 2,
        unsat: 1,
        critical: 1,
        photoCount: 7,
      ),
      actionItems: [
        InspectionActionItemView(
          title: 'Lockout/Tagout before restart',
          description:
              'Critical tank integrity issue requires isolation until corrective work is complete.',
          conditionRating: ConditionRating.criticalOutOfService,
          sourceSection: 'Fluid & Tank Service',
          sourceItem: 'Tank integrity',
          partsRequired: 'Tank repair kit, lockout hardware',
        ),
        InspectionActionItemView(
          title: 'Replace breather element',
          description:
              'Breather housing contamination noted; element replacement recommended.',
          conditionRating: ConditionRating.monitorAtRisk,
          sourceSection: 'Filtration & Breather Service',
          sourceItem: 'Breather replaced?',
          partsRequired: 'Breather element 12-7781',
        ),
      ],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'Critical tank corrosion',
          sectionTitle: 'Fluid & Tank Service',
          itemLabel: 'Tank integrity',
          capturedAt: DateTime(2026, 4, 20, 10, 12),
        ),
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_2.jpg',
          caption: 'Gauges under load',
          sectionTitle: 'Operational Data / System Test',
          itemLabel: 'System test',
          capturedAt: DateTime(2026, 4, 20, 10, 18),
        ),
      ],
      flaggedCount: 3,
      atRiskCount: 2,
      unsatisfactoryCount: 1,
      criticalCount: 1,
      photoCount: 7,
      lastUpdatedAt: today.add(const Duration(hours: 2, minutes: 55)),
      completedAt: today.add(const Duration(hours: 3, minutes: 10)),
      emailedAt: today.add(const Duration(hours: 3, minutes: 42)),
      criticalAcknowledged: true,
      generatedPdfPath:
          '/storage/emulated/0/Download/CTS_Fluid_Power_Inspection_Report_20260420-0002.pdf',
    );

    final inspection3 = InspectionSummary(
      id: 'inspection_20260419_0001',
      documentNumber: '20260419-0001',
      customer: 'Prairie Rail Services',
      workOrderNumber: 'WO-48888',
      customerReference: 'PR-1182',
      assetName: 'Hydraulic Lift Cart 2',
      siteLocation: 'Maintenance Yard',
      technicianName: 'T. Singh',
      servicingShop: 'CTS Red Deer Service',
      inspectionDateTime: yesterday,
      createdAt: yesterday,
      status: InspectionStatus.inProgress,
      sections: _defaultSections(
        atRisk: 0,
        unsat: 0,
        critical: 0,
        photoCount: 2,
      ),
      actionItems: [],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'Asset identification photo',
          sectionTitle: 'Job & Asset Identification',
          itemLabel: 'HPU wide shot',
          capturedAt: DateTime(2026, 4, 19, 15, 01),
        ),
      ],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 2,
      lastUpdatedAt: yesterday.add(const Duration(hours: 1, minutes: 45)),
    );

    return [inspection2, inspection1, inspection3];
  }

  static List<InspectionSectionView> _defaultSections({
    int atRisk = 0,
    int unsat = 0,
    int critical = 0,
    int photoCount = 0,
  }) {
    return [
      InspectionSectionView(
        key: InspectionSectionKeys.jobAssetIdentification,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .jobAssetIdentification]!,
        completionState: SectionCompletionState.complete,
        summary: 'Header complete and photos captured.',
        photoCount: photoCount > 0 ? 2 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.componentTracking,
        title:
            inspectionSectionTitles[InspectionSectionKeys.componentTracking]!,
        completionState: SectionCompletionState.complete,
        summary: 'Nameplates and component notes captured.',
        photoCount: photoCount > 1 ? 2 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.fluidTankService,
        title: inspectionSectionTitles[InspectionSectionKeys.fluidTankService]!,
        completionState: critical > 0
            ? SectionCompletionState.blocked
            : atRisk > 0 || unsat > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: critical > 0
            ? 'Critical tank warning acknowledged.'
            : atRisk > 0 || unsat > 0
            ? 'Flagged fluid service items need follow-up.'
            : 'Fluid condition is within tolerance.',
        photoCount: photoCount > 2 ? 1 : 0,
        flaggedCount: atRisk + unsat + critical,
        criticalWarning: critical > 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.hoseConnectionInspection,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .hoseConnectionInspection]!,
        completionState: atRisk > 0 || unsat > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Hose replacement entries and fitting notes documented.',
        photoCount: photoCount > 3 ? 1 : 0,
        flaggedCount: atRisk > 0 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.filtrationBreatherService,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .filtrationBreatherService]!,
        completionState: atRisk > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Filter replacement statuses captured.',
        photoCount: photoCount > 4 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.operationalDataSystemTest,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .operationalDataSystemTest]!,
        completionState: SectionCompletionState.complete,
        summary: 'System test readings stored.',
        photoCount: photoCount > 5 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.followUpRepairsQuoting,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .followUpRepairsQuoting]!,
        completionState: atRisk > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Quoted parts and follow-up actions are tracked.',
        photoCount: photoCount > 6 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.reviewCompletion,
        title: inspectionSectionTitles[InspectionSectionKeys.reviewCompletion]!,
        completionState: atRisk > 0 || unsat > 0 || critical > 0
            ? SectionCompletionState.blocked
            : SectionCompletionState.complete,
        summary: 'Ready for signoff when validation is clear.',
        photoCount: 0,
        flaggedCount: atRisk + unsat + critical,
        criticalWarning: critical > 0,
      ),
    ];
  }
}
