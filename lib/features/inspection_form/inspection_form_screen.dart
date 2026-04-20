import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/workspace_models.dart';
import '../../data/models/inspection_enums.dart';
import '../../widgets/condition_selector.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/required_field_label.dart';
import '../../widgets/section_card.dart';
import '../../widgets/signature_pad.dart';

class InspectionFormScreen extends StatefulWidget {
  const InspectionFormScreen({super.key, this.seed});

  final InspectionSummary? seed;

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  late final ScrollController _scrollController;
  late final SignatureController _signatureController;
  late final Map<String, GlobalKey> _keys;
  late final TextEditingController _customer;
  late final TextEditingController _asset;
  late final TextEditingController _workOrder;
  late final TextEditingController _tech;
  late final TextEditingController _shop;
  late final TextEditingController _finalComments;
  late final TextEditingController _repairNotes;
  late final TextEditingController _hoseName;
  late final TextEditingController _hoseParts;
  late final TextEditingController _componentPn;

  final List<InspectionPhotoView> _photos = [
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
  ];

  final List<_SectionState> _sections = [
    _SectionState(
      InspectionSectionKeys.jobAssetIdentification,
      'Job & Asset Identification',
      SectionCompletionState.complete,
    ),
    _SectionState(
      InspectionSectionKeys.componentTracking,
      'Component Tracking',
      SectionCompletionState.complete,
    ),
    _SectionState(
      InspectionSectionKeys.fluidTankService,
      'Fluid & Tank Service',
      SectionCompletionState.inProgress,
    ),
    _SectionState(
      InspectionSectionKeys.hoseConnectionInspection,
      'Hose & Connection Inspection',
      SectionCompletionState.inProgress,
    ),
    _SectionState(
      InspectionSectionKeys.filtrationBreatherService,
      'Filtration & Breather Service',
      SectionCompletionState.complete,
    ),
    _SectionState(
      InspectionSectionKeys.operationalDataSystemTest,
      'Operational Data / System Test',
      SectionCompletionState.complete,
    ),
    _SectionState(
      InspectionSectionKeys.followUpRepairsQuoting,
      'Follow-Up Repairs & Quoting',
      SectionCompletionState.inProgress,
    ),
    _SectionState(
      InspectionSectionKeys.reviewCompletion,
      'Review & Completion',
      SectionCompletionState.blocked,
    ),
  ];

  final List<_Issue> _issues = [
    _Issue('Flagged fluid service item needs comment and photo.'),
    _Issue('Critical acknowledgement required before completion.'),
    _Issue('Drawn signature required for signoff.'),
  ];

