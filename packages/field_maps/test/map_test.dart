import 'package:field_core/field_core.dart';
import 'package:field_maps/field_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'renderer accepts domain coordinates and exposes edits and zoom',
    (tester) async {
      final c = FieldMapController();
      final points = <GeoPoint>[];
      int? selected;
      final client = MockClient((_) async => http.Response('', 404));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FieldMap(
              controller: c,
              tileClient: client,
              vertices: [GeoPoint(-13.718, -76.148)],
              editing: true,
              onTap: points.add,
              onVertex: (i) => selected = i,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(250, 200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(points.length, 1);
      expect(points.first.latitude, isNot(-13.718));
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(selected, 0);
      await tester.tap(find.byTooltip('Acercar mapa'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      client.close();
    },
  );
}
