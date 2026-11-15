import 'dart:convert';
import 'dart:io';

import 'package:field_compute/field_compute.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_maps/field_maps.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:field_storage/field_storage.dart';
import 'package:field_shift/app.dart';
import 'package:field_shift/application/field_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows real: map, parcel, local reopen, real scene and offline result',
    (tester) async {
      const root = String.fromEnvironment('REPO_ROOT');
      expect(root, isNotEmpty);
      final directory = await Directory.systemTemp.createTemp(
        'NASA_Field_Shift_verified_',
      );
      var store = await LocalStore.open('${directory.path}/fields.sqlite');
      final client = http.Client();
      final tiles = CachedTileClient(Directory('${directory.path}/tiles'));
      final processor = LocalRasterProcessor(
        executable: '$root/.venv/Scripts/python.exe',
        arguments: ['$root/packages/field_compute/worker/raster_worker.py'],
        outputDirectory: '${directory.path}/results',
      );
      var m = FieldController(
        parcels: store,
        documents: store,
        sentinel: StacCatalog.sentinel(client),
        landsat: landsatCatalog(client),
        climate: NasaPower(client),
        processor: processor,
      );
      await m.initialize();
      await tester.pumpWidget(
        FieldShiftApp(model: m, tiles: tiles, dataDirectory: directory.path),
      );
      await tester.pumpAndSettle();
      m.goTo(FieldPage.map);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to coordinates'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '-13.718, -76.148');
      await tester.tap(find.text('Center on this location'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mark a field'));
      await tester.tap(find.text('Mark a field'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(FieldMap));
      for (final delta in [
        const Offset(-80, -70),
        const Offset(80, -70),
        const Offset(80, 70),
        const Offset(-80, 70),
      ]) {
        await tester.tapAt(rect.center + delta);
        await tester.pump(const Duration(milliseconds: 450));
      }
      expect(m.vertices.length, 4);
      await tester.ensureVisible(find.text('Save field'));
      await tester.tap(find.text('Save field'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextFormField),
            )
            .first,
        'Verificación Windows — no es terreno del usuario',
      );
      await tester.tap(find.text('Save information'));
      await tester.pumpAndSettle();
      expect(m.selected, isNotNull);
      expect((await store.listParcels()).length, 1);
      final original = m.selected!.toJson();
      await tester.pumpWidget(const SizedBox.shrink());
      m.dispose();
      await store.close();
      store = await LocalStore.open('${directory.path}/fields.sqlite');
      expect((await store.listParcels()).single.toJson(), original);
      m = FieldController(
        parcels: store,
        documents: store,
        sentinel: StacCatalog.sentinel(client),
        landsat: landsatCatalog(client),
        climate: NasaPower(client),
        processor: processor,
      );
      await m.initialize();
      await m.select(m.saved.single);
      await tester.pumpWidget(
        FieldShiftApp(model: m, tiles: tiles, dataDirectory: directory.path),
      );
      await tester.pumpAndSettle();
      m.start = DateTime.utc(2025, 2, 1);
      m.end = DateTime.utc(2025, 3, 1);
      m.maxCloud = 40;
      m.navigate('Análisis');
      await tester.pumpAndSettle();
      await m.searchScenes();
      expect(m.scenes, isNotEmpty);
      await tester.pumpAndSettle();
      await m.analyze(m.scenes.first, Observation.ndvi);
      expect(m.result, isNotNull, reason: m.message);
      expect(m.result!.statistics.validPixels, greaterThan(0));
      await tester.pumpAndSettle();
      final result = m.result!;
      expect(await File(result.imagePath).exists(), true);
      expect(result.resolution, 20);
      expect(m.scenes.length, greaterThan(1));
      await m.analyze(m.scenes[1], Observation.ndvi);
      expect(m.comparable(result, m.result!), true);
      m.comparison = result;
      m.emit();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Switch image on map'));
      await tester.tap(find.text('Switch image on map'));
      await tester.pumpAndSettle();
      expect(m.result!.id, result.id);
      await tiles.flush();
      expect(await tiles.directory.list().length, greaterThan(0));
      await m.loadWeather();
      expect(m.weather, isNotNull, reason: m.message);
      expect(m.weather!.unitFor('PRECTOTCORR'), isNotEmpty);
      m.viewObservations(weather: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Daily records'));
      await tester.tap(find.text('Daily records'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(tester.takeException(), isNull);
      tiles.offline = true;
      m.offline = true;
      m.advanced = true;
      await m.preferences();
      await tester.pumpWidget(const SizedBox.shrink());
      m.dispose();
      await store.close();
      store = await LocalStore.open('${directory.path}/fields.sqlite');
      m = FieldController(
        parcels: store,
        documents: store,
        sentinel: StacCatalog.sentinel(client),
        landsat: landsatCatalog(client),
        climate: NasaPower(client),
        processor: processor,
      );
      await m.initialize();
      await m.select(m.saved.single);
      expect(m.results.length, 2);
      expect(m.offline, true);
      expect(m.weather!.days, isNotEmpty);
      m.result = m.results.first;
      m.navigate('Análisis');
      await tester.pumpWidget(
        FieldShiftApp(model: m, tiles: tiles, dataDirectory: directory.path),
      );
      await tester.pumpAndSettle();
      await m.inspect(m.selected!.geometry.bounds.center);
      expect(m.pixel!.values, isNotNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await File('$root/docs/evidence/windows_integration.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'status': 'PASS',
          'testDirectory': directory.path,
          'parcel': original,
          'scene': result.sceneId,
          'result': result.data,
          'tileFiles': await tiles.directory.list().length,
          'pixel': m.pixel?.toJson(),
          'offline': true,
          'resultsRecovered': m.results.length,
          'temporalComparison': 'same polygon, CRS, transform, source, variable; UI alternate passed',
        }),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      m.dispose();
      tiles.close();
      client.close();
      await store.close();
    },
  );
}
