import 'package:flutter_test/flutter_test.dart';

import 'package:cts_fluid_power_inspection_app/core/workspace_controller.dart';

void main() {
  test('document numbers increment and search filters records', () {
    final controller = AppWorkspaceController();

    final created = controller.createInspection();
    expect(created.documentNumber, matches(RegExp(r'^\d{8}-\d{4}$')));

    final duplicate = controller.duplicateInspection(
      controller.inspections.first,
    );
    expect(duplicate.documentNumber, isNot(equals(created.documentNumber)));
    expect(duplicate.sections.length, 8);

    controller.setSearchQuery('North Basin');
    expect(controller.filteredInspections.length, 1);
    expect(
      controller.filteredInspections.first.customer,
      'North Basin Processing',
    );
  });
}
