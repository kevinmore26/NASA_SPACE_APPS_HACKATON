import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic> cropSuitabilityInputs(Parcel parcel) {
  final center = parcel.geometry.bounds.center;
  final farm = parcel.farm.planning;
  final texture = farm?.texture;
  return {
    'latitude': center.latitude,
    'longitude': center.longitude,
    if (texture != null && texture != SoilTexture.other)
      'texture': texture.name,
    if (farm?.drainage case final SoilDrainage drainage)
      'drainage': drainage.name,
    if (farm?.soilConductivity case final double conductivity)
      'soilConductivity': conductivity,
  };
}

enum CropSuitabilityStatus { candidates, conditional, empty }

class CropSuitability {
  final Map<String, dynamic> data;
  final CropSuitabilityStatus status;
  final DateTime start, end;
  final String source, catalog;
  final bool usesSoil;
  final List<CropCandidate> crops;

  CropSuitability.fromJson(this.data)
    : status = CropSuitabilityStatus.values.byName(data['status'] as String),
      start = DateTime.parse(data['period']['start'] as String),
      end = DateTime.parse(data['period']['end'] as String),
      source = data['source'] as String,
      catalog = data['catalog'] as String,
      usesSoil = (data['soilFactors'] as List).isNotEmpty,
      crops = List.unmodifiable(
        (data['crops'] as List).map(
          (row) => CropCandidate(
            name: row['name'] as String,
            scientificName: row['scientificName'] as String? ?? '',
            score: (row['score'] as num).toDouble(),
          ),
        ),
      ) {
    if (data['schema'] != 1 ||
        end.isBefore(start) ||
        (status == CropSuitabilityStatus.empty) != crops.isEmpty ||
        crops.any(
          (crop) => !crop.score.isFinite || crop.score < 0 || crop.score > 100,
        )) {
      throw const FormatException('Invalid crop suitability results.');
    }
  }
}

class CropCandidate {
  final String name, scientificName;
  final double score;
  const CropCandidate({
    required this.name,
    required this.scientificName,
    required this.score,
  });
}

class CropSuitabilityClient {
  final http.Client client;
  final Uri endpoint;
  const CropSuitabilityClient(this.client, this.endpoint);

  Future<CropSuitability> evaluate(Map<String, dynamic> inputs) async {
    final response = await client
        .post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(inputs),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      throw StateError(
        'Crop suitability service returned HTTP ${response.statusCode}.',
      );
    }
    final result = jsonDecode(utf8.decode(response.bodyBytes));
    if (result is! Map<String, dynamic>) {
      throw const FormatException('Invalid crop suitability response.');
    }
    return CropSuitability.fromJson(result);
  }
}
