import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_shift/application/field_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test(
    'create, correct, undo, save, recover, edit and delete farmer parcel',
    () async {
      final store = MemoryStore();
      final m = FieldController(
        parcels: store,
        documents: store,
        sentinel: EmptyCatalog(),
        landsat: EmptyCatalog(),
        climate: NoClimate(),
        processor: NoProcessor(),
      );
      await m.initialize();
      expect(m.advanced, false);
      m.newParcel();
      m.tap(GeoPoint(0, 0));
      m.tap(GeoPoint(0, .01));
      m.tap(GeoPoint(.01, .01));
      m.chooseVertex(1);
      m.tap(GeoPoint(0, .02));
      expect(m.vertices[1].longitude, .02);
      m.undo();
      expect(m.vertices[1].longitude, .01);
      await m.save(
        'Huerto',
        const FarmRecord(crop: 'Maíz', history: 'Frijol 2024'),
      );
      expect(m.saved.length, 1);
      expect(m.editing, false);
      await m.select(m.saved.single);
      expect(m.selected!.farm.history, 'Frijol 2024');
      m.edit();
      m.chooseVertex(0);
      m.removeVertex();
      expect(m.vertices.length, 2);
      await m.save('Inválido', const FarmRecord());
      expect(m.saved.single.name, 'Huerto');
      m.cancelEdit();
      expect(m.vertices.length, 3);
      await m.deleteSelected();
      expect(await store.listParcels(), isEmpty);
      m.dispose();
    },
  );

  test(
    'offline reopens V1 results and distinguishes usable coverage',
    () async {
      final store = MemoryStore();
      final parcel = pilotParcel();
      await store.saveParcel(parcel);
      await store.writeDocument('preferences-v1', {
        'schema': 1,
        'offline': true,
      });
      await store.writeDocument(
        'result:pilot:good',
        rasterFixture(parcel, id: 'good', pixels: 95),
      );
      await store.writeDocument(
        'result:pilot:limited',
        rasterFixture(
          parcel,
          id: 'limited',
          pixels: 20,
          date: DateTime.utc(2025),
        ),
      );
      await store.writeDocument(
        'result:pilot:bad',
        rasterFixture(
          parcel,
          id: 'bad',
          pixels: 0,
          date: DateTime.utc(2026, 2),
        ),
      );
      await store.writeDocument('power:pilot', {
        'geometry': {
          'type': 'Point',
          'coordinates': parcel.geometry.bounds.center.toJson(),
        },
        'properties': {
          'parameter': {
            'PRECTOTCORR': {'20260101': 1.2, '20260102': -999},
          },
        },
        'parameters': {
          'PRECTOTCORR': {'units': 'mm/day'},
        },
      });
      final m = FieldController(
        parcels: store,
        documents: store,
        sentinel: EmptyCatalog(),
        landsat: EmptyCatalog(),
        climate: NoClimate(),
        processor: NoProcessor(),
      );
      addTearDown(m.dispose);
      await m.initialize();
      expect(m.offline, true);
      expect(m.selected!.id, 'pilot');
      expect(m.results.map((r) => r.quality), [
        RasterQuality.limited,
        RasterQuality.available,
        RasterQuality.unusable,
      ]);
      expect(m.observations.latestUsable!.id, 'good');
      m.openResult(m.results.first);
      expect(m.result!.id, 'limited');
      expect(m.comparable(m.results.last, m.results.first), false);
      expect(m.weather!.value('PRECTOTCORR', '20260102'), isNull);
      expect(m.weather!.unitFor('PRECTOTCORR'), 'mm/day');
    },
  );
  test(
    'offline refuses new scene retrieval and preserves preferences',
    () async {
      final store = MemoryStore();
      final m = FieldController(
        parcels: store,
        documents: store,
        sentinel: EmptyCatalog(),
        landsat: EmptyCatalog(),
        climate: NoClimate(),
        processor: NoProcessor(),
      );
      m.newParcel();
      for (final p in [GeoPoint(0, 0), GeoPoint(0, .01), GeoPoint(.01, .01)]) {
        m.tap(p);
      }
      await m.save('P', const FarmRecord());
      m.offline = true;
      await m.searchScenes();
      expect(m.message, contains('internet'));
      await m.preferences();
      expect((await store.readDocument('preferences-v1'))!['offline'], true);
      m.dispose();
    },
  );
}
