import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite adapter v1. App supplies a per-user application-support path.
class LocalStore implements ParcelRepository, LocalDocuments {
  final Database _db;
  LocalStore._(this._db);
  static Future<LocalStore> open(String path) async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await db.execute(
            'CREATE TABLE parcels (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE documents (key TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    return LocalStore._(db);
  }

  @override
  Future<List<Parcel>> listParcels() async =>
      (await _db.query('parcels', orderBy: 'id'))
          .map(
            (r) => Parcel.fromJson(
              jsonDecode(r['body'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
  @override
  Future<void> saveParcel(Parcel p) async {
    await _db.insert('parcels', {
      'id': p.id,
      'body': jsonEncode(p.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteParcel(String id) async {
    await _db.delete('parcels', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Map<String, dynamic>?> readDocument(String key) async {
    final rows = await _db.query(
      'documents',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['body'] as String) as Map<String, dynamic>;
  }

  @override
  Future<void> writeDocument(String key, Map<String, dynamic> value) async {
    await _db.insert('documents', {
      'key': key,
      'body': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(String prefix) async =>
      (await _db.query(
            'documents',
            where: 'substr(key,1,?) = ?',
            whereArgs: [prefix.length, prefix],
          ))
          .map((r) => jsonDecode(r['body'] as String) as Map<String, dynamic>)
          .toList();
  Future<void> close() => _db.close();
}
