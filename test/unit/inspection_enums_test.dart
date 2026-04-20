import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspection status labels and parsing are stable', () {
    expect(InspectionStatus.draft.label, 'Draft');
    expect(InspectionStatus.inProgress.label, 'In Progress');
    expect(InspectionStatus.complete.label, 'Complete');
    expect(InspectionStatus.emailed.label, 'Emailed');

    expect(InspectionStatusX.fromValue('draft'), InspectionStatus.draft);
    expect(
      InspectionStatusX.fromValue('in_progress'),
      InspectionStatus.inProgress,
    );
    expect(InspectionStatusX.fromValue('complete'), InspectionStatus.complete);
    expect(InspectionStatusX.fromValue('emailed'), InspectionStatus.emailed);
  });

  test('condition ratings expose the expected labels and flag behavior', () {
    expect(ConditionRating.satisfactory.label, 'Satisfactory');
    expect(ConditionRating.monitorAtRisk.label, 'Monitor / At Risk');
    expect(ConditionRating.unsatisfactory.label, 'Unsatisfactory (Fail)');
    expect(
      ConditionRating.criticalOutOfService.label,
      'Critical / Out of Service',
    );

    expect(ConditionRating.satisfactory.isFlagged, isFalse);
    expect(ConditionRating.monitorAtRisk.isFlagged, isTrue);
    expect(ConditionRating.unsatisfactory.isFlagged, isTrue);
    expect(ConditionRating.criticalOutOfService.isFlagged, isTrue);
    expect(ConditionRating.criticalOutOfService.requiresLotO, isTrue);

    expect(
      ConditionRatingX.fromValue('satisfactory'),
      ConditionRating.satisfactory,
    );
    expect(
      ConditionRatingX.fromValue('monitor_at_risk'),
      ConditionRating.monitorAtRisk,
    );
    expect(
      ConditionRatingX.fromValue('unsatisfactory'),
      ConditionRating.unsatisfactory,
    );
    expect(
      ConditionRatingX.fromValue('critical_out_of_service'),
      ConditionRating.criticalOutOfService,
    );
  });

  test('field and option enums keep their string contract', () {
    expect(YesNoNa.yes.label, 'Yes');
    expect(YesNoNa.no.label, 'No');
    expect(YesNoNa.na.label, 'N/A');
    expect(YesNoNaX.fromValue('yes'), YesNoNa.yes);
    expect(YesNoNaX.fromValue('no'), YesNoNa.no);
    expect(YesNoNaX.fromValue('na'), YesNoNa.na);

    expect(FluidLevelOption.high.label, 'High');
    expect(FluidLevelOption.withinTolerance.label, 'Within Tolerance');
    expect(FluidLevelOption.low.label, 'Low');

    expect(FluidClarityOption.clear.label, 'Clear');
    expect(FluidClarityOption.discolored.label, 'Discolored');
    expect(
      FluidClarityOption.milkyOrContaminated.label,
      'Milky or Contaminated',
    );
    expect(FluidClarityOption.other.label, 'Other');

    expect(TemperatureUnit.celsius.symbol, '°C');
    expect(TemperatureUnit.fahrenheit.symbol, '°F');

    expect(FailureType.weeping.label, 'Weeping');
    expect(FailureType.leak.isFailure, isTrue);
    expect(FailureType.other.isFailure, isFalse);

    expect(FilterReplacementStatus.yes.label, 'Yes');
    expect(FilterReplacementStatus.no.label, 'No');
    expect(FilterReplacementStatus.na.label, 'N/A');
  });

  test('inspection field types remain serializable', () {
    expect(InspectionFieldTypeX.fromValue('text'), InspectionFieldType.text);
    expect(
      InspectionFieldTypeX.fromValue('multiline_text'),
      InspectionFieldType.multilineText,
    );
    expect(
      InspectionFieldTypeX.fromValue('number'),
      InspectionFieldType.number,
    );
    expect(
      InspectionFieldTypeX.fromValue('dropdown'),
      InspectionFieldType.dropdown,
    );
    expect(
      InspectionFieldTypeX.fromValue('yes_no_na'),
      InspectionFieldType.yesNoNa,
    );
    expect(
      InspectionFieldTypeX.fromValue('condition_rating'),
      InspectionFieldType.conditionRating,
    );
    expect(
      InspectionFieldTypeX.fromValue('date_time'),
      InspectionFieldType.dateTime,
    );
    expect(InspectionFieldTypeX.fromValue('photo'), InspectionFieldType.photo);
    expect(
      InspectionFieldTypeX.fromValue('signature'),
      InspectionFieldType.signature,
    );
    expect(
      InspectionFieldTypeX.fromValue('toggle'),
      InspectionFieldType.toggle,
    );
  });
}
