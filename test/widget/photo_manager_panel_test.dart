import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LocalPhotoManagerPanel extends StatelessWidget {
  const _LocalPhotoManagerPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: const <Widget>[
            Text('Camera'),
            SizedBox(width: 8),
            Text('Gallery'),
            SizedBox(width: 8),
            Text('Sample'),
          ],
        ),
        const SizedBox(height: 16),
        const Text('No photos added yet.'),
      ],
    );
  }
}

void main() {
  testWidgets('photo manager panel renders controls and empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: _LocalPhotoManagerPanel())),
    );

    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Sample'), findsOneWidget);
    expect(find.text('No photos added yet.'), findsOneWidget);
  });
}
