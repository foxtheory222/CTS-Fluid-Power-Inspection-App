import 'dart:io';

import 'package:cts_fluid_power_inspection_app/core/constants.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:flutter/material.dart';

import 'spec_models.dart';
import 'spec_service.dart';

class SpecTabletHarnessApp extends StatefulWidget {
  const SpecTabletHarnessApp({super.key, required this.service});

  final SpecInspectionService service;

  @override
  State<SpecTabletHarnessApp> createState() => _SpecTabletHarnessAppState();
}

class _SpecTabletHarnessAppState extends State<SpecTabletHarnessApp> {
  final TextEditingController customerController = TextEditingController(
    text: 'Acme Manufacturing',
  );
  final TextEditingController workOrderController = TextEditingController(
    text: 'WO-48158',
  );
  final TextEditingController customerReferenceController =
      TextEditingController(text: 'PO-1194');
  final TextEditingController assetController = TextEditingController(
    text: 'HPU-13',
  );
  final TextEditingController locationController = TextEditingController(
    text: 'Main Plant',
  );
  final TextEditingController technicianController = TextEditingController(
    text: 'Jordan Lee',
  );
  final TextEditingController shopController = TextEditingController(
    text: 'CTS North Shop',
  );
  final TextEditingController commentController = TextEditingController();
  final TextEditingController recipientController = TextEditingController(
    text: 'customer@example.com',
  );

  SpecInspection? activeInspection;
  String infoMessage = '';
  File? lastExportedBundle;
  bool criticalMode = false;

