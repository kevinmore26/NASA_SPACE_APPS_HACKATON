import 'package:field_core/field_core.dart';

enum Observation { rgb, falseColor, swir, red, ndvi, ndmi, temperature }

enum RasterQuality {
  available('Disponible'),
  limited('Limitado'),
  unusable('Sin datos utilizables');

  const RasterQuality(this.label);
  final String label;
}

extension ObservationLabel on Observation {
  String get label => switch (this) {
    Observation.rgb => 'Foto del terreno',
    Observation.falseColor => 'Vegetación en infrarrojo',
    Observation.swir => 'Composición de onda corta',
    Observation.red => 'Banda roja',
    Observation.ndvi => 'Estado de la vegetación',
    Observation.ndmi => 'Agua en la vegetación',
    Observation.temperature => 'Calor de la superficie',
  };
  String get formula => switch (this) {
    Observation.ndvi => '(NIR − rojo) / (NIR + rojo)',
    Observation.ndmi => '(NIR − SWIR1) / (NIR + SWIR1)',
    Observation.temperature => 'DN × escala + offset − 273.15',
    _ => 'Reflectancia superficial; visualización con escala fija 0–0.3',
  };
  String get caveat => switch (this) {
    Observation.ndvi =>
      'No identifica enfermedades, nutrientes ni necesidad de riego.',
    Observation.ndmi =>
      'No mide humedad volumétrica del suelo ni indica cuánto regar.',
    Observation.temperature => 'Temperatura de superficie, no temperatura del aire. Resolución térmica nativa más gruesa.',
    _ => 'Los colores son una visualización, no un diagnóstico agrícola.',
  };
}

class Scene {
  final String id, collection, provider;
  final DateTime acquired;
  final double? clouds;
  final Map<String, dynamic> stac;
  Scene({
    required this.id,
    required this.collection,
    required this.provider,
    required this.acquired,
    required this.clouds,
    required this.stac,
  });
  factory Scene.fromStac(Map<String, dynamic> j, String provider) {
    final props = j['properties'] as Map<String, dynamic>;
    return Scene(
      id: j['id'] as String,
      collection: j['collection'] as String,
      provider: provider,
      acquired: DateTime.parse(props['datetime'] as String),
      clouds: (props['eo:cloud_cover'] as num?)?.toDouble(),
      stac: j,
    );
  }
  Map<String, dynamic> toJson() => {'provider': provider, 'stac': stac};
  factory Scene.fromJson(Map<String, dynamic> j) => Scene.fromStac(
    j['stac'] as Map<String, dynamic>,
    j['provider'] as String,
  );
}

abstract interface class SceneCatalog {
  Future<List<Scene>> search({
    required GeoBounds bounds,
    required DateTime start,
    required DateTime end,
    double maxCloud = 80,
  });
}

/// Result schema v1. Numeric raster is retained independently from its PNG preview.
class RasterResult {
  final Map<String, dynamic> data;
  RasterResult(this.data) {
    if (data['schema'] != 1)
      throw const FormatException('Versión de resultado no compatible.');
  }
  String get id => data['id'] as String;
  String get sceneId => data['sceneId'] as String;
  String get parcelId => data['parcelId'] as String;
  String get parcelFingerprint => data['parcelFingerprint'] as String;
  String get imagePath => data['imagePath'] as String;
  String? get previewPath => data['imagePath'] as String?;
  String get numericPath => data['numericPath'] as String;

  /// Older Windows workers decoded the UTF-8 separator as Windows-1252.
  String get provider => (data['provider'] as String).replaceAll('Â·', '·');
  String get product =>
      data['collection'] as String? ?? 'Producto sin identificar';
  List<String> get warnings =>
      (data['warnings'] as List? ?? []).whereType<String>().toList();
  Observation get observation =>
      Observation.values.byName(data['observation'] as String);
  DateTime get acquired => DateTime.parse(data['acquired'] as String);
  double get resolution => (data['resolution'] as num).toDouble();
  RasterStatistics get statistics =>
      RasterStatistics.fromJson(data['statistics'] as Map<String, dynamic>);

  /// Screen-level criteria. The raster and its statistics retain schema V1.
  RasterQuality get quality {
    final s = statistics;
    if (s.validPixels <= 0 ||
        s.validPixels > s.totalPixels ||
        !s.validPercent.isFinite ||
        s.validPercent <= 0 ||
        s.validPercent > 100 ||
        s.mean?.isFinite != true) {
      return RasterQuality.unusable;
    }
    if (s.validPixels < 9 || s.validPercent < 50 || warnings.isNotEmpty) {
      return RasterQuality.limited;
    }
    return RasterQuality.available;
  }

  GeoBounds get bounds {
    final b = data['bounds'] as List;
    return GeoBounds(
      (b[0] as num).toDouble(),
      (b[1] as num).toDouble(),
      (b[2] as num).toDouble(),
      (b[3] as num).toDouble(),
    );
  }
}

abstract interface class RasterProcessor {
  Future<RasterResult> process({
    required Scene scene,
    required Parcel parcel,
    required Observation observation,
  });
  Future<PixelSample> sample(RasterResult result, GeoPoint point);
  void cancel();
}

class RasterStatistics {
  final int validPixels, totalPixels, cloudPixels, shadowPixels, missingPixels;
  final double validPercent;
  final double? mean, min, max, median, stdDev;
  const RasterStatistics({
    required this.validPixels,
    required this.totalPixels,
    required this.cloudPixels,
    required this.shadowPixels,
    required this.missingPixels,
    required this.validPercent,
    this.mean,
    this.min,
    this.max,
    this.median,
    this.stdDev,
  });
  factory RasterStatistics.fromJson(Map<String, dynamic> j) => RasterStatistics(
    validPixels: j['validPixels'] as int,
    totalPixels: j['totalPixels'] as int,
    cloudPixels: j['cloudPixels'] as int,
    shadowPixels: j['shadowPixels'] as int,
    missingPixels: j['missingPixels'] as int,
    validPercent: (j['validPercent'] as num).toDouble(),
    mean: (j['mean'] as num?)?.toDouble(),
    min: (j['min'] as num?)?.toDouble(),
    max: (j['max'] as num?)?.toDouble(),
    median: (j['median'] as num?)?.toDouble(),
    stdDev: (j['stdDev'] as num?)?.toDouble(),
  );
}

class PixelSample {
  final List<double?>? values;
  final int? row, column;
  final String? reason;
  const PixelSample({this.values, this.row, this.column, this.reason});
  factory PixelSample.fromJson(Map<String, dynamic> j) => PixelSample(
    values: (j['values'] as List?)
        ?.map((v) => (v as num?)?.toDouble())
        .toList(),
    row: j['row'] as int?,
    column: j['column'] as int?,
    reason: j['reason'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'values': values,
    'row': row,
    'column': column,
    'reason': reason,
  };
}
