enum InspectionStatus { draft, inProgress, complete, emailed }

enum SectionCompletionState { notStarted, inProgress, complete, blocked }

enum ConditionRating {
  satisfactory,
  monitorAtRisk,
  unsatisfactory,
  criticalOutOfService,
}

enum InspectionFieldType {
  text,
  multilineText,
  number,
  dropdown,
  yesNoNa,
  conditionRating,
  dateTime,
  photo,
  signature,
  toggle,
}

enum YesNoNa { yes, no, na }

enum FluidLevelOption { high, withinTolerance, low }

enum FluidClarityOption { clear, discolored, milkyOrContaminated, other }

enum FailureType {
  weeping,
  cracking,
  abrasion,
  heatDamage,
  collapse,
  leak,
  wrongHoseType,
  other,
}

enum FilterReplacementStatus { yes, no, na }

enum TemperatureUnit { celsius, fahrenheit }

enum ValidationSeverity { info, warning, error }

enum InspectionSearchScope { all, draft, inProgress, complete, emailed }

extension InspectionStatusX on InspectionStatus {
  String get value {
    switch (this) {
      case InspectionStatus.draft:
        return 'draft';
      case InspectionStatus.inProgress:
        return 'in_progress';
      case InspectionStatus.complete:
        return 'complete';
      case InspectionStatus.emailed:
        return 'emailed';
    }
  }

  String get label {
    switch (this) {
      case InspectionStatus.draft:
        return 'Draft';
      case InspectionStatus.inProgress:
        return 'In Progress';
      case InspectionStatus.complete:
        return 'Complete';
      case InspectionStatus.emailed:
        return 'Emailed';
    }
  }

  static InspectionStatus fromValue(String value) {
    switch (value) {
      case 'draft':
        return InspectionStatus.draft;
      case 'in_progress':
        return InspectionStatus.inProgress;
      case 'complete':
        return InspectionStatus.complete;
      case 'emailed':
        return InspectionStatus.emailed;
      default:
        return InspectionStatus.draft;
    }
  }
}

extension SectionCompletionStateX on SectionCompletionState {
  String get value {
    switch (this) {
      case SectionCompletionState.notStarted:
        return 'not_started';
      case SectionCompletionState.inProgress:
        return 'in_progress';
      case SectionCompletionState.complete:
        return 'complete';
      case SectionCompletionState.blocked:
        return 'blocked';
    }
  }

  String get label {
    switch (this) {
      case SectionCompletionState.notStarted:
        return 'Not started';
      case SectionCompletionState.inProgress:
        return 'In progress';
      case SectionCompletionState.complete:
        return 'Complete';
      case SectionCompletionState.blocked:
        return 'Blocked';
    }
  }

  static SectionCompletionState fromValue(String value) {
    switch (value) {
      case 'not_started':
        return SectionCompletionState.notStarted;
      case 'in_progress':
        return SectionCompletionState.inProgress;
      case 'complete':
        return SectionCompletionState.complete;
      case 'blocked':
        return SectionCompletionState.blocked;
      default:
        return SectionCompletionState.notStarted;
    }
  }
}

extension ConditionRatingX on ConditionRating {
  String get value {
    switch (this) {
      case ConditionRating.satisfactory:
        return 'satisfactory';
      case ConditionRating.monitorAtRisk:
        return 'monitor_at_risk';
      case ConditionRating.unsatisfactory:
        return 'unsatisfactory';
      case ConditionRating.criticalOutOfService:
        return 'critical_out_of_service';
    }
  }

  String get label {
    switch (this) {
      case ConditionRating.satisfactory:
        return 'Satisfactory';
      case ConditionRating.monitorAtRisk:
        return 'Monitor / At Risk';
      case ConditionRating.unsatisfactory:
        return 'Unsatisfactory (Fail)';
      case ConditionRating.criticalOutOfService:
        return 'Critical / Out of Service';
    }
  }

