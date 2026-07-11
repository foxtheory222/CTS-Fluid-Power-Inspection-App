import 'package:cts_fluid_power_inspection_app/core/workspace_models.dart';
import 'package:cts_fluid_power_inspection_app/widgets/photo_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty photo grid does not show a dead add-photo button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PhotoGrid(photos: [])),
      ),
    );

    expect(find.text('No photos added yet.'), findsOneWidget);
    expect(find.text('Add first photo'), findsNothing);
  });

  testWidgets('populated photo grid does not append a dead add-photo tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PhotoGrid(photos: [_photoView()])),
      ),
    );

    expect(find.text('Pump overview'), findsOneWidget);
    expect(find.text('Add photo'), findsNothing);
  });

  testWidgets('empty photo grid renders a working add-photo action', (
    tester,
  ) async {
    var addCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoGrid(photos: const [], onAddPhoto: () => addCount++),
        ),
      ),
    );

    expect(find.text('No photos added yet.'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);

    await tester.tap(find.text('Add photo'));

    expect(addCount, 1);
  });

  testWidgets('populated photo grid renders a working add-photo tile', (
    tester,
  ) async {
    var addCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoGrid(photos: [_photoView()], onAddPhoto: () => addCount++),
        ),
      ),
    );

    expect(find.text('Pump overview'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);

    await tester.tap(find.text('Add photo'));

    expect(addCount, 1);
  });
}

InspectionPhotoView _photoView() {
  return InspectionPhotoView(
    assetPath: '/tmp/missing-photo-grid-test.jpg',
    caption: 'Pump overview',
    sectionTitle: 'Job & Asset Identification',
    itemLabel: 'HPU wide shot',
    capturedAt: DateTime.utc(2026, 4, 20, 12),
  );
}
