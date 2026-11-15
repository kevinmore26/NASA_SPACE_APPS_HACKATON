import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_nasa/field_nasa.dart';

class MemoryStore implements ParcelRepository, LocalDocuments {
  final Map<String, Parcel> parcels = {};
  final Map<String, Map<String, dynamic>> docs = {};
  @override
  Future<List<Parcel>> listParcels() async => parcels.values.toList();
  @override
  Future<void> saveParcel(Parcel p) async {
    parcels[p.id] = p;
  }

  @override
  Future<void> deleteParcel(String id) async {
    parcels.remove(id);
  }

  @override
  Future<Map<String, dynamic>?> readDocument(String key) async => docs[key];
  @override
  Future<void> writeDocument(String key, Map<String, dynamic> value) async {
    docs[key] = value;
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(String prefix) async => docs
      .entries
      .where((e) => e.key.startsWith(prefix))
      .map((e) => e.value)
      .toList();
}

class EmptyCatalog implements SceneCatalog {
  @override
  Future<List<Scene>> search({
    required GeoBounds bounds,
    required DateTime start,
    required DateTime end,
    double maxCloud = 80,
  }) async => [];
}

class NoProcessor implements RasterProcessor {
  @override
  void cancel() {}
  @override
  Future<RasterResult> process({
    required Scene scene,
    required Parcel parcel,
    required Observation observation,
  }) async => throw StateError('Test: no real processor');
  @override
  Future<PixelSample> sample(RasterResult result, GeoPoint point) async =>
      const PixelSample();
}

class NoClimate implements ClimateProvider {
  @override
  Future<ClimateSeries> daily(
    GeoPoint point,
    DateTime start,
    DateTime end,
  ) async => throw StateError('Test: no climate');
}
