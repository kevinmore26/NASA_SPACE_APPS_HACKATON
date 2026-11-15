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

Parcel pilotParcel({
  FarmRecord farm = const FarmRecord(
    crop: 'Maíz',
    planning: FarmPlanning(
      crop: FarmCrop.maize,
      region: FarmRegion.lambayequeCoast,
      sowingMonth: 3,
      texture: SoilTexture.sandyLoam,
      drainage: SoilDrainage.good,
      soilConductivity: 1.5,
      water: FarmWater.secured,
      irrigation: IrrigationMethod.drip,
    ),
  ),
}) => Parcel(
  id: 'pilot',
  name: 'Parcela de prueba',
  geometry: FieldGeometry([
    GeoPoint(-6.725, -79.779),
    GeoPoint(-6.725, -79.776),
    GeoPoint(-6.723, -79.776),
    GeoPoint(-6.723, -79.779),
  ]),
  farm: farm,
  updatedAt: DateTime.utc(2026, 11, 14),
);

Map<String, dynamic> rasterFixture(
  Parcel parcel, {
  required String id,
  required int pixels,
  DateTime? date,
}) => {
  'schema': 1,
  'id': id,
  'sceneId': 'fixture',
  'parcelId': parcel.id,
  'parcelFingerprint': 'fixture-polygon',
  'observation': 'ndvi',
  'provider': 'ESA/Copernicus',
  'collection': 'sentinel-2-l2a',
  'acquired': (date ?? DateTime.utc(2026, 1, 1)).toIso8601String(),
  'resolution': 20,
  'geometry': parcel.geometry.toGeoJson(),
  'bounds': parcel.geometry.bounds.toJson(),
  'statistics': {
    'validPixels': pixels,
    'totalPixels': 100,
    'cloudPixels': 100 - pixels,
    'shadowPixels': 0,
    'missingPixels': 0,
    'validPercent': pixels,
    'mean': pixels == 0 ? null : 0.2,
  },
};
