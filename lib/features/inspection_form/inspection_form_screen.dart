import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/workspace_models.dart';
import '../../core/workspace_providers.dart';
import '../../data/models/inspection_enums.dart';
import '../../data/models/inspection_models.dart';
import '../../services/photo_service.dart';
import '../../widgets/condition_selector.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/required_field_label.dart';
import '../../widgets/section_card.dart';
import '../../widgets/signature_pad.dart';

class InspectionFormScreen extends ConsumerStatefulWidget {
  const InspectionFormScreen({super.key, this.seed, this.inspectionId});

  final InspectionSummary? seed;
  final String? inspectionId;

  @override
  ConsumerState<InspectionFormScreen> createState() =>
      _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  String? _inspectionId;
  late final ScrollController _scrollController;
  late final SignatureController _signatureController;
  late final SignatureController _customerSignatureController;
  late final Map<String, GlobalKey> _keys;
  late final TextEditingController _customer;
  late final TextEditingController _asset;
  late final TextEditingController _workOrder;
  late final TextEditingController _customerReference;
  late final TextEditingController _siteLocation;
  late final TextEditingController _tech;
  late final TextEditingController _shop;
  late final TextEditingController _finalComments;
  late final TextEditingController _repairNotes;
  late final TextEditingController _hoseName;
  late final TextEditingController _hoseParts;
  late final Map<String, TextEditingController> _componentPartNumbers;
  late final TextEditingController _breatherPartNumber;
  late final TextEditingController _pressureFilterPartNumber;
  late final TextEditingController _returnFilterPartNumber;
  late final TextEditingController _pumpCompensatorSetting;
  late final TextEditingController _systemReliefSetting;
  late final TextEditingController _operatingTemperature;
  late final TextEditingController _accumulatorPreCharge;
  late final TextEditingController _operationalNotes;

  final List<InspectionPhotoView> _photos = [];

  final List<_SectionState> _sections = [
    _SectionState(
      InspectionSectionKeys.jobAssetIdentification,
      'Job & Asset Identification',
      SectionCompletionState.notStarted,
    ),
    _SectionState(
      InspectionSectionKeys.componentTracking,
      'Component Tracking',
      SectionCompletionState.notStarted,
    ),
    _SectionState(
      InspectionSectionKeys.fluidTankService,
      'Fluid & Tank Service',
      SectionCompletionState.notStarted,
    ),
    _SectionState(
      InspectionSectionKeys.hoseConnectionInspection,
      'Hose & Connection Inspection',
      SectionCompletionState.notStarted,
    ),
    _SectionState(
      InspectionSectionKeys.filtrationBreatherService,
      'Filtration & Breather Service',
      SectionCompletionState.notStarted,
    ),
    _SectionState(
      InspectionSectionKeys.operationalDataSystemTest,
      'Operational Data / System Test',
      SectionCompletionState.notStarted,
    ),
    _SectionState(
      InspectionSectionKeys.followUpRepairsQuoting,
      'Follow-Up Repairs & Quoting',
      SectionCompletionState.notStarted,
    ),
    _SectionState(
      InspectionSectionKeys.reviewCompletion,
      'Review & Completion',
      SectionCompletionState.notStarted,
    ),
  ];

  bool _criticalAcknowledged = false;
  bool _signed = false;
  bool _customerSigned = false;
  bool _isHydrating = false;
  bool _isSaving = false;
  String? _loadError;
  FluidLevelOption? _fluidLevel;
  FluidClarityOption? _fluidClarity;
  ConditionRating? _tankIntegrity;
  YesNoNa? _tankCleanoutPerformed;
  ConditionRating? _hoseCondition;
  FilterReplacementStatus? _breatherReplaced;
  FilterReplacementStatus? _pressureFilterReplaced;
  FilterReplacementStatus? _returnFilterReplaced;
  YesNoNa? _running;
  YesNoNa? _changePumpCompensator;
  YesNoNa? _changeSystemRelief;
  TemperatureUnit? _operatingTemperatureUnit;
  YesNoNa? _chargeAccumulator;
  YesNoNa? _additionalRepairs;