  @override
  void dispose() {
    customerController.dispose();
    workOrderController.dispose();
    customerReferenceController.dispose();
    assetController.dispose();
    locationController.dispose();
    technicianController.dispose();
    shopController.dispose();
    commentController.dispose();
    recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text(AppConstants.appName)),
        body: activeInspection == null ? _buildDashboard() : _buildEditor(),
      ),
    );
  }

  Widget _buildDashboard() {
    final inspections = widget.service.inspections.toList(growable: false);
    final counts = <InspectionStatus, int>{
      for (final status in InspectionStatus.values)
        status: inspections
            .where((SpecInspection inspection) => inspection.status == status)
            .length,
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'CTS Fluid Power Inspection App',
            key: Key('dashboard_title'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: InspectionStatus.values
                .map(
                  (InspectionStatus status) => Chip(
                    label: Text('${status.label}: ${counts[status]}'),
                    key: Key('count_${status.value}'),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('new_inspection_button'),
            onPressed: () {
              setState(() {
                activeInspection = widget.service.createInspection(
                  now: DateTime.utc(2026, 4, 20, 16, 0),
                  customer: customerController.text,
                  workOrderNumber: workOrderController.text,
                  customerReference: customerReferenceController.text,
                  assetName: assetController.text,
                  siteLocation: locationController.text,
                  technicianName: technicianController.text,
                  servicingShop: shopController.text,
                );
                _seedBaselineResponses(activeInspection!);
              });
            },
            child: const Text('New Inspection'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: inspections
                  .map(
                    (SpecInspection inspection) => ListTile(
                      title: Text(inspection.documentNumber),
                      subtitle: Text(
                        '${inspection.customer} • ${inspection.status.label}',
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    final inspection = activeInspection!;
    final validation = widget.service.validateCompletion(inspection);
    return Row(
      children: <Widget>[
        NavigationRail(
          selectedIndex: 0,
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.badge_outlined),
              label: Text('Header'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.warning_amber_outlined),
              label: Text('Problems'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.fact_check_outlined),
              label: Text('Review'),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                'Document number: ${inspection.documentNumber}',
                key: const Key('document_number_text'),
              ),
              Text('Status: ${inspection.status.label}'),
              const SizedBox(height: 16),
              _buildEditorActions(inspection),
              const SizedBox(height: 16),
              const Text(
                'Job & Asset Identification',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: customerController,
                      decoration: const InputDecoration(labelText: 'Customer'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: workOrderController,
                      decoration: const InputDecoration(
                        labelText: 'Work Order',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: customerReferenceController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Reference',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: assetController,
                      decoration: const InputDecoration(labelText: 'Asset'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: technicianController,
                      decoration: const InputDecoration(
                        labelText: 'Technician',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: shopController,
                      decoration: const InputDecoration(
                        labelText: 'Servicing Shop',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      key: const Key('issue_comment_field'),
                      controller: commentController,
                      decoration: const InputDecoration(
                        labelText: 'Issue comment',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Review Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Status: ${inspection.status.label}'),
                Text(
                  'Flagged items: ${inspection.responses.where((SpecResponse r) => r.isFlagged).length}',
                ),
                Text('Action items: ${inspection.actionItems.length}'),
                Text('Photos: ${inspection.photos.length}'),
                Text(
                  'Recipients: ${widget.service.recentRecipientUsage().length}',
                ),
                const SizedBox(height: 16),
                ...validation.issues.map(
                  (SpecValidationIssue issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      issue.message,
                      key: ValueKey<String>(issue.fieldKey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('recipient_field'),
                  controller: recipientController,
                  decoration: const InputDecoration(labelText: 'Recipient'),
                ),
                const SizedBox(height: 12),
                Text(infoMessage, key: const Key('info_message')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _seedBaselineResponses(SpecInspection inspection) {
    if (inspection.responses.isNotEmpty) {
      return;
    }

    void addRequiredResponse({
      required String sectionKey,
      required String itemKey,
      required String itemLabel,
      required InspectionFieldType fieldType,
      required String value,
      ConditionRating? conditionRating,
    }) {
      widget.service.upsertResponse(
        inspection: inspection,
        sectionKey: sectionKey,
        itemKey: itemKey,
        itemLabel: itemLabel,
        fieldType: fieldType,
        value: value,
        isRequired: true,
        conditionRating: conditionRating,
      );
    }

    addRequiredResponse(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidLevel,
      itemLabel: 'Fluid Level',
      fieldType: InspectionFieldType.dropdown,
      value: FluidLevelOption.withinTolerance.value,
      conditionRating: ConditionRating.satisfactory,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidClarity,
      itemLabel: 'Fluid Clarity',
      fieldType: InspectionFieldType.dropdown,
      value: FluidClarityOption.clear.value,
      conditionRating: ConditionRating.satisfactory,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankIntegrity,
      itemLabel: 'Tank Integrity',
      fieldType: InspectionFieldType.conditionRating,
      value: ConditionRating.satisfactory.value,
      conditionRating: ConditionRating.satisfactory,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankCleanoutPerformed,
      itemLabel: 'Tank Cleanout Performed',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.yes.value,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.hoseConnectionInspection,
      itemKey: InspectionItemKeys.overallHoseCondition,
      itemLabel: 'Overall Hose Condition',
      fieldType: InspectionFieldType.conditionRating,
      value: ConditionRating.satisfactory.value,
      conditionRating: ConditionRating.satisfactory,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherPartNumber,
      itemLabel: 'Breather Part Number',
      fieldType: InspectionFieldType.text,
      value: 'BR-100',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherReplaced,
      itemLabel: 'Breather Replaced?',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.yes.value,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterPartNumber,
      itemLabel: 'Pressure Filter PN',
      fieldType: InspectionFieldType.text,
      value: 'PF-200',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterReplaced,
      itemLabel: 'Pressure Filter Replaced?',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.yes.value,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterPartNumber,
      itemLabel: 'Return Filter PN',
      fieldType: InspectionFieldType.text,
      value: 'RF-300',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterReplaced,
      itemLabel: 'Return Filter Replaced?',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.yes.value,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.equipmentRunning,
      itemLabel: 'Equipment Running',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.yes.value,
      conditionRating: ConditionRating.satisfactory,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.pumpCompensatorSetting,
      itemLabel: 'Pump Compensator Setting Observed',
      fieldType: InspectionFieldType.number,
      value: '2800',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changePumpCompensator,
      itemLabel: 'Do you need to change the pump compensator setting?',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.no.value,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.systemReliefSetting,
      itemLabel: 'System Relief Setting Observed',
      fieldType: InspectionFieldType.number,
      value: '3000',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changeSystemRelief,
      itemLabel: 'Do you need to change the system relief setting?',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.no.value,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperature,
      itemLabel: 'Operating Temperature',
      fieldType: InspectionFieldType.number,
      value: '55',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperatureUnit,
      itemLabel: 'Operating Temperature Unit',
      fieldType: InspectionFieldType.dropdown,
      value: '°C',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.accumulatorPreCharge,
      itemLabel: 'Accumulator Pre-charge',
      fieldType: InspectionFieldType.number,
      value: '900',
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.chargeAccumulator,
      itemLabel: 'Does the accumulator need to be charged?',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.no.value,
    );
    addRequiredResponse(
      sectionKey: InspectionSectionKeys.followUpRepairsQuoting,
      itemKey: InspectionItemKeys.additionalPartsRepairs,
      itemLabel: 'Are additional parts/repairs required?',
      fieldType: InspectionFieldType.yesNoNa,
      value: YesNoNa.no.value,
    );
  }

  Widget _buildEditorActions(SpecInspection inspection) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        ElevatedButton(
          key: const Key('save_header_button'),
          onPressed: () {
            setState(() {
              inspection
                ..customer = customerController.text
                ..workOrderNumber = workOrderController.text
                ..customerReference = customerReferenceController.text
                ..assetName = assetController.text
                ..siteLocation = locationController.text
                ..technicianName = technicianController.text
                ..servicingShop = shopController.text;
              widget.service.saveInspection(inspection);
            });
          },
          child: const Text('Save Header'),
        ),
        ElevatedButton(
          key: const Key('at_risk_button'),
          onPressed: () {
            setState(() {
              criticalMode = false;
              widget.service.upsertResponse(
                inspection: inspection,
                sectionKey: InspectionSectionKeys.hoseConnectionInspection,
                itemKey: InspectionItemKeys.overallHoseCondition,
                itemLabel: 'Overall Hose Condition',
                fieldType: InspectionFieldType.conditionRating,
                value: ConditionRating.monitorAtRisk.value,
                isRequired: true,
                conditionRating: ConditionRating.monitorAtRisk,
                comment: commentController.text,
              );
              widget.service.addManualActionItem(
                inspection: inspection,
                sourceSectionKey:
                    InspectionSectionKeys.hoseConnectionInspection,
                sourceItemKey: InspectionItemKeys.overallHoseCondition,
                conditionRating: ConditionRating.monitorAtRisk,
                title: 'Overall Hose Condition requires attention',
                description: commentController.text,
              );
            });
          },
          child: const Text('Mark At Risk'),
        ),
        ElevatedButton(
          key: const Key('critical_button'),
          onPressed: () {
            setState(() {
              criticalMode = true;
              widget.service.upsertResponse(
                inspection: inspection,
                sectionKey: InspectionSectionKeys.operationalDataSystemTest,
                itemKey: InspectionItemKeys.equipmentRunning,
                itemLabel: 'Equipment Running',
                fieldType: InspectionFieldType.yesNoNa,
                value: YesNoNa.no.value,
                isRequired: true,
                conditionRating: ConditionRating.criticalOutOfService,
                comment: commentController.text,
              );
              widget.service.addManualActionItem(
                inspection: inspection,
                sourceSectionKey:
                    InspectionSectionKeys.operationalDataSystemTest,
                sourceItemKey: InspectionItemKeys.equipmentRunning,
                conditionRating: ConditionRating.criticalOutOfService,
                title: 'Equipment Running requires immediate shutdown',
                description: commentController.text,
              );
            });
          },
          child: const Text('Mark Critical'),
        ),
        ElevatedButton(
          key: const Key('add_photo_button'),
          onPressed: () async {
            final sectionKey = criticalMode
                ? InspectionSectionKeys.operationalDataSystemTest
                : InspectionSectionKeys.hoseConnectionInspection;
            final itemKey = criticalMode
                ? InspectionItemKeys.equipmentRunning
                : InspectionItemKeys.overallHoseCondition;
            await widget.service.addPhoto(
              inspection: inspection,
              sectionKey: sectionKey,
              itemKey: itemKey,
              caption: 'Harness photo',
            );
            setState(() {});
          },
          child: const Text('Add Photo'),
        ),
        ElevatedButton(
          key: const Key('loto_ack_button'),
          onPressed: () {
            setState(() {
              inspection.criticalAcknowledged = true;
              widget.service.saveInspection(inspection);
            });
          },
          child: const Text('LOTO Ack'),
        ),
        ElevatedButton(
          key: const Key('add_hose_button'),
          onPressed: () {
            setState(() {
              widget.service.addHoseEntry(
                inspection: inspection,
                hoseNameLocation: 'Return line near manifold',
                failureType: FailureType.leak,
                hoseSize: '3/8 in',
                hoseLength: '42 in',
                hoseType: '2-wire hydraulic hose',
                fittingEndA: 'JIC 37',
                fittingEndB: 'ORFS',
                quantity: 1,
                replacementPartNumbers: 'H-334, F-221',
                partsNeeded: 'Hose, fittings, clamps',
                notes: 'Leak at swivel fitting.',
              );
            });
          },
          child: const Text('Add Hose Entry'),
        ),
        ElevatedButton(
          key: const Key('signature_button'),
          onPressed: () {
            setState(() {
              inspection.signatureFilePath = '/tmp/signature.png';
              widget.service.saveInspection(inspection);
            });
          },
          child: const Text('Draw Signature'),
        ),
        ElevatedButton(
          key: const Key('complete_button'),
          onPressed: () {
            setState(() {
              try {
                widget.service.completeInspection(inspection);
                infoMessage = 'Inspection completed';
              } catch (error) {
                infoMessage = error.toString();
              }
            });
          },
          child: const Text('Complete Inspection'),
        ),
        ElevatedButton(
          key: const Key('pdf_button'),
          onPressed: () async {
            final pdf = await widget.service.generatePdf(inspection);
            setState(() {
              infoMessage = 'PDF generated at ${pdf.path}';
            });
          },
          child: const Text('Generate PDF'),
        ),
        ElevatedButton(
          key: const Key('email_button'),
          onPressed: () {
            setState(() {
              widget.service.markEmailed(
                inspection,
                confirmed: true,
                recipient: recipientController.text,
                customer: inspection.customer,
              );
              infoMessage = 'Marked as emailed';
            });
          },
          child: const Text('Email PDF'),
        ),
        ElevatedButton(
          key: const Key('duplicate_button'),
          onPressed: () {
            setState(() {
              activeInspection = widget.service.duplicateInspection(inspection);
            });
          },
          child: const Text('Duplicate'),
        ),
        ElevatedButton(
          key: const Key('export_button'),
          onPressed: () async {
            final file = await widget.service.exportInspection(inspection);
            lastExportedBundle = file;
            setState(() {
              infoMessage = 'Exported to ${file.path}';
            });
          },
          child: const Text('Export'),
        ),
        ElevatedButton(
          key: const Key('import_button'),
          onPressed: lastExportedBundle == null
              ? null
              : () async {
                  final imported = await widget.service.importInspection(
                    lastExportedBundle!,
                  );
                  setState(() {
                    activeInspection = imported;
                    infoMessage = 'Imported ${imported.documentNumber}';
                  });
                },
          child: const Text('Import'),
        ),
      ],
    );
  }
}