  bool _criticalAcknowledged = false;
  bool _signed = false;
  ConditionRating? _tankIntegrity = ConditionRating.monitorAtRisk;
  ConditionRating? _hoseCondition = ConditionRating.monitorAtRisk;
  YesNoNa _running = YesNoNa.yes;
  YesNoNa _additionalRepairs = YesNoNa.yes;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: CtsPalette.orange,
      exportBackgroundColor: Colors.white,
    );
    _keys = {for (final section in _sections) section.key: GlobalKey()};
    final seed = widget.seed;
    _customer = TextEditingController(text: seed?.customer ?? 'Moraine Quarry');
    _asset = TextEditingController(
      text: seed?.assetName ?? 'HPU-12 Main Press',
    );
    _workOrder = TextEditingController(
      text: seed?.workOrderNumber ?? 'WO-48912',
    );
    _tech = TextEditingController(text: seed?.technicianName ?? 'R. Ellis');
    _shop = TextEditingController(
      text: seed?.servicingShop ?? 'CTS Edmonton Service',
    );
    _finalComments = TextEditingController(
      text:
          seed?.finalTechComments ??
          'Inspection conducted in landscape tablet mode.',
    );
    _repairNotes = TextEditingController(
      text:
          'Additional parts required for hose replacement and breather service.',
    );
    _hoseName = TextEditingController(text: 'Return hose at manifold');
    _hoseParts = TextEditingController(
      text: 'Hose assembly, JIC fittings, crimp sleeves',
    );
    _componentPn = TextEditingController(text: 'Parker PGP511A0120CL2H');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _signatureController.dispose();
    _customer.dispose();
    _asset.dispose();
    _workOrder.dispose();
    _tech.dispose();
    _shop.dispose();
    _finalComments.dispose();
    _repairNotes.dispose();
    _hoseName.dispose();
    _hoseParts.dispose();
    _componentPn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issues = _buildIssues();
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= 1120;
        final showSummary = constraints.maxWidth >= 1350;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showRail) ...[
              SizedBox(
                width: 250,
                child: _SectionRail(sections: _sections, onJump: _jumpTo),
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
                      isEdit: widget.seed != null,
                      onGeneratePdf: _notify,
                      onComplete: _showCompleteDialog,
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
          _TextFieldSpec(_customer, 'Customer / Site Name'),
          _TextFieldSpec(_asset, 'HPU Asset ID / Name'),
          _TextFieldSpec(_workOrder, 'Work order number'),
          _TextFieldSpec(_tech, 'Technician name'),
          _TextFieldSpec(_shop, 'Servicing shop'),
        ]),
        const SizedBox(height: 14),
        PhotoGrid(photos: _photos.take(1).toList(growable: false)),
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
        PhotoGrid(photos: _photos.take(2).toList(growable: false)),
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
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add hose entry'),
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
          _TextFieldSpec(_componentPn, 'Breather part number'),
          _TextFieldSpec(_componentPn, 'Pressure filter PN'),
          _TextFieldSpec(_componentPn, 'Return filter PN'),
        ]),
        const SizedBox(height: 12),
        PhotoGrid(photos: _photos.take(1).toList(growable: false)),
      ],
    ),
  );

  Widget _operationalSection() => SectionCard(
    key: _keys[InspectionSectionKeys.operationalDataSystemTest],
    title: 'Operational Data / System Test',
    subtitle: 'Capture running state, settings, and temperature readings.',
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<YesNoNa>(
                initialValue: _running,
                decoration: const InputDecoration(
                  labelText: 'Were you able to have the equipment running?',
                ),
                items: YesNoNa.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _running = value ?? YesNoNa.yes),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: TextField(
                decoration: InputDecoration(labelText: 'Operating temperature'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _repairNotes,
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
          onChanged: (value) =>
              setState(() => _additionalRepairs = value ?? YesNoNa.yes),
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
                  '${_hoseCondition == ConditionRating.satisfactory ? 0 : 1} flagged hose item',
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
        Row(
          children: [
            FilledButton.icon(
              onPressed: _notify,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save draft'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _showCompleteDialog,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Complete inspection'),
            ),
          ],
        ),
      ],
    ),
  );

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

  void _notify() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft saved locally in the tablet workspace.'),
      ),
    );
  }

  void _showCompleteDialog() {
    setState(() => _signed = true);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete inspection'),
        content: const Text(
          'This UI is ready for the persistence and PDF layer to attach beneath it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _componentCard(String title, IconData icon) {
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
                    controller: _componentPn,
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

  Widget _fieldGrid(List<_TextFieldSpec> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 760
          ? 2
          : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fields.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.0 : 2.5,
        ),
        itemBuilder: (context, index) {
          final field = fields[index];
          return TextField(
            controller: field.controller,
            decoration: InputDecoration(labelText: field.label),
          );
        },
      );
    },
  );

  Widget _label(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
  );

  List<String> _buildIssues() {
    final issues = _issues.map((issue) => issue.text).toList(growable: true);
    if (_tankIntegrity == ConditionRating.criticalOutOfService &&
        !_criticalAcknowledged) {
      issues.add('Critical / Out of Service acknowledgement must be checked.');
    }
    if (!_signed) {
      issues.add('Drawn signature is required.');
    }
    if (_customer.text.trim().isEmpty) {
      issues.add('Customer / Site Name is required.');
    }
    if (_workOrder.text.trim().isEmpty) {
      issues.add('Work order number is required.');
    }
    if (_tech.text.trim().isEmpty) {
      issues.add('Technician name is required before completion.');
    }
    return issues;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.isEdit,
    required this.onGeneratePdf,
    required this.onComplete,
  });

  final bool isEdit;
  final VoidCallback onGeneratePdf;
  final VoidCallback onComplete;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Inspection' : 'New Inspection',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Landscape-first three-panel editor with anchored sections, large touch targets, and validation feedback.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onGeneratePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Generate PDF'),
              ),
              OutlinedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Mark complete'),
              ),
            ],
          ),
        ],
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
    return SectionCard(
      title: 'Sections',
      subtitle: 'Tap to jump between the fixed inspection sections.',
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _stateColor(section.status).withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
  });

  final List<String> issues;
  final List<InspectionPhotoView> photos;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionCard(
          title: 'Validation',
          subtitle: 'Highlights missing fields and completion blockers.',
          child: Column(
            children: [
              for (final issue in issues) ...[
                _IssueTile(issue),
                const SizedBox(height: 8),
              ],
              if (issues.isEmpty)
                const _IssueTile('No blocking issues currently visible.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => onJump(InspectionSectionKeys.reviewCompletion),
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
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CtsPalette.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TextFieldSpec {
  const _TextFieldSpec(this.controller, this.label);
  final TextEditingController controller;
  final String label;
}

class _SectionState {
  const _SectionState(this.key, this.title, this.status);
  final String key;
  final String title;
  final SectionCompletionState status;
}

class _Issue {
  const _Issue(this.text);
  final String text;
}