  bool get isFlagged =>
      this == ConditionRating.monitorAtRisk ||
      this == ConditionRating.unsatisfactory ||
      this == ConditionRating.criticalOutOfService;

  bool get requiresLotO => this == ConditionRating.criticalOutOfService;

  static ConditionRating fromValue(String value) {
    switch (value) {
      case 'satisfactory':
        return ConditionRating.satisfactory;
      case 'monitor_at_risk':
        return ConditionRating.monitorAtRisk;
      case 'unsatisfactory':
        return ConditionRating.unsatisfactory;
      case 'critical_out_of_service':
        return ConditionRating.criticalOutOfService;
      default:
        return ConditionRating.satisfactory;
    }
  }
}

extension InspectionFieldTypeX on InspectionFieldType {
  String get value {
    switch (this) {
      case InspectionFieldType.text:
        return 'text';
      case InspectionFieldType.multilineText:
        return 'multiline_text';
      case InspectionFieldType.number:
        return 'number';
      case InspectionFieldType.dropdown:
        return 'dropdown';
      case InspectionFieldType.yesNoNa:
        return 'yes_no_na';
      case InspectionFieldType.conditionRating:
        return 'condition_rating';
      case InspectionFieldType.dateTime:
        return 'date_time';
      case InspectionFieldType.photo:
        return 'photo';
      case InspectionFieldType.signature:
        return 'signature';
      case InspectionFieldType.toggle:
        return 'toggle';
    }
  }

  static InspectionFieldType fromValue(String value) {
    switch (value) {
      case 'text':
        return InspectionFieldType.text;
      case 'multiline_text':
        return InspectionFieldType.multilineText;
      case 'number':
        return InspectionFieldType.number;
      case 'dropdown':
        return InspectionFieldType.dropdown;
      case 'yes_no_na':
        return InspectionFieldType.yesNoNa;
      case 'condition_rating':
        return InspectionFieldType.conditionRating;
      case 'date_time':
        return InspectionFieldType.dateTime;
      case 'photo':
        return InspectionFieldType.photo;
      case 'signature':
        return InspectionFieldType.signature;
      case 'toggle':
        return InspectionFieldType.toggle;
      default:
        return InspectionFieldType.text;
    }
  }
}

extension YesNoNaX on YesNoNa {
  String get value {
    switch (this) {
      case YesNoNa.yes:
        return 'yes';
      case YesNoNa.no:
        return 'no';
      case YesNoNa.na:
        return 'na';
    }
  }

  String get label {
    switch (this) {
      case YesNoNa.yes:
        return 'Yes';
      case YesNoNa.no:
        return 'No';
      case YesNoNa.na:
        return 'N/A';
    }
  }

  static YesNoNa fromValue(String value) {
    switch (value) {
      case 'yes':
        return YesNoNa.yes;
      case 'no':
        return YesNoNa.no;
      case 'na':
        return YesNoNa.na;
      default:
        return YesNoNa.na;
    }
  }
}

extension FluidLevelOptionX on FluidLevelOption {
  String get value {
    switch (this) {
      case FluidLevelOption.high:
        return 'high';
      case FluidLevelOption.withinTolerance:
        return 'within_tolerance';
      case FluidLevelOption.low:
        return 'low';
    }
  }

  String get label {
    switch (this) {
      case FluidLevelOption.high:
        return 'High';
      case FluidLevelOption.withinTolerance:
        return 'Within Tolerance';
      case FluidLevelOption.low:
        return 'Low';
    }
  }

  static FluidLevelOption fromValue(String value) {
    switch (value) {
      case 'high':
        return FluidLevelOption.high;
      case 'within_tolerance':
        return FluidLevelOption.withinTolerance;
      case 'low':
        return FluidLevelOption.low;
      default:
        return FluidLevelOption.withinTolerance;
    }
  }
}

