import 'package:field_core/field_core.dart';
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
