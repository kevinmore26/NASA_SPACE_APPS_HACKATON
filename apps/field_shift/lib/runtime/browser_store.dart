import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:field_core/field_core.dart';
import 'package:web/web.dart' as web;

class BrowserStore implements ParcelRepository, LocalDocuments {
  static const _parcels = 'parcels';
  static const _documents = 'documents';

  BrowserStore._(this._database);

  final web.IDBDatabase _database;

  static Future<BrowserStore> open() {
    final ready = Completer<BrowserStore>();
    final request = web.window.indexedDB.open('nasa-field-shift', 1);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      database.createObjectStore(_parcels);
      database.createObjectStore(_documents);
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      database.onversionchange = ((web.Event _) => database.close()).toJS;
      ready.complete(BrowserStore._(database));
    }).toJS;
    request.onerror = ((web.Event _) {
      ready.completeError(StateError('Could not open browser storage.'));
    }).toJS;
    return ready.future;
  }

  Future<JSAny?> _request(
    String collection,
    String mode,
    web.IDBRequest Function(web.IDBObjectStore) run,
  ) {
    final tx = _database.transaction(collection.toJS, mode);
    final request = run(tx.objectStore(collection));
    final done = Completer<JSAny?>();
    tx.oncomplete = ((web.Event _) => done.complete(request.result)).toJS;
    tx.onabort = ((web.Event _) {
      done.completeError(
        StateError(tx.error?.message ?? 'Could not access browser storage.'),
      );
    }).toJS;
    return done.future;
  }

  Map<String, dynamic> _decode(JSAny? value) =>
      jsonDecode((value as JSString).toDart) as Map<String, dynamic>;

  List<Map<String, dynamic>> _decodeList(JSAny? value) =>
      (value as JSArray<JSString>).toDart.map(_decode).toList();

  @override
  Future<List<Parcel>> listParcels() async => _decodeList(
    await _request(_parcels, 'readonly', (store) => store.getAll()),
  ).map(Parcel.fromJson).toList();

  @override
  Future<void> saveParcel(Parcel parcel) async {
    await _request(
      _parcels,
      'readwrite',
      (store) => store.put(jsonEncode(parcel.toJson()).toJS, parcel.id.toJS),
    );
  }

  @override
  Future<void> deleteParcel(String id) async {
    await _request(_parcels, 'readwrite', (store) => store.delete(id.toJS));
  }

  @override
  Future<Map<String, dynamic>?> readDocument(String key) async {
    final value = await _request(
      _documents,
      'readonly',
      (store) => store.get(key.toJS),
    );
    return value == null ? null : _decode(value);
  }

  @override
  Future<void> writeDocument(String key, Map<String, dynamic> value) async {
    await _request(
      _documents,
      'readwrite',
      (store) => store.put(jsonEncode(value).toJS, key.toJS),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(String prefix) async {
    final range = web.IDBKeyRange.bound(prefix.toJS, '$prefix\uffff'.toJS);
    return _decodeList(
      await _request(_documents, 'readonly', (store) => store.getAll(range)),
    );
  }
}
