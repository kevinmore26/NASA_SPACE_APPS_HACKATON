import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:field_storage/field_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('SQLite reopen, update, delete and versioned documents', () async {
    final dir = await Directory.systemTemp.createTemp('field_store_test_');
    final path = '${dir.path}/test.sqlite';
    var store = await LocalStore.open(path);
    final parcel = Parcel(
      id: 'one',
      name: 'Prueba',
      geometry: FieldGeometry([
        GeoPoint(0, 0),
        GeoPoint(0, .01),
        GeoPoint(.01, .01),
      ]),
      farm: const FarmRecord(crop: 'Maíz'),
      updatedAt: DateTime.utc(2026),
    );
    await store.saveParcel(parcel);
    await store.writeDocument('preferences-v1', {'schema': 1, 'offline': true});
    await store.writeDocument('result:one:a', {'schema': 1, 'value': 0.25});
    await store.close();
    store = await LocalStore.open(path);
    expect((await store.listParcels()).single.toJson(), parcel.toJson());
    expect((await store.readDocument('preferences-v1'))!['offline'], true);
    expect((await store.listDocuments('result:one:')).length, 1);
    await store.deleteParcel('one');
    expect(await store.listParcels(), isEmpty);
    await store.close();
    await dir.delete(recursive: true);
  });
  test('tile cache deduplicates, enforces budget and works offline', () async {
    final dir = await Directory.systemTemp.createTemp('field_tile_test_');
    var calls = 0;
    final cache = CachedTileClient(
      dir,
      maxBytes: 16,
      network: MockClient((r) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response.bytes(List.filled(12, 1), 200);
      }),
    );
    await Future.wait([
      cache.get(Uri.parse('https://example.test/1')),
      cache.get(Uri.parse('https://example.test/1')),
    ]);
    expect(calls, 1);
    await cache.flush();
    cache.offline = true;
    expect(
      (await cache.get(Uri.parse('https://example.test/1'))).bodyBytes.length,
      12,
    );
    await expectLater(
      cache.get(Uri.parse('https://example.test/missing')),
      throwsA(isA<SocketException>()),
    );
    cache.offline = false;
    await cache.get(Uri.parse('https://example.test/2'));
    await cache.flush();
    expect(await dir.list().length, 1);
    cache.close();
    await dir.delete(recursive: true);
  });
}
