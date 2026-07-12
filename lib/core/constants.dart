import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CTS Fluid Power Inspection App';
  static const String reportTitle = 'CTS Fluid Power Inspection Report';
  static const String placeholderLogoAsset = 'assets/logo/cts_logo.png';
  static const String samplePhotoAssetOne = 'assets/demo/sample_photo_1.jpg';
  static const String samplePhotoAssetTwo = 'assets/demo/sample_photo_2.jpg';
  static const int maxPhotosPerInspectionItem = 10;
  static const int recentInspectionLimit = 10;
  static const int recentRecipientLimit = 8;
  static const String databaseName = 'cts_fluid_power_inspections.db';
  static const String databaseFolderName = 'cts_fluid_power_inspection_app';
  static const String inspectionsFolderName = 'inspections';
  static const String exportsFolderName = 'exports';
  static const String importsFolderName = 'imports';
  static const String reportsFolderName = 'reports';
  static const String signatureFileName = 'signature.png';
  static const String customerSignatureFileName = 'customer_signature.png';
  static const String lotOWarning =
      'Critical / Out of Service condition identified. Lockout/Tagout required. '
      'Unit must not be operated until corrective action is complete.';

  static const List<String> samplePhotoAssets = <String>[
    samplePhotoAssetOne,
    samplePhotoAssetTwo,
  ];
}

class SectionDescriptor {
  const SectionDescriptor({
    required this.key,
    required this.title,
    required this.sortOrder,
  });

  final String key;
  final String title;
  final int sortOrder;
}

class InspectionSectionKeys {
  static const String jobAssetIdentification = 'job_asset_identification';
  static const String componentTracking = 'component_tracking';
  static const String fluidTankService = 'fluid_tank_service';
  static const String hoseConnectionInspection = 'hose_connection_inspection';
  static const String filtrationBreatherService = 'filtration_breather_service';
  static const String operationalDataSystemTest =
      'operational_data_system_test';
  static const String followUpRepairsQuoting = 'follow_up_repairs_quoting';
  static const String reviewCompletion = 'review_completion';

  static const List<SectionDescriptor> ordered = <SectionDescriptor>[
    SectionDescriptor(
      key: jobAssetIdentification,
      title: 'Job & Asset Identification',
      sortOrder: 0,
    ),
    SectionDescriptor(
      key: componentTracking,
      title: 'Component Tracking',
      sortOrder: 1,
    ),
    SectionDescriptor(
      key: fluidTankService,
      title: 'Fluid & Tank Service',
      sortOrder: 2,
    ),
    SectionDescriptor(
      key: hoseConnectionInspection,
      title: 'Hose & Connection Inspection',
      sortOrder: 3,
    ),
    SectionDescriptor(
      key: filtrationBreatherService,
      title: 'Filtration & Breather Service',
      sortOrder: 4,
    ),
    SectionDescriptor(
      key: operationalDataSystemTest,
      title: 'Operational Data / System Test',
      sortOrder: 5,
    ),
    SectionDescriptor(
      key: followUpRepairsQuoting,
      title: 'Follow-Up Repairs & Quoting',
      sortOrder: 6,
    ),
    SectionDescriptor(
      key: reviewCompletion,
      title: 'Review & Completion',
      sortOrder: 7,
    ),
  ];

  static String titleFor(String key) {
    return ordered
        .firstWhere(
          (descriptor) => descriptor.key == key,
          orElse: () => const SectionDescriptor(
            key: 'unknown',
            title: 'Unknown',
            sortOrder: 999,
          ),
        )
        .title;
  }
}

class InspectionItemKeys {
  static const String overviewPhotos = 'overview_photos';
  static const String fluidLevel = 'fluid_level';
  static const String fluidClarity = 'fluid_clarity';
  static const String tankIntegrity = 'tank_integrity';
  static const String tankCleanoutPerformed = 'tank_cleanout_performed';
  static const String overallHoseCondition = 'overall_hose_condition';
  static const String breatherPartNumber = 'breather_part_number';
  static const String breatherReplaced = 'breather_replaced';
  static const String pressureFilterPartNumber = 'pressure_filter_part_number';
  static const String pressureFilterReplaced = 'pressure_filter_replaced';
  static const String returnFilterPartNumber = 'return_filter_part_number';
  static const String returnFilterReplaced = 'return_filter_replaced';
  static const String equipmentRunning = 'equipment_running';
  static const String pumpCompensatorSetting = 'pump_compensator_setting';
  static const String changePumpCompensator = 'change_pump_compensator';
  static const String systemReliefSetting = 'system_relief_setting';
  static const String changeSystemRelief = 'change_system_relief';
  static const String operatingTemperature = 'operating_temperature';
  static const String operatingTemperatureUnit = 'operating_temperature_unit';
  static const String accumulatorPreCharge = 'accumulator_pre_charge';
  static const String chargeAccumulator = 'charge_accumulator';
  static const String operationalNotes = 'operational_notes';
  static const String additionalPartsRepairs = 'additional_parts_repairs';
  static const String finalTechComments = 'final_tech_comments';
  static const String technicianSignature = 'technician_signature';
  static const String criticalAcknowledgement = 'critical_acknowledgement';
}

class FixedOptions {
  static const List<String> fluidLevel = <String>[
    'High',
    'Within Tolerance',
    'Low',
  ];

  static const List<String> fluidClarity = <String>[
    'Clear',
    'Discolored',
    'Milky or Contaminated',
    'Other',
  ];

  static const List<String> yesNoNa = <String>['Yes', 'No', 'N/A'];

  static const List<String> failureTypes = <String>[
    'Weeping',
    'Cracking',
    'Abrasion',
    'Heat damage',
    'Collapse',
    'Leak',
    'Wrong hose type',
    'Other',
  ];

  static const List<String> temperatureUnits = <String>['°C', '°F'];
}

class AppColors {
  static const Color navy = Color(0xFF051125);
  static const Color navySoft = Color(0xFF1B263B);
  static const Color slate = Color(0xFF47607E);
  static const Color orange = Color(0xFFEA6400);
  static const Color canvas = Color(0xFFF8F9FA);
  static const Color mutedSurface = Color(0xFFEDEEEF);
  static const Color warning = Color(0xFFC17000);
  static const Color danger = Color(0xFFBA1A1A);
  static const Color success = Color(0xFF2E7D32);
}