extension FluidClarityOptionX on FluidClarityOption {
  String get value {
    switch (this) {
      case FluidClarityOption.clear:
        return 'clear';
      case FluidClarityOption.discolored:
        return 'discolored';
      case FluidClarityOption.milkyOrContaminated:
        return 'milky_or_contaminated';
      case FluidClarityOption.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case FluidClarityOption.clear:
        return 'Clear';
      case FluidClarityOption.discolored:
        return 'Discolored';
      case FluidClarityOption.milkyOrContaminated:
        return 'Milky or Contaminated';
      case FluidClarityOption.other:
        return 'Other';
    }
  }

  static FluidClarityOption fromValue(String value) {
    switch (value) {
      case 'clear':
        return FluidClarityOption.clear;
      case 'discolored':
        return FluidClarityOption.discolored;
      case 'milky_or_contaminated':
        return FluidClarityOption.milkyOrContaminated;
      case 'other':
        return FluidClarityOption.other;
      default:
        return FluidClarityOption.clear;
    }
  }
}

extension FailureTypeX on FailureType {
  String get value {
    switch (this) {
      case FailureType.weeping:
        return 'weeping';
      case FailureType.cracking:
        return 'cracking';
      case FailureType.abrasion:
        return 'abrasion';
      case FailureType.heatDamage:
        return 'heat_damage';
      case FailureType.collapse:
        return 'collapse';
      case FailureType.leak:
        return 'leak';
      case FailureType.wrongHoseType:
        return 'wrong_hose_type';
      case FailureType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case FailureType.weeping:
        return 'Weeping';
      case FailureType.cracking:
        return 'Cracking';
      case FailureType.abrasion:
        return 'Abrasion';
      case FailureType.heatDamage:
        return 'Heat damage';
      case FailureType.collapse:
        return 'Collapse';
      case FailureType.leak:
        return 'Leak';
      case FailureType.wrongHoseType:
        return 'Wrong hose type';
      case FailureType.other:
        return 'Other';
    }
  }

  bool get isFailure => this != FailureType.other;

  static FailureType fromValue(String value) {
    switch (value) {
      case 'weeping':
        return FailureType.weeping;
      case 'cracking':
        return FailureType.cracking;
      case 'abrasion':
        return FailureType.abrasion;
      case 'heat_damage':
        return FailureType.heatDamage;
      case 'collapse':
        return FailureType.collapse;
      case 'leak':
        return FailureType.leak;
      case 'wrong_hose_type':
        return FailureType.wrongHoseType;
      case 'other':
        return FailureType.other;
      default:
        return FailureType.other;
    }
  }
}

extension FilterReplacementStatusX on FilterReplacementStatus {
  String get value {
    switch (this) {
      case FilterReplacementStatus.yes:
        return 'yes';
      case FilterReplacementStatus.no:
        return 'no';
      case FilterReplacementStatus.na:
        return 'na';
    }
  }

  String get label {
    switch (this) {
      case FilterReplacementStatus.yes:
        return 'Yes';
      case FilterReplacementStatus.no:
        return 'No';
      case FilterReplacementStatus.na:
        return 'N/A';
    }
  }

  static FilterReplacementStatus fromValue(String value) {
    switch (value) {
      case 'yes':
        return FilterReplacementStatus.yes;
      case 'no':
        return FilterReplacementStatus.no;
      case 'na':
        return FilterReplacementStatus.na;
      default:
        return FilterReplacementStatus.na;
    }
  }
}

extension TemperatureUnitX on TemperatureUnit {
  String get value {
    switch (this) {
      case TemperatureUnit.celsius:
        return 'celsius';
      case TemperatureUnit.fahrenheit:
        return 'fahrenheit';
    }
  }

  String get symbol {
    switch (this) {
      case TemperatureUnit.celsius:
        return '°C';
      case TemperatureUnit.fahrenheit:
        return '°F';
    }
  }

  static TemperatureUnit fromValue(String value) {
    switch (value) {
      case 'celsius':
        return TemperatureUnit.celsius;
      case 'fahrenheit':
        return TemperatureUnit.fahrenheit;
      default:
        return TemperatureUnit.celsius;
    }
  }
}
