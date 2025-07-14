import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_mobile/widgets/unit_grid/unit_tile.dart';
import 'package:hub_mobile/models/unit.dart';
import 'package:hub_mobile/models/defect.dart';

void main() {
  testWidgets('UnitTile background color matches defect status color', (tester) async {
    final unit = Unit(
      id: 1,
      name: '1',
      locked: false,
      defects: [Defect(id: 1, description: '', projectId: 1, statusId: 2)],
    );

    final statusColors = {2: '#f59e0b'};

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: UnitTile(unit: unit, onTap: () {}, statusColors: statusColors),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFF59E0B));
  });
}
