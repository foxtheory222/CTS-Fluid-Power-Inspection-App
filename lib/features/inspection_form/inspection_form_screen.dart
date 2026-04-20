import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/date_time_utils.dart';
import '../../core/file_utils.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/workspace_providers.dart';
import '../../data/models/inspection_enums.dart';
import '../../data/models/inspection_models.dart';
import '../../services/email_service.dart';
import '../../services/photo_service.dart';
import '../../widgets/condition_selector.dart';
import '../../widgets/required_field_label.dart';
import '../../widgets/section_card.dart';
import '../../widgets/signature_pad.dart';
import '../../widgets/status_badge.dart';

class InspectionFormScreen extends ConsumerStatefulWidget {
  const InspectionFormScreen({super.key, this.inspectionId});

  final String? inspectionId;

  @override
  ConsumerState<InspectionFormScreen> createState() =>
      _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  final Uuid _uuid = const Uuid();
  final ScrollController _scrollController = ScrollController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: CtsPalette.secondaryBlue,
    exportBackgroundColor: Colors.white,
  );
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{
    for (final SectionDescriptor descriptor in InspectionSectionKeys.ordered)
      descriptor.key: GlobalKey(),
  };

  late final TextEditingController _customerController;
  late final TextEditingController _hpuAssetController;
  late final TextEditingController _assetController;
  late final TextEditingController _workOrderController;
  late final TextEditingController _referenceController;
  late final TextEditingController _siteController;
  late final TextEditingController _technicianController;
  late final TextEditingController _shopController;
  late final TextEditingController _finalCommentsController;

  InspectionRecord? _inspection;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _existingSignaturePath;
  bool _signatureRemoved = false;

  @override
  void initState() {
    super.initState();
    _customerController = TextEditingController();
    _hpuAssetController = TextEditingController();
    _assetController = TextEditingController();
    _workOrderController = TextEditingController();
    _referenceController = TextEditingController();
    _siteController = TextEditingController();
    _technicianController = TextEditingController();
    _shopController = TextEditingController();
    _finalCommentsController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInspection());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _signatureController.dispose();
    _customerController.dispose();
    _hpuAssetController.dispose();
    _assetController.dispose();
    _workOrderController.dispose();
    _referenceController.dispose();
    _siteController.dispose();
    _technicianController.dispose();
    _shopController.dispose();
    _finalCommentsController.dispose();
    super.dispose();
  }

  Future<void> _loadInspection() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final controller = ref.read(workspaceProvider);
      final InspectionRecord? inspection = widget.inspectionId == null
          ? await controller.createInspection()
          : await controller.loadInspectionRecord(widget.inspectionId!);
      if (!mounted) {
        return;
      }
      if (inspection == null) {
        setState(() {
          _loadError = 'Inspection not found.';
          _loading = false;
        });
        return;
      }
      _inspection = inspection;
      _existingSignaturePath = inspection.signatureFilePath;
      _hydrateControllers(inspection);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  void _hydrateControllers(InspectionRecord inspection) {
    _customerController.text = inspection.customer;
    _hpuAssetController.text = inspection.hpuAssetIdName;
    _assetController.text = inspection.assetName;
    _workOrderController.text = inspection.workOrderNumber;
    _referenceController.text = inspection.customerReference;
    _siteController.text = inspection.siteLocation;
    _technicianController.text = inspection.technicianName;
    _shopController.text = inspection.servicingShop;
    _finalCommentsController.text = inspection.finalTechComments;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null || _inspection == null) {
      return Center(
        child: SectionCard(
          title: 'Unable to open inspection',
          subtitle: _loadError ?? 'Unknown error',
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to dashboard'),
          ),
        ),
      );
    }

    final InspectionRecord inspection = _inspection!;
    final List<ValidationIssue> issues = ref
        .watch(workspaceProvider)
        .validate(inspection)
        .issues;
    final bool wide = MediaQuery.sizeOf(context).width >= 1250;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderBanner(context, inspection),
        const SizedBox(height: 18),
        _buildJobAssetSection(context, inspection),
        const SizedBox(height: 18),
        _buildComponentSection(context, inspection),
        const SizedBox(height: 18),
        _buildFluidSection(context, inspection),
        const SizedBox(height: 18),
        _buildHoseSection(context, inspection),
        const SizedBox(height: 18),
        _buildFilterSection(context, inspection),
        const SizedBox(height: 18),
        _buildOperationalSection(context, inspection),
        const SizedBox(height: 18),
        _buildFollowUpSection(context, inspection),
        const SizedBox(height: 18),
        _buildReviewSection(context, inspection, issues),
        const SizedBox(height: 32),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide) ...[
          SizedBox(
            width: 250,
            child: _buildSectionNavigator(inspection, issues),
          ),
          const SizedBox(width: 18),
        ],
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: content,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBanner(BuildContext context, InspectionRecord inspection) {
    return SectionCard(
      title: widget.inspectionId == null ? 'New Inspection' : 'Edit Inspection',
      subtitle:
          'Document ${inspection.documentNumber} • ${DateTimeUtils.displayDateTime(inspection.inspectionDateTime)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatusBadge.forInspection(inspection.status),
              StatusBadge(
                label: inspection.documentNumber,
                color: CtsPalette.secondaryBlue,
                icon: Icons.confirmation_number_outlined,
              ),
              if (inspection.generatedPdfPath != null)
                const StatusBadge(
                  label: 'PDF generated',
                  color: CtsPalette.success,
                  icon: Icons.picture_as_pdf_outlined,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const Key('save_draft_button'),
                onPressed: _saving
                    ? null
                    : () => _persistInspection(showMessage: true),
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Draft'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _jumpToSection(InspectionSectionKeys.reviewCompletion),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Jump to Review'),
              ),
              if (widget.inspectionId != null)
                OutlinedButton.icon(
                  onPressed: () => context.go('/inspection/${inspection.id}'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Details'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionNavigator(
    InspectionRecord inspection,
    List<ValidationIssue> issues,
  ) {
    return SectionCard(
      title: 'Sections',
      subtitle: 'Tap to move through the fixed inspection workflow.',
      child: Column(
        children: [
          for (final SectionDescriptor descriptor
              in InspectionSectionKeys.ordered) ...[
            _SectionNavTile(
              title: descriptor.title,
              subtitle: _sectionSubtitle(descriptor.key, inspection, issues),
              onTap: () => _jumpToSection(descriptor.key),
            ),
            if (descriptor != InspectionSectionKeys.ordered.last)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildJobAssetSection(
    BuildContext context,
    InspectionRecord inspection,
  ) {
    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.jobAssetIdentification],
      title: 'Job & Asset Identification',
      subtitle: 'Required header details and the unit wide-shot photos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextGrid(<Widget>[
            _buildRequiredField(
              controller: _customerController,
              label: 'Customer',
              fieldKey: const Key('customer_field'),
            ),
            _buildTextField(
              controller: _hpuAssetController,
              label: 'HPU Asset ID / Name',
            ),
            _buildRequiredField(
              controller: _assetController,
              label: 'Asset / equipment name',
              fieldKey: const Key('asset_field'),
            ),
            _buildRequiredField(
              controller: _workOrderController,
              label: 'Work order number',
              fieldKey: const Key('work_order_field'),
            ),
            _buildRequiredField(
              controller: _referenceController,
              label: 'Customer reference / PO / job number',
              fieldKey: const Key('customer_reference_field'),
            ),
            _buildRequiredField(
              controller: _siteController,
              label: 'Location / site',
              fieldKey: const Key('site_field'),
            ),
            _buildRequiredField(
              controller: _technicianController,
              label: 'Technician name',
              fieldKey: const Key('technician_field'),
            ),
            _buildRequiredField(
              controller: _shopController,
              label: 'Servicing shop',
              fieldKey: const Key('servicing_shop_field'),
            ),
            _readOnlyField(
              label: 'Inspection date/time',
              value: DateTimeUtils.displayDateTime(
                inspection.inspectionDateTime,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildPhotoManager(
            sectionKey: InspectionSectionKeys.jobAssetIdentification,
            itemKey: InspectionItemKeys.overviewPhotos,
            label: 'Unit / as-found photos',
            addButtonPrefix: 'overview',
          ),
          const SizedBox(height: 16),
          _buildSectionActions(
            onNext: () =>
                _jumpToSection(InspectionSectionKeys.componentTracking),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentSection(
    BuildContext context,
    InspectionRecord inspection,
  ) {
    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.componentTracking],
      title: 'Component Tracking',
      subtitle:
          'Model, serial, notes, and nameplate photos for each component.',
      child: Column(
        children: [
          for (final ComponentEntry entry in inspection.componentEntries) ...[
            _buildComponentCard(entry),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addComponentEntry,
              icon: const Icon(Icons.add),
              label: const Text('Add Other Component'),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionActions(
            onNext: () =>
                _jumpToSection(InspectionSectionKeys.fluidTankService),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidSection(BuildContext context, InspectionRecord inspection) {
    final InspectionResponse fluidLevel = _response(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidLevel,
      itemLabel: 'Fluid Level',
      fieldType: InspectionFieldType.dropdown,
    );
    final InspectionResponse fluidClarity = _response(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidClarity,
      itemLabel: 'Fluid Clarity',
      fieldType: InspectionFieldType.dropdown,
    );
    final InspectionResponse tankIntegrity = _response(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankIntegrity,
      itemLabel: 'Tank Integrity',
      fieldType: InspectionFieldType.conditionRating,
    );
    final InspectionResponse cleanout = _response(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankCleanoutPerformed,
      itemLabel: 'Tank Cleanout Performed',
      fieldType: InspectionFieldType.yesNoNa,
    );

    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.fluidTankService],
      title: 'Fluid & Tank Service',
      subtitle:
          'Flagged items require a comment and at least one photo before completion.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('fluid_level_field'),
            initialValue: fluidLevel.value?.isEmpty ?? true
                ? null
                : fluidLevel.value,
            decoration: const InputDecoration(labelText: 'Fluid Level'),
            items: FixedOptions.fluidLevel
                .map(
                  (String option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              setState(() {
                fluidLevel.value = value;
                fluidLevel.conditionRating = value == 'Within Tolerance'
                    ? ConditionRating.satisfactory
                    : value == null
                    ? null
                    : fluidLevel.conditionRating ??
                          ConditionRating.monitorAtRisk;
                fluidLevel.isFlagged =
                    fluidLevel.conditionRating?.isFlagged ?? false;
              });
            },
          ),
          if (fluidLevel.conditionRating != null &&
              fluidLevel.conditionRating != ConditionRating.satisfactory) ...[
            const SizedBox(height: 10),
            KeyedSubtree(
              key: const Key('fluid_level_condition_selector'),
              child: ConditionSelector(
                value: fluidLevel.conditionRating,
                onChanged: (ConditionRating value) {
                  setState(() {
                    fluidLevel.conditionRating = value;
                    fluidLevel.isFlagged = value.isFlagged;
                  });
                },
              ),
            ),
            _buildFlaggedDetails(
              response: fluidLevel,
              addButtonPrefix: 'fluid_level',
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('fluid_clarity_field'),
            initialValue: fluidClarity.value?.isEmpty ?? true
                ? null
                : fluidClarity.value,
            decoration: const InputDecoration(labelText: 'Fluid Clarity'),
            items: FixedOptions.fluidClarity
                .map(
                  (String option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              setState(() {
                fluidClarity.value = value;
                if (value == 'Clear') {
                  fluidClarity.conditionRating = ConditionRating.satisfactory;
                } else if (value == 'Discolored') {
                  fluidClarity.conditionRating = ConditionRating.monitorAtRisk;
                } else if (value == 'Milky or Contaminated') {
                  fluidClarity.conditionRating = ConditionRating.unsatisfactory;
                } else if (value != null) {
                  fluidClarity.conditionRating =
                      fluidClarity.conditionRating ??
                      ConditionRating.monitorAtRisk;
                } else {
                  fluidClarity.conditionRating = null;
                }
                fluidClarity.isFlagged =
                    fluidClarity.conditionRating?.isFlagged ?? false;
              });
            },
          ),
          if (fluidClarity.conditionRating != null &&
              fluidClarity.conditionRating != ConditionRating.satisfactory)
            _buildFlaggedDetails(
              response: fluidClarity,
              addButtonPrefix: 'fluid_clarity',
            ),
          const SizedBox(height: 14),
          Text(
            'Tank Integrity',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: const Key('tank_integrity_condition_selector'),
            child: ConditionSelector(
              value: tankIntegrity.conditionRating,
              onChanged: (ConditionRating value) {
                setState(() {
                  tankIntegrity.conditionRating = value;
                  tankIntegrity.value = value.label;
                  tankIntegrity.isFlagged = value.isFlagged;
                });
              },
            ),
          ),
          _buildFlaggedDetails(
            response: tankIntegrity,
            addButtonPrefix: 'tank_integrity',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('tank_cleanout_performed_field'),
            initialValue: cleanout.value?.isEmpty ?? true
                ? null
                : cleanout.value,
            decoration: const InputDecoration(
              labelText: 'Tank Cleanout Performed',
            ),
            items: FixedOptions.yesNoNa
                .map(
                  (String option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              setState(() {
                cleanout.value = value;
                if (value == 'No') {
                  cleanout.isFlagged = true;
                  cleanout.conditionRating ??= ConditionRating.monitorAtRisk;
                } else {
                  cleanout.isFlagged = false;
                  cleanout.conditionRating = null;
                  cleanout.comment = null;
                }
              });
            },
          ),
          if (cleanout.value == 'No')
            _buildFlaggedDetails(
              response: cleanout,
              addButtonPrefix: 'tank_cleanout',
            ),
          const SizedBox(height: 16),
          _buildSectionActions(
            onNext: () =>
                _jumpToSection(InspectionSectionKeys.hoseConnectionInspection),
          ),
        ],
      ),
    );
  }

  Widget _buildHoseSection(BuildContext context, InspectionRecord inspection) {
    final InspectionResponse overallHoseCondition = _response(
      sectionKey: InspectionSectionKeys.hoseConnectionInspection,
      itemKey: InspectionItemKeys.overallHoseCondition,
      itemLabel: 'Overall Hose Condition',
      fieldType: InspectionFieldType.conditionRating,
    );

    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.hoseConnectionInspection],
      title: 'Hose & Connection Inspection',
      subtitle:
          'Identify the hose, failure type, and parts needed to build the replacement.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Hose Condition',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: const Key('overall_hose_condition_selector'),
            child: ConditionSelector(
              value: overallHoseCondition.conditionRating,
              onChanged: (ConditionRating value) {
                setState(() {
                  overallHoseCondition.conditionRating = value;
                  overallHoseCondition.value = value.label;
                  overallHoseCondition.isFlagged = value.isFlagged;
                });
              },
            ),
          ),
          _buildFlaggedDetails(
            response: overallHoseCondition,
            addButtonPrefix: 'overall_hose',
          ),
          const SizedBox(height: 16),
          for (final HoseEntry entry in inspection.hoseEntries) ...[
            _buildHoseEntryCard(entry),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('add_hose_entry_button'),
              onPressed: _addHoseEntry,
              icon: const Icon(Icons.add),
              label: const Text('Add Hose Entry'),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionActions(
            onNext: () =>
                _jumpToSection(InspectionSectionKeys.filtrationBreatherService),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    InspectionRecord inspection,
  ) {
    final InspectionResponse breatherPart = _response(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherPartNumber,
      itemLabel: 'Breather Part Number',
      fieldType: InspectionFieldType.text,
    );
    final InspectionResponse breatherReplaced = _response(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherReplaced,
      itemLabel: 'Breather Replaced',
      fieldType: InspectionFieldType.yesNoNa,
    );
    final InspectionResponse pressurePart = _response(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterPartNumber,
      itemLabel: 'Pressure Filter PN',
      fieldType: InspectionFieldType.text,
    );
    final InspectionResponse pressureReplaced = _response(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterReplaced,
      itemLabel: 'Pressure Filter Replaced',
      fieldType: InspectionFieldType.yesNoNa,
    );
    final InspectionResponse returnPart = _response(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterPartNumber,
      itemLabel: 'Return Filter PN',
      fieldType: InspectionFieldType.text,
    );
    final InspectionResponse returnReplaced = _response(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterReplaced,
      itemLabel: 'Return Filter Replaced',
      fieldType: InspectionFieldType.yesNoNa,
    );

    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.filtrationBreatherService],
      title: 'Filtration & Breather Service',
      subtitle: 'Record part numbers, replacement status, and filter photos.',
      child: Column(
        children: [
          _buildTextGrid(<Widget>[
            _buildResponseTextField(breatherPart, 'Breather Part Number'),
            _buildResponseTextField(pressurePart, 'Pressure Filter PN'),
            _buildResponseTextField(returnPart, 'Return Filter PN'),
          ]),
          const SizedBox(height: 14),
          _buildReplacementDropdown(breatherReplaced, 'Breather Replaced'),
          _buildFlaggedDetails(
            response: breatherReplaced,
            addButtonPrefix: 'breather',
          ),
          const SizedBox(height: 14),
          _buildReplacementDropdown(
            pressureReplaced,
            'Pressure Filter Replaced',
          ),
          _buildFlaggedDetails(
            response: pressureReplaced,
            addButtonPrefix: 'pressure_filter',
          ),
          const SizedBox(height: 14),
          _buildReplacementDropdown(returnReplaced, 'Return Filter Replaced'),
          _buildFlaggedDetails(
            response: returnReplaced,
            addButtonPrefix: 'return_filter',
          ),
          const SizedBox(height: 16),
          _buildSectionActions(
            onNext: () =>
                _jumpToSection(InspectionSectionKeys.operationalDataSystemTest),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalSection(
    BuildContext context,
    InspectionRecord inspection,
  ) {
    final InspectionResponse running = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.equipmentRunning,
      itemLabel: 'Equipment Running',
      fieldType: InspectionFieldType.yesNoNa,
    );
    final InspectionResponse pumpCompensator = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.pumpCompensatorSetting,
      itemLabel: 'Pump Compensator Setting Observed',
      fieldType: InspectionFieldType.number,
    );
    final InspectionResponse changePumpCompensator = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changePumpCompensator,
      itemLabel: 'Change Pump Compensator Setting',
      fieldType: InspectionFieldType.yesNoNa,
    );
    final InspectionResponse systemRelief = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.systemReliefSetting,
      itemLabel: 'System Relief Setting Observed',
      fieldType: InspectionFieldType.number,
    );
    final InspectionResponse changeSystemRelief = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changeSystemRelief,
      itemLabel: 'Change System Relief Setting',
      fieldType: InspectionFieldType.yesNoNa,
    );
    final InspectionResponse operatingTemperature = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperature,
      itemLabel: 'Operating Temperature',
      fieldType: InspectionFieldType.number,
    );
    final InspectionResponse operatingTemperatureUnit = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperatureUnit,
      itemLabel: 'Operating Temperature Unit',
      fieldType: InspectionFieldType.dropdown,
    );
    final InspectionResponse accumulatorPreCharge = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.accumulatorPreCharge,
      itemLabel: 'Accumulator Pre-charge',
      fieldType: InspectionFieldType.number,
    );
    final InspectionResponse chargeAccumulator = _response(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.chargeAccumulator,
      itemLabel: 'Charge Accumulator',
      fieldType: InspectionFieldType.yesNoNa,
    );

    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.operationalDataSystemTest],
      title: 'Operational Data / System Test',
      subtitle: 'Capture running state, settings, and temperature readings.',
      child: Column(
        children: [
          _buildYesNoNaDropdown(
            running,
            'Were you able to have the equipment running?',
          ),
          const SizedBox(height: 12),
          _buildTextGrid(<Widget>[
            _buildResponseTextField(
              pumpCompensator,
              'Pump Compensator Setting Observed (PSI or N/A)',
            ),
            _buildResponseTextField(
              systemRelief,
              'System Relief Setting Observed (PSI or N/A)',
            ),
            _buildResponseTextField(
              accumulatorPreCharge,
              'Accumulator Pre-charge (PSI or N/A)',
            ),
          ]),
          const SizedBox(height: 12),
          _buildYesNoNaDropdown(
            changePumpCompensator,
            'Do you need to change the pump compensator setting?',
          ),
          const SizedBox(height: 12),
          _buildYesNoNaDropdown(
            changeSystemRelief,
            'Do you need to change the system relief setting?',
          ),
          const SizedBox(height: 12),
          _buildTextGrid(<Widget>[
            _buildResponseTextField(
              operatingTemperature,
              'Operating Temperature',
            ),
            DropdownButtonFormField<String>(
              key: const Key('operating_temperature_unit_field'),
              initialValue: operatingTemperatureUnit.value?.isEmpty ?? true
                  ? null
                  : operatingTemperatureUnit.value,
              decoration: const InputDecoration(labelText: 'Temperature Unit'),
              items: FixedOptions.temperatureUnits
                  .map(
                    (String unit) => DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) =>
                  setState(() => operatingTemperatureUnit.value = value),
            ),
          ]),
          const SizedBox(height: 12),
          _buildYesNoNaDropdown(
            chargeAccumulator,
            'Does the accumulator need to be charged?',
          ),
          const SizedBox(height: 12),
          _buildPhotoManager(
            sectionKey: InspectionSectionKeys.operationalDataSystemTest,
            itemKey: 'operational_photos',
            label: 'Operational photos',
            addButtonPrefix: 'operational',
          ),
          const SizedBox(height: 16),
          _buildSectionActions(
            onNext: () =>
                _jumpToSection(InspectionSectionKeys.followUpRepairsQuoting),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpSection(
    BuildContext context,
    InspectionRecord inspection,
  ) {
    final InspectionResponse additionalParts = _response(
      sectionKey: InspectionSectionKeys.followUpRepairsQuoting,
      itemKey: InspectionItemKeys.additionalPartsRepairs,
      itemLabel: 'Additional Parts / Repairs',
      fieldType: InspectionFieldType.yesNoNa,
    );

    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.followUpRepairsQuoting],
      title: 'Follow-Up Repairs & Quoting',
      subtitle:
          'Track additional parts, repairs, and final technician comments.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('additional_parts_repairs_field'),
            initialValue: additionalParts.value?.isEmpty ?? true
                ? null
                : additionalParts.value,
            decoration: const InputDecoration(
              labelText: 'Are additional parts / repairs required?',
            ),
            items: const <String>['Yes', 'No']
                .map(
                  (String option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) =>
                setState(() => additionalParts.value = value),
          ),
          const SizedBox(height: 16),
          for (final RequiredItemEntry entry in inspection.requiredItems) ...[
            _buildRequiredItemCard(entry),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _addRequiredItem,
            icon: const Icon(Icons.add),
            label: const Text('Add Required Item'),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('final_comments_field'),
            controller: _finalCommentsController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Final tech comments'),
            onChanged: (_) =>
                _inspection!.finalTechComments = _finalCommentsController.text,
          ),
          const SizedBox(height: 16),
          _buildSectionActions(
            onNext: () =>
                _jumpToSection(InspectionSectionKeys.reviewCompletion),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(
    BuildContext context,
    InspectionRecord inspection,
    List<ValidationIssue> issues,
  ) {
    return SectionCard(
      key: _sectionKeys[InspectionSectionKeys.reviewCompletion],
      title: 'Review & Completion',
      subtitle:
          'Resolve validation issues, confirm LOTO when needed, and sign the inspection.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatusBadge(
                label: '${inspection.flaggedItemCount} flagged',
                color: inspection.flaggedItemCount == 0
                    ? CtsPalette.success
                    : CtsPalette.warning,
                icon: Icons.warning_amber_rounded,
              ),
              StatusBadge(
                label: '${inspection.actionItems.length} action items',
                color: CtsPalette.info,
                icon: Icons.assignment_turned_in_outlined,
              ),
              StatusBadge(
                label: '${inspection.photoCount} photos',
                color: CtsPalette.secondaryBlue,
                icon: Icons.photo_library_outlined,
              ),
              StatusBadge(
                label: issues.isEmpty
                    ? 'Ready to complete'
                    : '${issues.length} issues',
                color: issues.isEmpty ? CtsPalette.success : CtsPalette.danger,
                icon: issues.isEmpty
                    ? Icons.verified_outlined
                    : Icons.error_outline,
              ),
            ],
          ),
          if (inspection.hasCriticalItems) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CtsPalette.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: CtsPalette.danger.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                AppConstants.lotOWarning,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CtsPalette.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const Key('critical_acknowledgement_checkbox'),
              value: inspection.criticalAcknowledged,
              onChanged: (bool? value) => setState(
                () => inspection.criticalAcknowledged = value ?? false,
              ),
              title: const Text('LOTO acknowledgement recorded'),
              subtitle: const Text(
                'Critical / Out of Service condition identified. Lockout/Tagout required.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 16),
          if (issues.isNotEmpty) ...[
            Text(
              'Completion issues',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final ValidationIssue issue in issues) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CtsPalette.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(issue.message),
              ),
            ],
          ],
          const SizedBox(height: 8),
          if (_existingSignaturePath != null) ...[
            Text(
              'Saved signature',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Image.file(
                File(_existingSignaturePath!),
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SignaturePad(
            key: const Key('signature_pad'),
            controller: _signatureController,
            isSigned:
                _signatureController.isNotEmpty ||
                _existingSignaturePath != null,
            onClear: () {
              setState(() {
                _signatureController.clear();
                _existingSignaturePath = null;
                _signatureRemoved = true;
                inspection.signatureFilePath = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const Key('complete_inspection_button'),
                onPressed: _saving ? null : _completeInspection,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Complete Inspection'),
              ),
              OutlinedButton.icon(
                key: const Key('generate_pdf_button'),
                onPressed:
                    (inspection.status == InspectionStatus.complete ||
                        inspection.status == InspectionStatus.emailed)
                    ? _generatePdf
                    : null,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Generate PDF'),
              ),
              OutlinedButton.icon(
                key: const Key('share_pdf_button'),
                onPressed: inspection.generatedPdfPath != null
                    ? _sharePdf
                    : null,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share / Email PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComponentCard(ComponentEntry entry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.componentType,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!_isCoreComponent(entry.componentType))
                  IconButton(
                    onPressed: () => setState(
                      () => _inspection!.componentEntries.removeWhere(
                        (ComponentEntry item) => item.id == entry.id,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            _buildTextGrid(<Widget>[
              TextFormField(
                key: ValueKey('component_${entry.id}_model'),
                initialValue: entry.modelPartNumber,
                decoration: const InputDecoration(
                  labelText: 'Model / part number',
                ),
                onChanged: (String value) => entry.modelPartNumber = value,
              ),
              TextFormField(
                key: ValueKey('component_${entry.id}_serial'),
                initialValue: entry.serialNumber,
                decoration: const InputDecoration(labelText: 'Serial number'),
                onChanged: (String value) => entry.serialNumber = value,
              ),
            ]),
            const SizedBox(height: 12),
            ConditionSelector(
              value: entry.conditionRating,
              onChanged: (ConditionRating value) =>
                  setState(() => entry.conditionRating = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('component_${entry.id}_notes'),
              initialValue: entry.notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
              onChanged: (String value) => entry.notes = value,
            ),
            const SizedBox(height: 12),
            _buildPhotoManager(
              sectionKey: InspectionSectionKeys.componentTracking,
              itemKey: 'component:${entry.id}',
              label: '${entry.componentType} photos',
              addButtonPrefix: 'component_${entry.id}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoseEntryCard(HoseEntry entry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (entry.hoseNameLocation ?? '').trim().isEmpty
                        ? 'Hose entry'
                        : entry.hoseNameLocation!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _inspection!.hoseEntries.removeWhere(
                      (HoseEntry item) => item.id == entry.id,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            _buildTextGrid(<Widget>[
              TextFormField(
                key: ValueKey('hose_${entry.id}_name'),
                initialValue: entry.hoseNameLocation,
                decoration: const InputDecoration(
                  labelText: 'Hose name/location',
                ),
                onChanged: (String value) {
                  setState(() => entry.hoseNameLocation = value);
                },
              ),
              DropdownButtonFormField<FailureType>(
                key: ValueKey('hose_${entry.id}_failure'),
                initialValue: entry.failureType,
                decoration: const InputDecoration(labelText: 'Failure type'),
                items: FailureType.values
                    .map(
                      (FailureType value) => DropdownMenuItem<FailureType>(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (FailureType? value) =>
                    setState(() => entry.failureType = value),
              ),
              TextFormField(
                initialValue: entry.hoseSize,
                decoration: const InputDecoration(labelText: 'Hose size'),
                onChanged: (String value) => entry.hoseSize = value,
              ),
              TextFormField(
                initialValue: entry.hoseLength,
                decoration: const InputDecoration(labelText: 'Hose length'),
                onChanged: (String value) => entry.hoseLength = value,
              ),
              TextFormField(
                initialValue: entry.fittingEndA,
                decoration: const InputDecoration(labelText: 'Fitting / end A'),
                onChanged: (String value) => entry.fittingEndA = value,
              ),
              TextFormField(
                initialValue: entry.fittingEndB,
                decoration: const InputDecoration(labelText: 'Fitting / end B'),
                onChanged: (String value) => entry.fittingEndB = value,
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('hose_${entry.id}_replacement_parts'),
              initialValue: entry.replacementPartNumbers,
              decoration: const InputDecoration(
                labelText: 'Replacement parts needed',
              ),
              onChanged: (String value) => entry.replacementPartNumbers = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: entry.notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
              onChanged: (String value) => entry.notes = value,
            ),
            const SizedBox(height: 12),
            _buildPhotoManager(
              sectionKey: InspectionSectionKeys.hoseConnectionInspection,
              itemKey: 'hose:${entry.id}',
              label: 'Hose entry photos',
              addButtonPrefix: 'hose_${entry.id}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredItemCard(RequiredItemEntry entry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (entry.itemName ?? '').trim().isEmpty
                        ? 'Required item'
                        : entry.itemName!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _inspection!.requiredItems.removeWhere(
                      (RequiredItemEntry item) => item.id == entry.id,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            _buildTextGrid(<Widget>[
              TextFormField(
                initialValue: entry.itemName,
                decoration: const InputDecoration(labelText: 'Item / part'),
                onChanged: (String value) {
                  setState(() => entry.itemName = value);
                },
              ),
              TextFormField(
                initialValue: entry.partNumber,
                decoration: const InputDecoration(labelText: 'Part number'),
                onChanged: (String value) => entry.partNumber = value,
              ),
              TextFormField(
                initialValue: entry.quantity?.toString(),
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                onChanged: (String value) =>
                    entry.quantity = int.tryParse(value.trim()),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: entry.description,
              decoration: const InputDecoration(
                labelText: 'Description / notes',
              ),
              onChanged: (String value) => entry.description = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlaggedDetails({
    required InspectionResponse response,
    required String addButtonPrefix,
  }) {
    final bool flagged =
        response.isFlagged || (response.conditionRating?.isFlagged ?? false);
    if (!flagged) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          TextFormField(
            key: Key('${response.itemKey}_comment_field'),
            initialValue: response.comment,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '${response.itemLabel} comment',
            ),
            onChanged: (String value) {
              setState(() => response.comment = value);
            },
          ),
          const SizedBox(height: 12),
          _buildPhotoManager(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            label: '${response.itemLabel} photos',
            addButtonPrefix: addButtonPrefix,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoManager({
    required String sectionKey,
    required String itemKey,
    required String label,
    required String addButtonPrefix,
  }) {
    final List<InspectionPhoto> photos = _photosForItem(itemKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (photos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'No photos added yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: photos
                .map(
                  (InspectionPhoto photo) => SizedBox(
                    width: 260,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(photo.filePath),
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              initialValue: photo.caption,
                              decoration: const InputDecoration(
                                labelText: 'Caption',
                              ),
                              onChanged: (String value) =>
                                  photo.caption = value,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    DateTimeUtils.displayDateTime(
                                      photo.capturedAt,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deletePhoto(photo),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: Key('${addButtonPrefix}_camera_button'),
              onPressed: () => _capturePhoto(sectionKey, itemKey),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
            OutlinedButton.icon(
              key: Key('${addButtonPrefix}_gallery_button'),
              onPressed: () => _pickGalleryPhotos(sectionKey, itemKey),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionActions({required VoidCallback onNext}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () => _persistInspection(showMessage: true),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Draft'),
        ),
        FilledButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.arrow_downward_outlined),
          label: const Text('Next Section'),
        ),
      ],
    );
  }

  Widget _buildReplacementDropdown(InspectionResponse response, String label) {
    return DropdownButtonFormField<String>(
      key: Key('${response.itemKey}_field'),
      initialValue: response.value?.isEmpty ?? true ? null : response.value,
      decoration: InputDecoration(labelText: label),
      items: FixedOptions.yesNoNa
          .map(
            (String option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(growable: false),
      onChanged: (String? value) {
        setState(() {
          response.value = value;
          response.isFlagged = value == 'No';
          response.conditionRating = response.isFlagged
              ? ConditionRating.monitorAtRisk
              : null;
        });
      },
    );
  }

  Widget _buildYesNoNaDropdown(InspectionResponse response, String label) {
    return DropdownButtonFormField<String>(
      key: Key('${response.itemKey}_field'),
      initialValue: response.value?.isEmpty ?? true ? null : response.value,
      decoration: InputDecoration(labelText: label),
      items: FixedOptions.yesNoNa
          .map(
            (String option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(growable: false),
      onChanged: (String? value) => setState(() => response.value = value),
    );
  }

  Widget _buildResponseTextField(InspectionResponse response, String label) {
    return TextFormField(
      key: Key('${response.itemKey}_field'),
      initialValue: response.value,
      decoration: InputDecoration(labelText: label),
      onChanged: (String value) => response.value = value,
    );
  }

  Widget _buildRequiredField({
    required TextEditingController controller,
    required String label,
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RequiredFieldLabel(label: label),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _readOnlyField({required String label, required String value}) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildTextGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        return GridView.builder(
          itemCount: children.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 108,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, int index) => children[index],
        );
      },
    );
  }

  InspectionResponse _response({
    required String sectionKey,
    required String itemKey,
    required String itemLabel,
    required InspectionFieldType fieldType,
  }) {
    final InspectionResponse? existing = _inspection!.responseByKey(
      sectionKey,
      itemKey,
    );
    if (existing != null) {
      return existing;
    }
    final DateTime now = DateTime.now();
    final InspectionResponse response = InspectionResponse(
      id: _uuid.v4(),
      inspectionId: _inspection!.id,
      sectionKey: sectionKey,
      itemKey: itemKey,
      itemLabel: itemLabel,
      fieldType: fieldType,
      createdAt: now,
      updatedAt: now,
    );
    _inspection!.responses.add(response);
    return response;
  }

  List<InspectionPhoto> _photosForItem(String itemKey) {
    return _inspection!.photos
        .where((InspectionPhoto photo) => photo.itemKey == itemKey)
        .toList(growable: false)
      ..sort(
        (InspectionPhoto a, InspectionPhoto b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );
  }

  Future<void> _capturePhoto(String sectionKey, String itemKey) async {
    try {
      final int currentCount = _photosForItem(itemKey).length;
      final ManagedInspectionPhoto? photo = await ref
          .read(workspaceProvider)
          .photoService
          .captureFromCamera(
            inspectionId: _inspection!.id,
            sectionKey: sectionKey,
            itemKey: itemKey,
            currentPhotoCount: currentCount,
            sortOrder: currentCount,
          );
      if (photo == null || !mounted) {
        return;
      }
      setState(() {
        _inspection!.photos.add(_inspectionPhotoFromManaged(photo));
      });
    } on PhotoServiceException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _pickGalleryPhotos(String sectionKey, String itemKey) async {
    try {
      final int currentCount = _photosForItem(itemKey).length;
      final PhotoBatchResult batch = await ref
          .read(workspaceProvider)
          .photoService
          .addFromGallery(
            inspectionId: _inspection!.id,
            sectionKey: sectionKey,
            itemKey: itemKey,
            currentPhotoCount: currentCount,
            startingSortOrder: currentCount,
          );
      if (!mounted || batch.savedPhotos.isEmpty) {
        return;
      }
      setState(() {
        _inspection!.photos.addAll(
          batch.savedPhotos.map(_inspectionPhotoFromManaged).toList(),
        );
      });
    } on PhotoServiceException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _deletePhoto(InspectionPhoto photo) async {
    await ref.read(workspaceProvider).photoService.deletePhoto(photo);
    setState(() {
      _inspection!.photos.removeWhere(
        (InspectionPhoto item) => item.id == photo.id,
      );
    });
  }

  InspectionPhoto _inspectionPhotoFromManaged(ManagedInspectionPhoto photo) {
    return InspectionPhoto(
      id: _uuid.v4(),
      inspectionId: _inspection!.id,
      sectionKey: photo.sectionKey,
      itemKey: photo.itemKey,
      filePath: photo.filePath,
      caption: photo.caption,
      sortOrder: photo.sortOrder,
      capturedAt: photo.capturedAt.toLocal(),
      createdAt: DateTime.now(),
    );
  }

  void _addComponentEntry() {
    setState(() {
      _inspection!.componentEntries.add(
        ComponentEntry(
          id: _uuid.v4(),
          inspectionId: _inspection!.id,
          componentType: 'Other Component',
        ),
      );
    });
  }

  void _addHoseEntry() {
    setState(() {
      _inspection!.hoseEntries.add(
        HoseEntry(id: _uuid.v4(), inspectionId: _inspection!.id),
      );
    });
  }

  void _addRequiredItem() {
    setState(() {
      _inspection!.requiredItems.add(
        RequiredItemEntry(id: _uuid.v4(), inspectionId: _inspection!.id),
      );
    });
  }

  bool _isCoreComponent(String componentType) {
    return componentType == 'Main Pump' ||
        componentType == 'Main Motor' ||
        componentType == 'Cooler' ||
        componentType == 'Accumulator';
  }

  Future<void> _persistInspection({required bool showMessage}) async {
    if (_inspection == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      _syncHeaderFields();
      await _persistSignatureIfNeeded();
      final bool hadEmailed = _inspection!.emailedAt != null;
      final InspectionRecord saved = await ref
          .read(workspaceProvider)
          .saveInspection(_inspection!);
      if (!mounted) {
        return;
      }
      setState(() {
        _inspection = saved;
        _existingSignaturePath = saved.signatureFilePath;
        _signatureRemoved = false;
      });
      if (showMessage) {
        if (hadEmailed && saved.emailedAt == null) {
          _showMessage(
            'This report was changed after emailing. Email status has been cleared until the updated report is sent again.',
          );
        } else {
          _showMessage('Draft saved.');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _completeInspection() async {
    await _persistInspection(showMessage: false);
    if (!mounted || _inspection == null) {
      return;
    }
    final ValidationResult result = ref
        .read(workspaceProvider)
        .validate(_inspection!);
    if (result.isValid && _inspection!.status == InspectionStatus.complete) {
      _showMessage('Inspection completed.');
      setState(() {});
      return;
    }
    _showMessage('Resolve the remaining review issues before completion.');
    _jumpToSection(InspectionSectionKeys.reviewCompletion);
  }

  Future<void> _generatePdf() async {
    if (_inspection == null) {
      return;
    }
    await _persistInspection(showMessage: false);
    if (_inspection == null) {
      return;
    }
    final ValidationResult result = ref
        .read(workspaceProvider)
        .validate(_inspection!);
    if (!result.isValid || _inspection!.status == InspectionStatus.draft) {
      _showMessage('Complete the inspection before generating the PDF.');
      return;
    }
    setState(() => _saving = true);
    try {
      final File file = await ref
          .read(workspaceProvider)
          .generatePdf(_inspection!);
      final InspectionRecord? refreshed = await ref
          .read(workspaceProvider)
          .loadInspectionRecord(_inspection!.id);
      if (!mounted) {
        return;
      }
      setState(() => _inspection = refreshed ?? _inspection);
      _showMessage('PDF generated: ${p.basename(file.path)}');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_inspection == null || _inspection!.generatedPdfPath == null) {
      _showMessage('Generate the PDF before sharing.');
      return;
    }
    try {
      await ref.read(workspaceProvider).sharePdf(_inspection!);
      if (!mounted) {
        return;
      }
      final bool? markEmailed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Mark as emailed?'),
            content: const Text('Mark this inspection as emailed?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Mark emailed'),
              ),
            ],
          );
        },
      );
      if (markEmailed == true) {
        final InspectionRecord updated = await ref
            .read(workspaceProvider)
            .markEmailed(_inspection!);
        setState(() => _inspection = updated);
        _showMessage('Inspection marked as emailed.');
      } else {
        _showMessage('PDF ready to share.');
      }
    } on EmailServiceException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _persistSignatureIfNeeded() async {
    if (_inspection == null) {
      return;
    }
    if (_signatureRemoved &&
        (_inspection!.signatureFilePath ?? '').isNotEmpty) {
      final File existingFile = File(_inspection!.signatureFilePath!);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }
      _inspection!.signatureFilePath = null;
    }
    if (_signatureController.isEmpty) {
      return;
    }
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null) {
      return;
    }
    final Directory inspectionDirectory = await FileUtils.inspectionDirectory(
      _inspection!.id,
    );
    final File signatureFile = File(
      p.join(inspectionDirectory.path, AppConstants.signatureFileName),
    );
    await signatureFile.writeAsBytes(bytes, flush: true);
    _inspection!.signatureFilePath = signatureFile.path;
    _existingSignaturePath = signatureFile.path;
  }

  void _syncHeaderFields() {
    if (_inspection == null) {
      return;
    }
    _inspection!
      ..customer = _customerController.text.trim()
      ..hpuAssetIdName = _hpuAssetController.text.trim()
      ..assetName = _assetController.text.trim()
      ..workOrderNumber = _workOrderController.text.trim()
      ..customerReference = _referenceController.text.trim()
      ..siteLocation = _siteController.text.trim()
      ..technicianName = _technicianController.text.trim()
      ..servicingShop = _shopController.text.trim()
      ..finalTechComments = _finalCommentsController.text.trim();
  }

  void _jumpToSection(String sectionKey) {
    final BuildContext? target = _sectionKeys[sectionKey]?.currentContext;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.04,
    );
  }

  String _sectionSubtitle(
    String sectionKey,
    InspectionRecord inspection,
    List<ValidationIssue> issues,
  ) {
    final int issueCount = issues.where((ValidationIssue issue) {
      return issue.sectionKey == sectionKey;
    }).length;
    if (issueCount > 0) {
      return '$issueCount issue${issueCount == 1 ? '' : 's'} to resolve';
    }
    final int photoCount = inspection.photos
        .where((InspectionPhoto photo) => photo.sectionKey == sectionKey)
        .length;
    if (photoCount > 0) {
      return '$photoCount photo${photoCount == 1 ? '' : 's'} attached';
    }
    return 'Ready';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionNavTile extends StatelessWidget {
  const _SectionNavTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
