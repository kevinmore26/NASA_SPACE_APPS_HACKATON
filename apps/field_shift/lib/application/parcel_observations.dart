import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_nasa/field_nasa.dart';

/// Typed read model of archived observations for the current parcel limits.
class ParcelObservations {
  final List<RasterResult> rasters;
  final ClimateSeries? climate;
  final bool incomplete;

  const ParcelObservations({
    this.rasters = const [],
    this.climate,
    this.incomplete = false,
  });

  RasterResult? get latestUsable => rasters.reversed
      .where((r) => r.quality != RasterQuality.unusable)
      .firstOrNull;

  static Future<ParcelObservations> read(
    LocalDocuments documents,
    Parcel parcel,
  ) async {
    final geometry = jsonEncode(parcel.geometry.toGeoJson());
    final rasters = <RasterResult>[];
    var incomplete = false;
    ClimateSeries? climate;
    try {
      final entries = await documents.listDocuments('result:${parcel.id}:');
      for (final entry in entries) {
        if (jsonEncode(entry['geometry']) != geometry) continue;
        try {
          final raster = RasterResult(entry);
          // Validate the fields used to represent historical results.
          raster.id;
          raster.acquired;
          raster.observation;
          raster.quality;
          rasters.add(raster);
        } on Object {
          incomplete = true;
        }
      }
    } on Object {
      incomplete = true;
    }
    try {
      final data = await documents.readDocument('power:${parcel.id}');
      if (data != null && _matchesClimate(data, parcel)) {
        climate = ClimateSeries(data);
        climate.days;
      }
    } on Object {
      climate = null;
      incomplete = true;
    }

    rasters.sort((a, b) => a.acquired.compareTo(b.acquired));
    return ParcelObservations(
      rasters: List.unmodifiable(rasters),
      climate: climate,
      incomplete: incomplete,
    );
  }

  static bool _matchesClimate(Map<String, dynamic> data, Parcel parcel) {
    // V2 records the original query point. V1 POWER responses echo the query.
    final geometry = data['geometry'];
    final point =
        data['fieldShiftQueryPoint'] ??
        (geometry is Map ? geometry['coordinates'] : null);
    if (point is! List || point.length < 2) return false;
    final center = parcel.geometry.bounds.center;
    return point[0] is num &&
        point[1] is num &&
        (center.longitude - (point[0] as num)).abs() < 0.0001 &&
        (center.latitude - (point[1] as num)).abs() < 0.0001;
  }
}
