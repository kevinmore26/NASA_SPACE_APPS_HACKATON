import 'package:field_core/field_core.dart';
import 'package:field_shift/application/field_language.dart';
import 'package:field_maps/field_maps.dart';
import 'package:field_shift/app.dart';
import 'package:field_shift/application/field_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support.dart';

FieldController controller(MemoryStore store) => FieldController(
  parcels: store,
  documents: store,
  sentinel: EmptyCatalog(),
  landsat: EmptyCatalog(),
  climate: NoClimate(),
  processor: NoProcessor(),
)..base = 'none';

void resize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Future<void> open(WidgetTester tester, FieldController model) async {
  final client = MockClient(
    (_) async => http.Response('Unexpected network request', 500),
  );
  addTearDown(client.close);
  addTearDown(model.dispose);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    FieldShiftApp(model: model, tiles: client, dataDirectory: 'QA local'),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draw, save and navigate through a compact window', (
    tester,
  ) async {
    resize(tester, const Size(1600, 900));
    final store = MemoryStore();
    final m = controller(store);
    await open(tester, m);
    expect(find.text('NASA Field Shift'), findsOneWidget);
    expect(find.byType(FieldMap), findsNothing);
    await press(tester, 'Add field');
    final map = tester.getRect(find.byType(FieldMap));
    for (final d in [
      const Offset(-70, -65),
      const Offset(70, -65),
      const Offset(70, 65),
    ]) {
      await tester.tapAt(map.center + d);
      await tester.pump(const Duration(milliseconds: 420));
    }
    expect(m.vertices.length, 3);
    await press(tester, 'Save field');
    await tester.enterText(
      find.byType(TextFormField).first,
      'Huerto de prueba',
    );
    await press(tester, 'Other notes (optional)');
    final note = find.widgetWithText(TextFormField, 'Past crops');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Maíz 2025');
    expect(tester.takeException(), isNull);
    await press(tester, 'Save information');
    expect(store.parcels.values.single.name, 'Huerto de prueba');
    expect(store.parcels.values.single.farm.history, 'Maíz 2025');
    final mapState = tester.state(find.byType(FieldMap));

    resize(tester, const Size(400, 620));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(FieldMap)), same(mapState));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DrawerButton), findsNothing);
    await tester.tap(find.byKey(const ValueKey('more-navigation')));
    await tester.pumpAndSettle();
    await press(tester, 'Settings');
    expect(find.text('Work offline'), findsOneWidget);
    expect(find.byType(FieldMap), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('views fit sample desktop sizes and keep the same map state', (
    tester,
  ) async {
    resize(tester, const Size(1600, 900));
    final store = MemoryStore();
    final parcel = pilotParcel();
    await store.saveParcel(parcel);
    await store.writeDocument(
      'result:${parcel.id}:cloud',
      rasterFixture(parcel, id: 'cloud', pixels: 0),
    );
    final m = controller(store);
    await m.initialize();
    await open(tester, m);
    await press(tester, 'Map');
    final mapState = tester.state(find.byType(FieldMap));
    expect(find.text('Map layers'), findsOneWidget);

    for (final size in [
      const Size(1600, 900),
      const Size(1366, 768),
      const Size(1024, 768),
      const Size(720, 620),
      const Size(400, 640),
      const Size(360, 540),
    ]) {
      resize(tester, size);
      for (final page in FieldPage.values) {
        m.goTo(page);
        if (page == FieldPage.analysis) m.openResult(m.results.single);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$page, $size');
        if (page == FieldPage.map || page == FieldPage.analysis) {
          expect(tester.state(find.byType(FieldMap)), same(mapState));
        } else {
          expect(find.byType(FieldMap), findsNothing);
        }
      }
    }
    m.goTo(FieldPage.analysis);
    await tester.pumpAndSettle();
    expect(find.text('No usable image data'), findsWidgets);
    expect(find.textContaining('Mean:'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('save structured agriculture inputs and compare offline', (
    tester,
  ) async {
    resize(tester, const Size(1366, 768));
    final store = MemoryStore();
    final parcel = pilotParcel(
      farm: const FarmRecord(crop: 'Maíz para grano', history: 'Maíz 2025'),
    );
    await store.saveParcel(parcel);
    final m = controller(store);
    await m.initialize();
    await m.setLanguage(FieldLanguage.spanish);
    m.offline = true;
    m.goTo(FieldPage.rotations);
    await open(tester, m);

    Future<void> choose(String label, String option) async {
      final field = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await press(tester, option);
    }

    await choose('Tipo de cultivo actual', 'Maíz amarillo duro');
    await choose(
      'Zona y altitud de la parcela',
      'Costa de Lambayeque (0–500 m)',
    );
    await choose('Mes disponible para sembrar', 'marzo');
    await choose('Textura del suelo', 'Franco arenoso');
    await choose('Drenaje del suelo', 'Drena bien');
    final conductivity = find.widgetWithText(
      TextFormField,
      'Conductividad del suelo (dS/m)',
    );
    await tester.ensureVisible(conductivity);
    await tester.enterText(conductivity, '1,5');
    await choose('Agua disponible', 'Confirmada para la próxima campaña');
    await choose('Sistema de riego', 'Goteo');
    await choose('Qué quieres priorizar', 'Cuidar el agua');
    await press(tester, 'Guardar y comparar');

    expect(find.text('Tu plan actual'), findsOneWidget);
    expect(find.text('Frijol caupí INIA 432'), findsOneWidget);
    expect(find.text('Frijol blanco mediano'), findsOneWidget);
    expect(find.text('Modo sin conexión'), findsOneWidget);
    expect(find.textContaining('Tu prioridad: Cuidar el agua'), findsOneWidget);
    final persisted = store.parcels[parcel.id]!;
    expect(persisted.farm.history, 'Maíz 2025');
    expect(persisted.farm.crop, 'Maíz para grano');
    expect(persisted.farm.planning!.soilConductivity, 1.5);
    expect(persisted.farm.planning!.region, FarmRegion.lambayequeCoast);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'English defaults, Spanish stays selected and the map survives the switch',
    (tester) async {
      resize(tester, const Size(1024, 768));
      tester.platformDispatcher.localeTestValue = const Locale('es', 'PE');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final store = MemoryStore();
      final m = controller(store);
      await m.initialize();
      await open(tester, m);
      expect(find.text('Add field'), findsOneWidget);
      await press(tester, 'Map');
      final map = tester.state(find.byType(FieldMap));
      await tester.tap(find.byKey(const ValueKey('language-menu')));
      await tester.pumpAndSettle();
      await press(tester, 'Español');
      expect(find.text('Mapa del terreno'), findsOneWidget);
      expect(tester.state(find.byType(FieldMap)), same(map));
      expect(store.docs['preferences-v1']!['language'], 'es');
      final reopened = controller(store);
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.language.value, FieldLanguage.spanish);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('open February in a different year without paging a calendar', (
    tester,
  ) async {
    resize(tester, const Size(1024, 768));
    final store = MemoryStore();
    await store.saveParcel(pilotParcel());
    final m = controller(store);
    await m.initialize();
    m.viewObservations();
    await open(tester, m);
    await tester.tap(find.byKey(const ValueKey('analysis-period')));
    await tester.pumpAndSettle();
    final year = find.byType(DropdownButtonFormField<int>);
    await tester.tap(year);
    await tester.pumpAndSettle();
    await press(tester, '2024');
    await press(tester, 'February');
    await press(tester, 'Use period');
    expect(find.text('February 2024'), findsOneWidget);
    expect(m.start, DateTime(2024, 2, 1));
    expect(m.end, DateTime(2024, 2, 29));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'open weather rows, scientific details, and rule sources across sizes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      resize(tester, const Size(1015, 760));
      final store = MemoryStore();
      final parcel = pilotParcel();
      await store.saveParcel(parcel);
      await store.writeDocument('result:pilot:legacy', {
        ...rasterFixture(parcel, id: 'legacy', pixels: 91),
        'provider': 'ESA/Copernicus Â· Earth Search',
      });
      await store.writeDocument('power:pilot', {
        'geometry': {'coordinates': parcel.geometry.bounds.center.toJson()},
        'parameters': {
          'PRECTOTCORR': {'units': 'mm/day'},
          'T2M': {'units': 'C'},
        },
        'properties': {
          'parameter': {
            'PRECTOTCORR': {
              for (var i = 1; i <= 28; i++)
                '202602${i.toString().padLeft(2, '0')}': i == 28 ? true : 2.5,
            },
            'T2M': {'20260227': 22.2},
          },
        },
      });
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final m = controller(store);
      await m.initialize();
      m.viewObservations(weather: true);
      await open(tester, m);
      await press(tester, 'Daily records');
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('No data'), findsWidgets);
      await tester.ensureVisible(find.byTooltip('Earlier days'));
      await tester.tap(find.byTooltip('Earlier days'));
      await tester.pumpAndSettle();
      expect(find.text('Feb 14, 2026'), findsOneWidget);
      resize(tester, const Size(450, 700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      m.viewObservations();
      m.openResult(m.results.single);
      await tester.pumpAndSettle();
      await press(tester, 'Data and method');
      await press(tester, 'Copy details');
      expect(copied, contains('ESA/Copernicus · Earth Search'));
      expect(copied, isNot(contains('Â')));
      await press(tester, 'Data and method');
      await press(tester, 'Data and method');
      expect(tester.takeException(), isNull);

      m.goTo(FieldPage.rotations);
      await tester.pumpAndSettle();
      await press(tester, 'Rule sources');
      final links = find.text('Copy link');
      await tester.ensureVisible(links.first);
      await tester.tap(links.first);
      await tester.pumpAndSettle();
      expect(copied, startsWith('https://www.senasa.gob.pe/'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'coordinates open, center the map and reopen across responsive layouts',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      resize(tester, const Size(1267, 700));
      final store = MemoryStore();
      final original = pilotParcel();
      await store.saveParcel(original);
      final model = controller(store);
      await model.initialize();
      model.goTo(FieldPage.map);
      await open(tester, model);
      final mapState = tester.state(find.byType(FieldMap));

      for (final size in [
        const Size(1267, 700),
        const Size(420, 720),
        const Size(1024, 760),
      ]) {
        resize(tester, size);
        await tester.pumpAndSettle();
        await press(tester, 'Go to coordinates');
        expect(tester.takeException(), isNull);
        final field = find.byType(TextField);
        await tester.ensureVisible(field);
        await tester.enterText(field, '-6.724, -79.777');
        await press(tester, 'Center on this location');
        expect(model.message, 'Map centered.');
        expect(find.textContaining('-6.72400, -79.77700'), findsOneWidget);
        expect(model.vertices, original.geometry.vertices);
        expect(tester.state(find.byType(FieldMap)), same(mapState));
        await press(tester, 'Go to coordinates');
        model.goTo(FieldPage.analysis);
        await tester.pumpAndSettle();
        model.goTo(FieldPage.map);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('compact navigation makes all six sections reachable', (
    tester,
  ) async {
    resize(tester, const Size(320, 650));
    final store = MemoryStore();
    await store.saveParcel(pilotParcel());
    final model = controller(store);
    await model.initialize();
    await open(tester, model);

    for (final page in [
      FieldPage.parcels,
      FieldPage.map,
      FieldPage.rotations,
      FieldPage.home,
    ]) {
      await tester.tap(find.byKey(ValueKey(page)));
      await tester.pumpAndSettle();
      expect(model.page, page);
      expect(tester.takeException(), isNull);
    }
    for (final (page, label) in [
      (FieldPage.analysis, 'Observations'),
      (FieldPage.settings, 'Settings'),
    ]) {
      await tester.tap(find.byKey(const ValueKey('more-navigation')));
      await tester.pumpAndSettle();
      await press(tester, label);
      expect(model.page, page);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