  @override
  void initState() {
    super.initState();
    _inspectionId = widget.seed?.id ?? widget.inspectionId;
    _scrollController = ScrollController();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: CtsPalette.orange,
      exportBackgroundColor: Colors.white,
    );
    _customerSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: CtsPalette.orange,
      exportBackgroundColor: Colors.white,
    );
    _signatureController.addListener(_handleSignatureChanged);
    _customerSignatureController.addListener(_handleCustomerSignatureChanged);
    _keys = {for (final section in _sections) section.key: GlobalKey()};
    final seed = widget.seed;
    _customer = TextEditingController(text: seed?.customer ?? '');
    _asset = TextEditingController(text: seed?.assetName ?? '');
    _workOrder = TextEditingController(text: seed?.workOrderNumber ?? '');
    _customerReference = TextEditingController(
      text: seed?.customerReference ?? '',
    );
    _siteLocation = TextEditingController(text: seed?.siteLocation ?? '');
    _tech = TextEditingController(text: seed?.technicianName ?? '');
    _shop = TextEditingController(text: seed?.servicingShop ?? '');
    _finalComments = TextEditingController(text: seed?.finalTechComments ?? '');
    _repairNotes = TextEditingController();
    _hoseName = TextEditingController();
    _hoseParts = TextEditingController();
    _componentPartNumbers = <String, TextEditingController>{
      for (final componentType in const <String>[
        'Main Pump',
        'Main Motor',
        'Cooler',
        'Accumulator',
      ])
        componentType: TextEditingController(),
    };
    _breatherPartNumber = TextEditingController();
    _pressureFilterPartNumber = TextEditingController();
    _returnFilterPartNumber = TextEditingController();
    _pumpCompensatorSetting = TextEditingController();
    _systemReliefSetting = TextEditingController();
    _operatingTemperature = TextEditingController();
    _accumulatorPreCharge = TextEditingController();
    _operationalNotes = TextEditingController();
    for (final controller in _allTextControllers) {
      controller.addListener(_handleFormChanged);
    }
    final inspectionId = _inspectionId;
    if (inspectionId != null) {
      _isHydrating = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _hydrateInspection(inspectionId),
      );
    }
  }

  Future<void> _hydrateInspection(String inspectionId) async {
    try {
      final record = await ref
          .read(workspaceProvider)
          .inspectionRecordById(inspectionId);
      if (!mounted) {
        return;
      }
      setState(() {
        if (record != null) {
          _applyRecord(record);
          _loadError = null;
        } else {
          _loadError = 'This inspection could not be found.';
        }
        _isHydrating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isHydrating = false;
        _loadError = 'Unable to load this inspection: $error';
      });
    }
  }

  void _applyRecord(InspectionRecord record) {
    _customer.text = record.customer;
    _asset.text = record.assetName;
    _workOrder.text = record.workOrderNumber;
    _customerReference.text = record.customerReference;
    _siteLocation.text = record.siteLocation;
    _tech.text = record.technicianName;
    _shop.text = record.servicingShop;
    _finalComments.text = record.finalTechComments;
    for (final entry in _componentPartNumbers.entries) {
      entry.value.text =
          record.componentEntries
              .where((component) => component.componentType == entry.key)
              .map((component) => component.modelPartNumber ?? '')
              .firstOrNull ??
          '';
    }
    _criticalAcknowledged = record.criticalAcknowledged;
    _signed = (record.signatureFilePath ?? '').trim().isNotEmpty;
    _customerSigned = (record.customerSignatureFilePath ?? '')
        .trim()
        .isNotEmpty;

    _fluidLevel = _enumFromResponse(
      record,
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.fluidLevel,
      FluidLevelOptionX.fromValue,
    );
    _fluidClarity = _enumFromResponse(
      record,
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.fluidClarity,
      FluidClarityOptionX.fromValue,
    );
    final tankIntegrity = record.responseByKey(
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.tankIntegrity,
    );
    _tankIntegrity = tankIntegrity?.conditionRating;
    _repairNotes.text = tankIntegrity?.comment ?? '';
    _tankCleanoutPerformed = _enumFromResponse(
      record,
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.tankCleanoutPerformed,
      YesNoNaX.fromValue,
    );

    final hoseCondition = record.responseByKey(
      InspectionSectionKeys.hoseConnectionInspection,
      InspectionItemKeys.overallHoseCondition,
    );
    _hoseCondition = hoseCondition?.conditionRating;
    final hoseDetails = (hoseCondition?.comment ?? '').split(' | ');
    _hoseName.text = hoseDetails.isEmpty ? '' : hoseDetails.first;
    _hoseParts.text = hoseDetails.length < 2 ? '' : hoseDetails[1];

    _breatherPartNumber.text = _responseValue(
      record,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.breatherPartNumber,
    );
    _breatherReplaced = _enumFromResponse(
      record,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.breatherReplaced,
      FilterReplacementStatusX.fromValue,
    );
    _pressureFilterPartNumber.text = _responseValue(
      record,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.pressureFilterPartNumber,
    );
    _pressureFilterReplaced = _enumFromResponse(
      record,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.pressureFilterReplaced,
      FilterReplacementStatusX.fromValue,
    );
    _returnFilterPartNumber.text = _responseValue(
      record,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.returnFilterPartNumber,
    );
    _returnFilterReplaced = _enumFromResponse(
      record,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.returnFilterReplaced,
      FilterReplacementStatusX.fromValue,
    );

    _running = _enumFromResponse(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.equipmentRunning,
      YesNoNaX.fromValue,
    );
    _pumpCompensatorSetting.text = _responseValue(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.pumpCompensatorSetting,
    );
    _changePumpCompensator = _enumFromResponse(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.changePumpCompensator,
      YesNoNaX.fromValue,
    );
    _systemReliefSetting.text = _responseValue(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.systemReliefSetting,
    );
    _changeSystemRelief = _enumFromResponse(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.changeSystemRelief,
      YesNoNaX.fromValue,
    );
    _operatingTemperature.text = _responseValue(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.operatingTemperature,
    );
    _operatingTemperatureUnit = _temperatureUnitFromResponse(record);
    _accumulatorPreCharge.text = _responseValue(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.accumulatorPreCharge,
    );
    _chargeAccumulator = _enumFromResponse(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.chargeAccumulator,
      YesNoNaX.fromValue,
    );
    _operationalNotes.text = _responseValue(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.operationalNotes,
    );
    _additionalRepairs = _enumFromResponse(
      record,
      InspectionSectionKeys.followUpRepairsQuoting,
      InspectionItemKeys.additionalPartsRepairs,
      YesNoNaX.fromValue,
    );
    _photos
      ..clear()
      ..addAll(record.photos.map(_photoViewFromRecord));
  }

  String _responseValue(
    InspectionRecord record,
    String sectionKey,
    String itemKey,
  ) {
    return record.responseByKey(sectionKey, itemKey)?.value ?? '';
  }

  T? _enumFromResponse<T>(
    InspectionRecord record,
    String sectionKey,
    String itemKey,
    T Function(String value) fromValue,
  ) {
    final value = _responseValue(record, sectionKey, itemKey).trim();
    return value.isEmpty ? null : fromValue(value);
  }

  TemperatureUnit? _temperatureUnitFromResponse(InspectionRecord record) {
    final value = _responseValue(
      record,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.operatingTemperatureUnit,
    ).trim();
    if (value.isEmpty) {
      return null;
    }
    if (value == TemperatureUnit.celsius.symbol) {
      return TemperatureUnit.celsius;
    }
    if (value == TemperatureUnit.fahrenheit.symbol) {
      return TemperatureUnit.fahrenheit;
    }
    return TemperatureUnitX.fromValue(value);
  }

  InspectionPhotoView _photoViewFromRecord(InspectionPhoto photo) {
    return InspectionPhotoView(
      assetPath: photo.filePath,
      caption: photo.caption ?? 'Inspection photo',
      sectionTitle: InspectionSectionKeys.titleFor(photo.sectionKey),
      itemLabel: photo.itemKey,
      capturedAt: photo.capturedAt,
    );
  }

  Iterable<TextEditingController> get _allTextControllers sync* {
    yield _customer;
    yield _asset;
    yield _workOrder;
    yield _customerReference;
    yield _siteLocation;
    yield _tech;
    yield _shop;
    yield _finalComments;
    yield _repairNotes;
    yield _hoseName;
    yield _hoseParts;
    yield* _componentPartNumbers.values;
    yield _breatherPartNumber;
    yield _pressureFilterPartNumber;
    yield _returnFilterPartNumber;
    yield _pumpCompensatorSetting;
    yield _systemReliefSetting;
    yield _operatingTemperature;
    yield _accumulatorPreCharge;
    yield _operationalNotes;
  }

  void _handleFormChanged() {
    if (mounted && !_isHydrating) {
      setState(() {});
    }
  }

  void _handleSignatureChanged() {
    if (mounted && _signed != _signatureController.isNotEmpty) {
      setState(() => _signed = _signatureController.isNotEmpty);
    }
  }

  void _handleCustomerSignatureChanged() {
    if (mounted && _customerSigned != _customerSignatureController.isNotEmpty) {
      setState(() => _customerSigned = _customerSignatureController.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _signatureController.dispose();
    _customerSignatureController.dispose();
    for (final controller in _allTextControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Center(
        child: SectionCard(
          title: 'Inspection unavailable',
          subtitle: _loadError,
          child: FilledButton.icon(
            onPressed: () => context.go('/inspections'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to inspections'),
          ),
        ),
      );
    }
    final issues = _buildIssues();
    final sectionStates = _currentSectionStates();
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final showRail =
            constraints.maxWidth >= 1120 &&
            constraints.maxHeight >= 620 &&
            textScale <= 1.25;
        final showSummary = constraints.maxWidth >= 1350 && textScale <= 1.25;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showRail) ...[
              SizedBox(
                width: 250,
                child: _SectionRail(sections: sectionStates, onJump: _jumpTo),
              ),
              const SizedBox(width: 18),
            ],
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Banner(
                      isEdit: _inspectionId != null,
                      isHydrating: _isHydrating,
                      isSaving: _isSaving,
                      onSave: _isHydrating || _isSaving ? null : _saveDraft,
                      onComplete: _isHydrating || _isSaving
                          ? null
                          : _completeInspection,
                    ),
                    const SizedBox(height: 18),
                    _headerSection(),
                    const SizedBox(height: 18),
                    _componentSection(),
                    const SizedBox(height: 18),
                    _fluidSection(),
                    const SizedBox(height: 18),
                    _hoseSection(),
                    const SizedBox(height: 18),
                    _filterSection(),
                    const SizedBox(height: 18),
                    _operationalSection(),
                    const SizedBox(height: 18),
                    _followUpSection(),
                    const SizedBox(height: 18),
                    _reviewSection(issues),
                  ],
                ),
              ),
            ),
            if (showSummary) ...[
              const SizedBox(width: 18),
              SizedBox(
                width: 360,
                child: _SummaryPanel(
                  issues: issues,
                  photos: _photos,
                  onJump: _jumpTo,
                  sectionForIssue: _sectionKeyForIssue,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _headerSection() => SectionCard(
    key: _keys[InspectionSectionKeys.jobAssetIdentification],
    title: 'Job & Asset Identification',
    subtitle: 'Header details, inspection date/time, and the as-found image.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RequiredFieldLabel(label: 'Customer / Site Name'),
        const SizedBox(height: 12),
        _fieldGrid([
          _TextFieldSpec(
            _customer,
            'Customer / Site Name',
            key: 'field-customer',
          ),
          _TextFieldSpec(_asset, 'HPU Asset ID / Name', key: 'field-asset'),
          _TextFieldSpec(
            _workOrder,
            'Work order number',
            key: 'field-work-order',
          ),
          _TextFieldSpec(
            _customerReference,
            'Customer reference / PO',
            key: 'field-customer-reference',
          ),
          _TextFieldSpec(
            _siteLocation,
            'Location / site',
            key: 'field-site-location',
          ),
          _TextFieldSpec(_tech, 'Technician name', key: 'field-technician'),
          _TextFieldSpec(_shop, 'Servicing shop', key: 'field-shop'),
        ]),
        const SizedBox(height: 14),
        PhotoGrid(
          photos: _photosFor(
            sectionKey: InspectionSectionKeys.jobAssetIdentification,
            itemKey: InspectionItemKeys.overviewPhotos,
          ),
          addButtonKey: const Key('overview-add-photo-button'),
          onAddPhoto: _isSaving
              ? null
              : () => _addDraftPhoto(
                  sectionKey: InspectionSectionKeys.jobAssetIdentification,
                  itemKey: InspectionItemKeys.overviewPhotos,
                  itemLabel: 'Overview photos',
                ),
          onRemovePhoto: _isSaving ? null : _removeDraftPhoto,
        ),
      ],
    ),
  );

  Widget _componentSection() => SectionCard(
    key: _keys[InspectionSectionKeys.componentTracking],
    title: 'Component Tracking',
    subtitle: 'Structured component cards with model and tag details.',
    child: Column(
      children: [
        _componentCard('Main Pump', Icons.settings_outlined),
        const SizedBox(height: 12),
        _componentCard('Main Motor', Icons.electrical_services_outlined),
        const SizedBox(height: 12),
        _componentCard('Cooler', Icons.ac_unit_outlined),
        const SizedBox(height: 12),
        _componentCard('Accumulator', Icons.circle_outlined),
      ],
    ),
  );

  Widget _fluidSection() => SectionCard(
    key: _keys[InspectionSectionKeys.fluidTankService],
    title: 'Fluid & Tank Service',
    subtitle: 'Flagged items require comments, photos, and action items.',
    trailing: const StatusChip(text: 'LOTO aware', color: CtsPalette.danger),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _controlGrid([
          _dropdownField<FluidLevelOption>(
            label: 'Fluid Level',
            value: _fluidLevel,
            values: FluidLevelOption.values,
            labelFor: (value) => value.label,
            onChanged: (value) => setState(() => _fluidLevel = value),
          ),
          _dropdownField<FluidClarityOption>(
            label: 'Fluid Clarity',
            value: _fluidClarity,
            values: FluidClarityOption.values,
            labelFor: (value) => value.label,
            onChanged: (value) => setState(() => _fluidClarity = value),
          ),
          _dropdownField<YesNoNa>(
            label: 'Tank Cleanout Performed',
            value: _tankCleanoutPerformed,
            values: YesNoNa.values,
            labelFor: (value) => value.label,
            onChanged: (value) =>
                setState(() => _tankCleanoutPerformed = value),
          ),
        ]),
        const SizedBox(height: 14),
        _label('Tank integrity'),
        const SizedBox(height: 8),
        ConditionSelector(
          value: _tankIntegrity,
          onChanged: (value) => setState(() => _tankIntegrity = value),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _repairNotes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Tank notes / flagged reason',
          ),
        ),
        const SizedBox(height: 14),
        PhotoGrid(
          photos: _photosFor(
            sectionKey: InspectionSectionKeys.fluidTankService,
            itemKey: InspectionItemKeys.tankIntegrity,
          ),
          addButtonKey: const Key('fluid-add-photo-button'),
          onAddPhoto: _isSaving
              ? null
              : () => _addDraftPhoto(
                  sectionKey: InspectionSectionKeys.fluidTankService,
                  itemKey: InspectionItemKeys.tankIntegrity,
                  itemLabel: 'Tank Integrity',
                ),
          onRemovePhoto: _isSaving ? null : _removeDraftPhoto,
        ),
      ],
    ),
  );

  Widget _hoseSection() => SectionCard(
    key: _keys[InspectionSectionKeys.hoseConnectionInspection],
    title: 'Hose & Connection Inspection',
    subtitle:
        'Identify the hose, failure type, and parts needed to build the replacement.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConditionSelector(
          value: _hoseCondition,
          onChanged: (value) => setState(() => _hoseCondition = value),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _hoseName,
          decoration: const InputDecoration(labelText: 'Hose name/location'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hoseParts,
          decoration: const InputDecoration(
            labelText: 'Replacement part numbers',
          ),
        ),
        const SizedBox(height: 14),
        PhotoGrid(
          photos: _photosFor(
            sectionKey: InspectionSectionKeys.hoseConnectionInspection,
            itemKey: InspectionItemKeys.overallHoseCondition,
          ),
          addButtonKey: const Key('hose-add-photo-button'),
          onAddPhoto: _isSaving
              ? null
              : () => _addDraftPhoto(
                  sectionKey: InspectionSectionKeys.hoseConnectionInspection,
                  itemKey: InspectionItemKeys.overallHoseCondition,
                  itemLabel: 'Hose condition',
                ),
          onRemovePhoto: _isSaving ? null : _removeDraftPhoto,
        ),
      ],
    ),
  );

  Widget _filterSection() => SectionCard(
    key: _keys[InspectionSectionKeys.filtrationBreatherService],
    title: 'Filtration & Breather Service',
    subtitle: 'Record part numbers, replacement status, and filter photos.',
    child: Column(
      children: [
        _fieldGrid([
          _TextFieldSpec(_breatherPartNumber, 'Breather part number'),
          _TextFieldSpec(_pressureFilterPartNumber, 'Pressure filter PN'),
          _TextFieldSpec(_returnFilterPartNumber, 'Return filter PN'),
        ]),
        const SizedBox(height: 12),
        _controlGrid([
          _dropdownField<FilterReplacementStatus>(
            label: 'Breather Replaced',
            value: _breatherReplaced,
            values: FilterReplacementStatus.values,
            labelFor: (value) => value.label,
            onChanged: (value) => setState(() => _breatherReplaced = value),
          ),
          _dropdownField<FilterReplacementStatus>(
            label: 'Pressure Filter Replaced',
            value: _pressureFilterReplaced,
            values: FilterReplacementStatus.values,
            labelFor: (value) => value.label,
            onChanged: (value) =>
                setState(() => _pressureFilterReplaced = value),
          ),
          _dropdownField<FilterReplacementStatus>(
            label: 'Return Filter Replaced',
            value: _returnFilterReplaced,
            values: FilterReplacementStatus.values,
            labelFor: (value) => value.label,
            onChanged: (value) => setState(() => _returnFilterReplaced = value),
          ),
        ]),
        const SizedBox(height: 12),
        PhotoGrid(
          photos: _photosFor(
            sectionKey: InspectionSectionKeys.filtrationBreatherService,
            itemKey: InspectionItemKeys.breatherPartNumber,
          ),
          addButtonKey: const Key('filter-add-photo-button'),
          onAddPhoto: _isSaving
              ? null
              : () => _addDraftPhoto(
                  sectionKey: InspectionSectionKeys.filtrationBreatherService,
                  itemKey: InspectionItemKeys.breatherPartNumber,
                  itemLabel: 'Filter / breather photo',
                ),
          onRemovePhoto: _isSaving ? null : _removeDraftPhoto,
        ),
      ],
    ),
  );

  Widget _operationalSection() => SectionCard(
    key: _keys[InspectionSectionKeys.operationalDataSystemTest],
    title: 'Operational Data / System Test',
    subtitle: 'Capture running state, settings, and temperature readings.',
    child: Column(
      children: [
        _controlGrid([
          _dropdownField<YesNoNa>(
            label: 'Were you able to have the equipment running?',
            value: _running,
            values: YesNoNa.values,
            labelFor: (value) => value.label,
            onChanged: (value) => setState(() => _running = value),
          ),
          TextField(
            controller: _pumpCompensatorSetting,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Pump Compensator Setting Observed',
            ),
          ),
          _dropdownField<YesNoNa>(
            label: 'Change Pump Compensator Setting',
            value: _changePumpCompensator,
            values: YesNoNa.values,
            labelFor: (value) => value.label,
            onChanged: (value) =>
                setState(() => _changePumpCompensator = value),
          ),
          TextField(
            controller: _systemReliefSetting,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'System Relief Setting Observed',
            ),
          ),
          _dropdownField<YesNoNa>(
            label: 'Change System Relief Setting',
            value: _changeSystemRelief,
            values: YesNoNa.values,
            labelFor: (value) => value.label,
            onChanged: (value) => setState(() => _changeSystemRelief = value),
          ),
          TextField(
            controller: _operatingTemperature,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Operating Temperature',
            ),
          ),
          _dropdownField<TemperatureUnit>(
            label: 'Operating Temperature Unit',
            value: _operatingTemperatureUnit,
            values: TemperatureUnit.values,
            labelFor: (value) => value.symbol,
            onChanged: (value) =>
                setState(() => _operatingTemperatureUnit = value),
          ),
          TextField(
            controller: _accumulatorPreCharge,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Accumulator Pre-charge',
            ),
          ),
          _dropdownField<YesNoNa>(
            label: 'Charge Accumulator',
            value: _chargeAccumulator,
            values: YesNoNa.values,
            labelFor: (value) => value.label,
            onChanged: (value) => setState(() => _chargeAccumulator = value),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _operationalNotes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Operational notes'),
        ),
      ],
    ),
  );

  Widget _followUpSection() => SectionCard(
    key: _keys[InspectionSectionKeys.followUpRepairsQuoting],
    title: 'Follow-Up Repairs & Quoting',
    subtitle:
        'Track additional parts, action items, and final technician comments.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<YesNoNa>(
          key: ValueKey<String>(
            'additional-repairs-${_additionalRepairs?.name}',
          ),
          initialValue: _additionalRepairs,
          decoration: const InputDecoration(
            labelText: 'Are additional parts/repairs required?',
          ),
          items: YesNoNa.values
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text(value.label)),
              )
              .toList(),
          onChanged: (value) => setState(() => _additionalRepairs = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _finalComments,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Final tech comments'),
        ),
      ],
    ),
  );

  Widget _reviewSection(List<String> issues) => SectionCard(
    key: _keys[InspectionSectionKeys.reviewCompletion],
    title: 'Review & Completion',
    subtitle: 'Validation summary, critical acknowledgement, and signoff.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            StatusChip(
              text: '${issues.length} issue${issues.length == 1 ? '' : 's'}',
              color: issues.isEmpty ? CtsPalette.success : CtsPalette.danger,
            ),
            StatusChip(
              text: '${_photos.length} photos',
              color: CtsPalette.info,
            ),
            StatusChip(
              text:
                  '${_hoseCondition == null || _hoseCondition == ConditionRating.satisfactory ? 0 : 1} flagged hose item',
              color: CtsPalette.orange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final issue in issues) ...[
          _IssueTile(issue),
          const SizedBox(height: 8),
        ],
        CheckboxListTile(
          value: _criticalAcknowledged,
          onChanged: (value) =>
              setState(() => _criticalAcknowledged = value ?? false),
          title: const Text('Critical / Out of Service acknowledgement'),
          subtitle: const Text(
            'Lockout/Tagout required. Unit must not be operated until corrective action is complete.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: CtsPalette.orange,
        ),
        const SizedBox(height: 12),
        SignaturePad(
          controller: _signatureController,
          isSigned: _signed,
          onClear: () {
            _signatureController.clear();
            setState(() => _signed = false);
          },
        ),
        const SizedBox(height: 12),
        SignaturePad(
          title: 'Customer signature',
          controller: _customerSignatureController,
          isSigned: _customerSigned,
          padKey: const Key('customer_signature_pad_area'),
          inputKey: const Key('customer_signature_input_area'),
          onClear: () {
            _customerSignatureController.clear();
            setState(() => _customerSigned = false);
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _isHydrating || _isSaving ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save draft'),
            ),
            OutlinedButton.icon(
              onPressed: _isHydrating || _isSaving ? null : _completeInspection,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Complete inspection'),
            ),
          ],
        ),
      ],
    ),
  );

  List<_SectionState> _currentSectionStates() {
    SectionCompletionState state({
      required bool hasContent,
      required bool isComplete,
    }) {
      if (isComplete) {
        return SectionCompletionState.complete;
      }
      return hasContent
          ? SectionCompletionState.blocked
          : SectionCompletionState.notStarted;
    }

    final headerValues = <String>[
      _customer.text,
      _asset.text,
      _workOrder.text,
      _customerReference.text,
      _siteLocation.text,
      _tech.text,
      _shop.text,
    ];
    final componentValues = _componentPartNumbers.values
        .map((controller) => controller.text)
        .toList(growable: false);
    final fluidHasContent =
        _fluidLevel != null ||
        _fluidClarity != null ||
        _tankIntegrity != null ||
        _tankCleanoutPerformed != null ||
        _repairNotes.text.trim().isNotEmpty;
    final tankFlaggedReady =
        _tankIntegrity?.isFlagged != true ||
        (_repairNotes.text.trim().isNotEmpty &&
            _hasPhoto(
              InspectionSectionKeys.fluidTankService,
              InspectionItemKeys.tankIntegrity,
            ));
    final hoseHasContent =
        _hoseCondition != null ||
        _hoseName.text.trim().isNotEmpty ||
        _hoseParts.text.trim().isNotEmpty;
    final hoseFlaggedReady =
        _hoseCondition?.isFlagged != true ||
        ((_hoseName.text.trim().isNotEmpty ||
                _hoseParts.text.trim().isNotEmpty) &&
            _hasPhoto(
              InspectionSectionKeys.hoseConnectionInspection,
              InspectionItemKeys.overallHoseCondition,
            ));
    final filterHasContent =
        _breatherPartNumber.text.trim().isNotEmpty ||
        _pressureFilterPartNumber.text.trim().isNotEmpty ||
        _returnFilterPartNumber.text.trim().isNotEmpty ||
        _breatherReplaced != null ||
        _pressureFilterReplaced != null ||
        _returnFilterReplaced != null;
    final operationalValues = <Object?>[
      _running,
      _pumpCompensatorSetting.text.trim().isEmpty ? null : true,
      _changePumpCompensator,
      _systemReliefSetting.text.trim().isEmpty ? null : true,
      _changeSystemRelief,
      _operatingTemperature.text.trim().isEmpty ? null : true,
      _operatingTemperatureUnit,
      _accumulatorPreCharge.text.trim().isEmpty ? null : true,
      _chargeAccumulator,
    ];
    final hasCritical =
        _tankIntegrity == ConditionRating.criticalOutOfService ||
        _hoseCondition == ConditionRating.criticalOutOfService;
    final signatureReady = _signed || _signatureController.isNotEmpty;

    return <_SectionState>[
      _SectionState(
        InspectionSectionKeys.jobAssetIdentification,
        'Job & Asset Identification',
        state(
          hasContent: headerValues.any((value) => value.trim().isNotEmpty),
          isComplete: headerValues.every((value) => value.trim().isNotEmpty),
        ),
      ),
      _SectionState(
        InspectionSectionKeys.componentTracking,
        'Component Tracking',
        state(
          hasContent: componentValues.any((value) => value.trim().isNotEmpty),
          isComplete: componentValues.any((value) => value.trim().isNotEmpty),
        ),
      ),
      _SectionState(
        InspectionSectionKeys.fluidTankService,
        'Fluid & Tank Service',
        state(
          hasContent: fluidHasContent,
          isComplete:
              _fluidLevel != null &&
              _fluidClarity != null &&
              _tankIntegrity != null &&
              _tankCleanoutPerformed != null &&
              tankFlaggedReady,
        ),
      ),
      _SectionState(
        InspectionSectionKeys.hoseConnectionInspection,
        'Hose & Connection Inspection',
        state(
          hasContent: hoseHasContent,
          isComplete: _hoseCondition != null && hoseFlaggedReady,
        ),
      ),
      _SectionState(
        InspectionSectionKeys.filtrationBreatherService,
        'Filtration & Breather Service',
        state(
          hasContent: filterHasContent,
          isComplete:
              _breatherPartNumber.text.trim().isNotEmpty &&
              _pressureFilterPartNumber.text.trim().isNotEmpty &&
              _returnFilterPartNumber.text.trim().isNotEmpty &&
              _breatherReplaced != null &&
              _pressureFilterReplaced != null &&
              _returnFilterReplaced != null,
        ),
      ),
      _SectionState(
        InspectionSectionKeys.operationalDataSystemTest,
        'Operational Data / System Test',
        state(
          hasContent: operationalValues.any((value) => value != null),
          isComplete: operationalValues.every((value) => value != null),
        ),
      ),
      _SectionState(
        InspectionSectionKeys.followUpRepairsQuoting,
        'Follow-Up Repairs & Quoting',
        state(
          hasContent:
              _additionalRepairs != null ||
              _finalComments.text.trim().isNotEmpty,
          isComplete: _additionalRepairs != null,
        ),
      ),
      _SectionState(
        InspectionSectionKeys.reviewCompletion,
        'Review & Completion',
        state(
          hasContent: signatureReady || _criticalAcknowledged,
          isComplete: signatureReady && (!hasCritical || _criticalAcknowledged),
        ),
      ),
    ];
  }

  bool _hasPhoto(String sectionKey, String itemKey) {
    return _photosFor(sectionKey: sectionKey, itemKey: itemKey).isNotEmpty;
  }

  String _sectionKeyForIssue(String issue) {
    final normalized = issue.toLowerCase();
    if (normalized.contains('customer') ||
        normalized.contains('work order') ||
        normalized.contains('asset') ||
        normalized.contains('location / site') ||
        normalized.contains('technician name') ||
        normalized.contains('servicing shop')) {
      return InspectionSectionKeys.jobAssetIdentification;
    }
    if (normalized.contains('fluid') || normalized.contains('tank')) {
      return InspectionSectionKeys.fluidTankService;
    }
    if (normalized.contains('hose')) {
      return InspectionSectionKeys.hoseConnectionInspection;
    }
    if (normalized.contains('filter') || normalized.contains('breather')) {
      return InspectionSectionKeys.filtrationBreatherService;
    }
    if (normalized.contains('running') ||
        normalized.contains('pump') ||
        normalized.contains('relief') ||
        normalized.contains('temperature') ||
        normalized.contains('accumulator')) {
      return InspectionSectionKeys.operationalDataSystemTest;
    }
    if (normalized.contains('additional parts') ||
        normalized.contains('repairs')) {
      return InspectionSectionKeys.followUpRepairsQuoting;
    }
    return InspectionSectionKeys.reviewCompletion;
  }

  void _jumpTo(String key) {
    final target = _keys[key]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    try {
      final summary = await ref
          .read(workspaceProvider)
          .saveFormDraft(await _buildDraft());
      if (!mounted) {
        return;
      }
      _inspectionId ??= summary.id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Progress saved as ${summary.documentNumber}.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save this inspection: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _completeInspection() async {
    final issues = _buildIssues();
    if (issues.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Complete inspection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final issue in issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(issue),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final controller = ref.read(workspaceProvider);
      final summary = await controller.saveFormDraft(
        await _buildDraft(),
        complete: true,
      );
      if (!mounted) {
        return;
      }
      _inspectionId ??= summary.id;
      if (summary.status != InspectionStatus.complete) {
        final persistedIssues = await controller.completionIssueMessages(
          summary.id,
        );
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Complete inspection'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The inspection was saved, but is not complete yet.',
                ),
                const SizedBox(height: 12),
                for (final issue in persistedIssues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(issue),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      setState(() => _signed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inspection completed as ${summary.documentNumber}.'),
        ),
      );
      context.go('/inspection/${summary.id}', extra: summary);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to complete inspection: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<InspectionFormDraft> _buildDraft() async {
    final Uint8List? technicianSignature = _signatureController.isNotEmpty
        ? await _signatureController.toPngBytes()
        : null;
    final Uint8List? customerSignature = _customerSignatureController.isNotEmpty
        ? await _customerSignatureController.toPngBytes()
        : null;
    return InspectionFormDraft(
      inspectionId: _inspectionId,
      customer: _customer.text,
      workOrderNumber: _workOrder.text,
      customerReference: _customerReference.text,
      assetName: _asset.text,
      siteLocation: _siteLocation.text,
      technicianName: _tech.text,
      servicingShop: _shop.text,
      finalTechComments: _finalComments.text,
      componentPartNumbers: <String, String>{
        for (final entry in _componentPartNumbers.entries)
          entry.key: entry.value.text,
      },
      fluidLevel: _fluidLevel,
      fluidClarity: _fluidClarity,
      tankIntegrity: _tankIntegrity,
      tankNotes: _repairNotes.text,
      tankCleanoutPerformed: _tankCleanoutPerformed,
      hoseCondition: _hoseCondition,
      hoseNameLocation: _hoseName.text,
      hosePartsRequired: _hoseParts.text,
      breatherPartNumber: _breatherPartNumber.text,
      breatherReplaced: _breatherReplaced,
      pressureFilterPartNumber: _pressureFilterPartNumber.text,
      pressureFilterReplaced: _pressureFilterReplaced,
      returnFilterPartNumber: _returnFilterPartNumber.text,
      returnFilterReplaced: _returnFilterReplaced,
      equipmentRunning: _running,
      pumpCompensatorSetting: _pumpCompensatorSetting.text,
      changePumpCompensator: _changePumpCompensator,
      systemReliefSetting: _systemReliefSetting.text,
      changeSystemRelief: _changeSystemRelief,
      operatingTemperature: _operatingTemperature.text,
      operatingTemperatureUnit: _operatingTemperatureUnit,
      accumulatorPreCharge: _accumulatorPreCharge.text,
      chargeAccumulator: _chargeAccumulator,
      operationalNotes: _operationalNotes.text,
      additionalPartsRepairs: _additionalRepairs,
      photos: List<InspectionPhotoView>.unmodifiable(_photos),
      criticalAcknowledged: _criticalAcknowledged,
      technicianSignaturePngBytes: technicianSignature,
      customerSignaturePngBytes: customerSignature,
      keepExistingTechnicianSignature: _signed,
      keepExistingCustomerSignature: _customerSigned,
    );
  }

  Widget _componentCard(String title, IconData icon) {
    final controller = _componentPartNumbers[title]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CtsPalette.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: CtsPalette.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: ValueKey<String>(
                      'component-${title.toLowerCase().replaceAll(' ', '-')}',
                    ),
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Model / part number',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldGrid(List<_TextFieldSpec> fields) => _controlGrid(
    fields
        .map((field) {
          return TextField(
            key: field.key == null ? null : ValueKey<String>(field.key!),
            controller: field.controller,
            decoration: InputDecoration(labelText: field.label),
          );
        })
        .toList(growable: false),
  );

  Widget _controlGrid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 760
          ? 2
          : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.0 : 2.5,
        ),
        itemBuilder: (context, index) {
          return children[index];
        },
      );
    },
  );

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey<String>('$label-${value.hashCode}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (value) => DropdownMenuItem<T>(
              value: value,
              child: Text(
                labelFor(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Future<void> _addDraftPhoto({
    required String sectionKey,
    required String itemKey,
    required String itemLabel,
  }) async {
    final source = await showModalBottomSheet<PhotoInputSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add $itemLabel photo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Photos are compressed and saved locally with this inspection.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              key: const Key('photo-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Use camera'),
              subtitle: const Text('Capture a new field photo.'),
              onTap: () => Navigator.pop(context, PhotoInputSource.camera),
            ),
            ListTile(
              key: const Key('photo-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from device'),
              subtitle: const Text('Select one or more existing photos.'),
              onTap: () => Navigator.pop(context, PhotoInputSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final workspace = ref.read(workspaceProvider);
      if (_inspectionId == null) {
        final summary = await workspace.saveFormDraft(await _buildDraft());
        if (!mounted) {
          return;
        }
        _inspectionId = summary.id;
      }
      final inspectionId = _inspectionId!;
      final existingCount = _photosFor(
        sectionKey: sectionKey,
        itemKey: itemKey,
      ).length;
      final photoService = ref.read(photoServiceProvider);
      final managedPhotos = <ManagedInspectionPhoto>[];
      if (source == PhotoInputSource.camera) {
        final photo = await photoService.captureFromCamera(
          inspectionId: inspectionId,
          sectionKey: sectionKey,
          itemKey: itemKey,
          currentPhotoCount: existingCount,
          caption: '$itemLabel photo ${existingCount + 1}',
          sortOrder: existingCount,
        );
        if (photo != null) {
          managedPhotos.add(photo);
        }
      } else {
        final result = await photoService.addFromGallery(
          inspectionId: inspectionId,
          sectionKey: sectionKey,
          itemKey: itemKey,
          currentPhotoCount: existingCount,
          captionPrefix: '$itemLabel photo',
          startingSortOrder: existingCount,
        );
        managedPhotos.addAll(result.savedPhotos);
      }
      if (managedPhotos.isEmpty || !mounted) {
        return;
      }

      setState(() {
        _photos.addAll(
          managedPhotos.map(
            (photo) => InspectionPhotoView(
              assetPath: photo.filePath,
              caption: photo.caption,
              sectionTitle: InspectionSectionKeys.titleFor(sectionKey),
              itemLabel: itemKey,
              capturedAt: photo.capturedAt.toLocal(),
            ),
          ),
        );
      });
      await workspace.saveFormDraft(await _buildDraft());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${managedPhotos.length} $itemLabel photo${managedPhotos.length == 1 ? '' : 's'} saved locally.',
          ),
        ),
      );
    } on PhotoServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to add photo: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _removeDraftPhoto(InspectionPhotoView photo) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove photo?'),
        content: Text(
          '“${photo.caption}” will be removed from this inspection and the local device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final inspectionId = _inspectionId;
      if (inspectionId != null) {
        await ref
            .read(workspaceProvider)
            .removeInspectionPhoto(inspectionId, photo.assetPath);
      }
      if (!mounted) {
        return;
      }
      setState(() => _photos.remove(photo));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo removed.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to remove photo: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<InspectionPhotoView> _photosFor({
    required String sectionKey,
    required String itemKey,
  }) {
    final sectionTitle = InspectionSectionKeys.titleFor(sectionKey);
    return _photos
        .where(
          (photo) =>
              photo.sectionTitle == sectionTitle && photo.itemLabel == itemKey,
        )
        .toList(growable: false);
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
  );

  List<String> _buildIssues() {
    final issues = <String>[];
    void requireValue(Object? value, String message) {
      if (value == null) {
        issues.add(message);
      }
    }

    void requireText(TextEditingController controller, String message) {
      if (controller.text.trim().isEmpty) {
        issues.add(message);
      }
    }

    requireValue(_fluidLevel, 'Fluid Level must be answered.');
    requireValue(_fluidClarity, 'Fluid Clarity must be answered.');
    requireValue(_tankIntegrity, 'Tank Integrity must be rated.');
    requireValue(
      _tankCleanoutPerformed,
      'Tank Cleanout Performed must be answered.',
    );
    requireValue(_hoseCondition, 'Overall Hose Condition must be rated.');
    requireText(_breatherPartNumber, 'Breather Part Number is required.');
    requireValue(_breatherReplaced, 'Breather Replaced must be answered.');
    requireText(_pressureFilterPartNumber, 'Pressure Filter PN is required.');
    requireValue(
      _pressureFilterReplaced,
      'Pressure Filter Replaced must be answered.',
    );
    requireText(_returnFilterPartNumber, 'Return Filter PN is required.');
    requireValue(
      _returnFilterReplaced,
      'Return Filter Replaced must be answered.',
    );
    requireValue(_running, 'Running equipment status must be answered.');
    requireText(
      _pumpCompensatorSetting,
      'Pump Compensator Setting Observed is required.',
    );
    requireValue(
      _changePumpCompensator,
      'Pump compensator change decision must be answered.',
    );
    requireText(
      _systemReliefSetting,
      'System Relief Setting Observed is required.',
    );
    requireValue(
      _changeSystemRelief,
      'System relief change decision must be answered.',
    );
    requireText(_operatingTemperature, 'Operating Temperature is required.');
    requireValue(
      _operatingTemperatureUnit,
      'Operating Temperature unit must be selected.',
    );
    requireText(_accumulatorPreCharge, 'Accumulator Pre-charge is required.');
    requireValue(
      _chargeAccumulator,
      'Accumulator charge decision must be answered.',
    );
    requireValue(
      _additionalRepairs,
      'Additional parts / repairs decision must be answered.',
    );
    if ((_tankIntegrity == ConditionRating.criticalOutOfService ||
            _hoseCondition == ConditionRating.criticalOutOfService) &&
        !_criticalAcknowledged) {
      issues.add('Critical / Out of Service acknowledgement must be checked.');
    }
    if (_tankIntegrity?.isFlagged == true && _repairNotes.text.trim().isEmpty) {
      issues.add('Flagged tank integrity items require notes.');
    }
    if (_tankIntegrity?.isFlagged == true &&
        !_hasPhoto(
          InspectionSectionKeys.fluidTankService,
          InspectionItemKeys.tankIntegrity,
        )) {
      issues.add('Flagged tank integrity items require at least one photo.');
    }
    if (_hoseCondition?.isFlagged == true &&
        _hoseParts.text.trim().isEmpty &&
        _hoseName.text.trim().isEmpty) {
      issues.add('Flagged hose condition items require hose details.');
    }
    if (_hoseCondition?.isFlagged == true &&
        !_hasPhoto(
          InspectionSectionKeys.hoseConnectionInspection,
          InspectionItemKeys.overallHoseCondition,
        )) {
      issues.add('Flagged hose condition items require at least one photo.');
    }
    if (_additionalRepairs == YesNoNa.yes &&
        _finalComments.text.trim().isEmpty) {
      issues.add(
        'Describe the additional parts or repairs in final tech comments.',
      );
    }
    if (!_signed && _signatureController.isEmpty) {
      issues.add('Drawn signature is required.');
    }
    if (_customer.text.trim().isEmpty) {
      issues.add('Customer / Site Name is required.');
    }
    if (_workOrder.text.trim().isEmpty) {
      issues.add('Work order number is required.');
    }
    if (_asset.text.trim().isEmpty) {
      issues.add('HPU Asset ID / Name is required.');
    }
    if (_customerReference.text.trim().isEmpty) {
      issues.add('Customer reference / PO is required.');
    }
    if (_siteLocation.text.trim().isEmpty) {
      issues.add('Location / site is required.');
    }
    if (_tech.text.trim().isEmpty) {
      issues.add('Technician name is required before completion.');
    }
    if (_shop.text.trim().isEmpty) {
      issues.add('Servicing shop is required.');
    }
    return issues;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.isEdit,
    required this.isHydrating,
    required this.isSaving,
    required this.onSave,
    required this.onComplete,
  });

  final bool isEdit;
  final bool isHydrating;
  final bool isSaving;
  final VoidCallback? onSave;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [CtsPalette.navyAlt, CtsPalette.navy, Color(0xFF132944)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit
                    ? isHydrating
                          ? 'Loading Inspection'
                          : 'Edit Inspection'
                    : 'New Inspection',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Work through each section, attach field evidence, then review all blockers before sign-off.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onSave,
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Saving…' : 'Save progress'),
              ),
              OutlinedButton.icon(
                onPressed: onComplete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Mark complete'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 18), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 18),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.sections, required this.onJump});

  final List<_SectionState> sections;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final listHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - 340).clamp(260.0, 520.0).toDouble()
            : 520.0;
        return SectionCard(
          title: 'Sections',
          subtitle: 'Tap to jump between the fixed inspection sections.',
          child: SizedBox(
            height: listHeight,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final section in sections) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onJump(section.key),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _stateColor(
                              section.status,
                            ).withValues(alpha: 0.24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            StatusChip(
                              text: section.status.label,
                              color: _stateColor(section.status),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (section != sections.last) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _stateColor(SectionCompletionState state) {
    switch (state) {
      case SectionCompletionState.complete:
        return CtsPalette.success;
      case SectionCompletionState.inProgress:
        return CtsPalette.orange;
      case SectionCompletionState.blocked:
        return CtsPalette.danger;
      case SectionCompletionState.notStarted:
        return CtsPalette.slate;
    }
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.issues,
    required this.photos,
    required this.onJump,
    required this.sectionForIssue,
  });

  final List<String> issues;
  final List<InspectionPhotoView> photos;
  final ValueChanged<String> onJump;
  final String Function(String issue) sectionForIssue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SectionCard(
            title: 'Validation',
            subtitle: 'Highlights missing fields and completion blockers.',
            child: Column(
              children: [
                SizedBox(
                  height: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final issue in issues) ...[
                          _IssueTile(
                            issue,
                            onTap: () => onJump(sectionForIssue(issue)),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (issues.isEmpty)
                          const _IssueTile(
                            'No blocking issues currently visible.',
                            isSuccess: true,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      onJump(InspectionSectionKeys.reviewCompletion),
                  child: const Text('Jump to review'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Photos',
            subtitle: 'Current local photo stack for the inspection.',
            child: PhotoGrid(photos: photos),
          ),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile(this.text, {this.onTap, this.isSuccess = false});

  final String text;
  final VoidCallback? onTap;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? CtsPalette.success : CtsPalette.danger;
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TextFieldSpec {
  const _TextFieldSpec(this.controller, this.label, {this.key});
  final TextEditingController controller;
  final String label;
  final String? key;
}

class _SectionState {
  const _SectionState(this.key, this.title, this.status);
  final String key;
  final String title;
  final SectionCompletionState status;
}
