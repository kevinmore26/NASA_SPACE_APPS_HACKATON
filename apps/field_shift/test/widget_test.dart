import 'dart:convert';

import 'package:field_shift/app.dart';
import 'package:field_shift/application/field_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support.dart';

void main() {
  testWidgets('farmer navigation, drawing and narrow layout do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    final m = FieldController(
      parcels: store,
      documents: store,
      sentinel: EmptyCatalog(),
      landsat: EmptyCatalog(),
      climate: NoClimate(),
      processor: NoProcessor(),
    );
    m.base = 'none';
    final client = MockClient(
      (_) async => http.Response.bytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aH9sAAAAASUVORK5CYII=',
        ),
        200,
      ),
    );
    await tester.pumpWidget(
      FieldShiftApp(model: m, tiles: client, dataDirectory: 'test-only'),
    );
    await tester.pumpAndSettle();
    expect(find.text('NASA Field Shift'), findsOneWidget);
    expect(find.text('Tu terreno, más claro'), findsOneWidget);
    await tester.tap(find.text('2. Marcar mi terreno'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(600, 260));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(800, 260));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(800, 450));
    await tester.pump(const Duration(milliseconds: 400));
    expect(m.vertices.length, 3);
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    expect(find.text('Modo avanzado'), findsOneWidget);
    tester.view.physicalSize = const Size(720, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    m.dispose();
    client.close();
  });
}
