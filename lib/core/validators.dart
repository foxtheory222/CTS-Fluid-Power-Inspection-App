import '../data/models/inspection_enums.dart';
import '../data/models/inspection_models.dart';
import 'constants.dart';

class ValidationIssue {
  const ValidationIssue({
    required this.sectionKey,
    this.itemKey,
    required this.message,
    this.severity = ValidationSeverity.error,
  });

  final String sectionKey;
  final String? itemKey;
  final String message;
  final ValidationSeverity severity;
}

class ValidationResult {
  const ValidationResult(this.issues);

  final List<ValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

class InspectionValidator {
  static ValidationResult validateForCompletion(InspectionRecord inspection) {
    final List<ValidationIssue> issues = <ValidationIssue>[];

    void requireHeader(String value, String message) {
      if (value.trim().isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.jobAssetIdentification,
            message: message,
          ),
        );
      }
    }

    requireHeader(inspection.workOrderNumber, 'Work order number is required.');
    requireHeader(inspection.customer, 'Customer is required.');
    requireHeader(inspection.assetName, 'Asset / equipment name is required.');
    requireHeader(
      inspection.customerReference,
      'Customer reference / PO / job number is required.',
    );
    requireHeader(inspection.siteLocation, 'Location / site is required.');
    requireHeader(inspection.technicianName, 'Technician name is required.');
    requireHeader(inspection.servicingShop, 'Servicing shop is required.');

    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidLevel,
      message: 'Fluid Level must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidClarity,
      message: 'Fluid Clarity must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankIntegrity,
      message: 'Tank Integrity must be rated.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankCleanoutPerformed,
      message: 'Tank Cleanout Performed must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.hoseConnectionInspection,
      itemKey: InspectionItemKeys.overallHoseCondition,
      message: 'Overall Hose Condition must be rated.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherPartNumber,
      message: 'Breather Part Number is required.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherReplaced,
      message: 'Breather Replaced must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterPartNumber,
      message: 'Pressure Filter PN is required.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterReplaced,
      message: 'Pressure Filter Replaced must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterPartNumber,
      message: 'Return Filter PN is required.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterReplaced,
      message: 'Return Filter Replaced must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.equipmentRunning,
      message: 'Running equipment status must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.pumpCompensatorSetting,
      message: 'Pump Compensator Setting Observed is required.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changePumpCompensator,
      message: 'Pump compensator change decision must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.systemReliefSetting,
      message: 'System Relief Setting Observed is required.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changeSystemRelief,
      message: 'System relief change decision must be answered.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperature,
      message: 'Operating Temperature is required.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperatureUnit,
      message: 'Operating Temperature unit must be selected.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.accumulatorPreCharge,
      message: 'Accumulator Pre-charge is required.',
    );
    _requireAnsweredResponse(
      inspection,
      issues,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.chargeAccumulator,
      message: 'Accumulator charge decision must be answered.',
    );

    for (final InspectionResponse response in inspection.responses) {
      final bool isFlagged =
          response.isFlagged || (response.conditionRating?.isFlagged ?? false);
      if (!isFlagged) {
        continue;
      }

      if ((response.comment ?? '').trim().isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            message: '${response.itemLabel} requires a comment.',
          ),
        );
      }

      if (inspection.photosForItem(response.itemKey).isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            message: '${response.itemLabel} requires at least one photo.',
          ),
        );
      }

      final bool hasActionItem = inspection.actionItems.any((
        ActionItem actionItem,
      ) {
        return actionItem.sourceSectionKey == response.sectionKey &&
            actionItem.sourceItemKey == response.itemKey;
      });
      if (!hasActionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            message: '${response.itemLabel} requires a linked action item.',
          ),
        );
      }
    }

    for (final HoseEntry hoseEntry in inspection.hoseEntries) {
      if (!hoseEntry.hasFailure) {
        continue;
      }
      final String hoseKey = 'hose:${hoseEntry.id}';
      final bool hasActionItem = inspection.actionItems.any((
        ActionItem actionItem,
      ) {
        return actionItem.sourceItemKey == hoseKey;
      });
      if (!hasActionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.hoseConnectionInspection,
            itemKey: hoseKey,
            message: 'Failed hose entry requires an action item.',
          ),
        );
      }
    }

    for (final FilterEntry filterEntry in inspection.filterEntries) {
      if (filterEntry.replacedStatus != FilterReplacementStatus.no &&
          !(filterEntry.conditionRating?.isFlagged ?? false)) {
        continue;
      }
      final String filterKey = 'filter:${filterEntry.id}';
      if ((filterEntry.notes ?? '').trim().isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.filtrationBreatherService,
            itemKey: filterKey,
            message: 'Filter replacement entries require a comment.',
          ),
        );
      }
      if (inspection.photosForItem(filterKey).isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.filtrationBreatherService,
            itemKey: filterKey,
            message: 'Filter replacement entries require at least one photo.',
          ),
        );
      }
      final bool hasActionItem = inspection.actionItems.any((
        ActionItem actionItem,
      ) {
        return actionItem.sourceItemKey == filterKey;
      });
      if (!hasActionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.filtrationBreatherService,
            itemKey: filterKey,
            message: 'Filter replacement entries require a linked action item.',
          ),
        );
      }
    }

    for (final InspectionPhoto photo in inspection.photos) {
      final int perItemCount = inspection.photosForItem(photo.itemKey).length;
      if (perItemCount > AppConstants.maxPhotosPerInspectionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: photo.sectionKey,
            itemKey: photo.itemKey,
            message:
                'No more than ${AppConstants.maxPhotosPerInspectionItem} photos are allowed per item.',
          ),
        );
      }
    }

    if (inspection.hasCriticalItems && !inspection.criticalAcknowledged) {
      issues.add(
        ValidationIssue(
          sectionKey: InspectionSectionKeys.reviewCompletion,
          itemKey: InspectionItemKeys.criticalAcknowledgement,
          message: AppConstants.lotOWarning,
        ),
      );
    }

    if ((inspection.signatureFilePath ?? '').trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: InspectionSectionKeys.reviewCompletion,
          itemKey: InspectionItemKeys.technicianSignature,
          message: 'Technician signature is required.',
        ),
      );
    }

    final InspectionResponse? additionalRepairsResponse = inspection
        .responseByKey(
          InspectionSectionKeys.followUpRepairsQuoting,
          InspectionItemKeys.additionalPartsRepairs,
        );
    if ((additionalRepairsResponse?.value ?? '').trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: InspectionSectionKeys.followUpRepairsQuoting,
          itemKey: InspectionItemKeys.additionalPartsRepairs,
          message: 'Additional parts / repairs decision must be answered.',
        ),
      );
    }
    if ((additionalRepairsResponse?.value ?? '') == 'yes' &&
        inspection.requiredItems.isEmpty &&
        inspection.actionItems.isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: InspectionSectionKeys.followUpRepairsQuoting,
          itemKey: InspectionItemKeys.additionalPartsRepairs,
          message:
              'Additional parts / repairs requires at least one required item or action item.',
        ),
      );
    }

    return ValidationResult(issues);
  }

  static InspectionStatus deriveStatus(InspectionRecord inspection) {
    if (inspection.emailedAt != null) {
      return InspectionStatus.emailed;
    }
    final ValidationResult result = validateForCompletion(inspection);
    if (result.isValid && inspection.completedAt != null) {
      return InspectionStatus.complete;
    }
    if (_hasMeaningfulProgress(inspection)) {
      return InspectionStatus.inProgress;
    }
    return InspectionStatus.draft;
  }

  static bool _hasMeaningfulProgress(InspectionRecord inspection) {
    return inspection.customer.trim().isNotEmpty ||
        inspection.workOrderNumber.trim().isNotEmpty ||
        inspection.responses.isNotEmpty ||
        inspection.photos.isNotEmpty ||
        inspection.componentEntries.any(
          (ComponentEntry entry) =>
              (entry.modelPartNumber ?? '').trim().isNotEmpty ||
              (entry.serialNumber ?? '').trim().isNotEmpty,
        ) ||
        inspection.hoseEntries.any(
          (HoseEntry entry) =>
              (entry.hoseNameLocation ?? '').trim().isNotEmpty ||
              entry.failureType != null,
        ) ||
        inspection.filterEntries.any(
          (FilterEntry entry) =>
              (entry.filterName ?? '').trim().isNotEmpty ||
              (entry.partNumber ?? '').trim().isNotEmpty,
        );
  }

  static void _requireAnsweredResponse(
    InspectionRecord inspection,
    List<ValidationIssue> issues, {
    required String sectionKey,
    required String itemKey,
    required String message,
  }) {
    final InspectionResponse? response = inspection.responseByKey(
      sectionKey,
      itemKey,
    );
    final bool answered =
        response != null &&
        ((response.value ?? '').trim().isNotEmpty ||
            response.conditionRating != null);
    if (!answered) {
      issues.add(
        ValidationIssue(
          sectionKey: sectionKey,
          itemKey: itemKey,
          message: message,
        ),
      );
    }
  }
}
