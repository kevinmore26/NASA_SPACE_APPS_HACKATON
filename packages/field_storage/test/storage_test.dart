import 'dart:convert';
import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:field_storage/field_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  test('a V1 SQLite row keeps its geometry, id and agricultural notes after V2', () async {
    final dir = await Directory.systemTemp.createTemp('field_legacy_test_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/legacy.sqlite';
    final v1 = {
      'schema': 1,
      'id': 'legacy',
      'name': 'Parcela El Olivar',
      'geometry': [
        [-79.78, -6.73],
        [-79.77, -6.73],
        [-79.77, -6.72],
      ],
      'farm': {
        'crop': 'Maíz',
        'history': 'Frijol en 2025',
        'soil': 'Franco arenoso',
        'water': 'Canal',
        'irrigation': 'Por turnos',
        'budget': 'Ahorro para semilla',
        'priorities': 'Cuidar el agua',
      },
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };
    sqfliteFfiInit();
    final oldDb = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE parcels (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE documents (key TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
        },
      ),
    );
    await oldDb.insert('parcels', {'id': 'legacy', 'body': jsonEncode(v1)});
    await oldDb.close();
    var store = await LocalStore.open(path);
    final original = (await store.listParcels()).single;
    expect(original.toJson(), v1);
    expect(original.farm.planning, isNull);

    final evolved = original.toJson();
    (evolved['farm'] as Map<String, dynamic>)['planning'] = const FarmPlanning(
      crop: FarmCrop.maize,
      water: FarmWater.secured,
      sowingMonth: 3,
    ).toJson();
    await store.saveParcel(Parcel.fromJson(evolved));
    await store.close();
    store = await LocalStore.open(path);
    final read = (await store.listParcels()).single;
    await store.close();
    expect(read.farm.planning!.crop, FarmCrop.maize);
    expect(read.farm.planning!.sowingMonth, 3);
    expect(read.toJson(), evolved);
  });
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
