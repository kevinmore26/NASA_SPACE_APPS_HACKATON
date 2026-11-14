import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Reusable STAC protocol adapter. Each provider declares its own configuration.
class StacCatalog implements SceneCatalog {
  final http.Client client;
  final Uri endpoint;
  final String collection, provider;
  StacCatalog({
    required this.client,
    required this.endpoint,
    required this.collection,
    required this.provider,
  });
  factory StacCatalog.sentinel(http.Client client) => StacCatalog(
    client: client,
    endpoint: Uri.parse('https://earth-search.aws.element84.com/v1/search'),
    collection: 'sentinel-2-l2a',
    provider: 'ESA/Copernicus · Earth Search',
  );
  @override
  Future<List<Scene>> search({
    required GeoBounds bounds,
    required DateTime start,
    required DateTime end,
    double maxCloud = 80,
  }) async {
    if (end.isBefore(start))
      throw ArgumentError('La fecha final debe ser posterior a la inicial.');
    final response = await client
        .post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'collections': [collection],
            'bbox': bounds.toJson(),
            'datetime':
                '${start.toUtc().toIso8601String()}/${end.toUtc().toIso8601String()}',
            'limit': 30,
            'query': {
              'eo:cloud_cover': {'lte': maxCloud},
            },
          }),
        )
        .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200)
      throw http.ClientException(
        'Catálogo no disponible (HTTP ${response.statusCode}).',
      );
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (j['features'] as List)
        .map((f) => Scene.fromStac(f as Map<String, dynamic>, provider))
        .toList();
    results.sort((a, b) => b.acquired.compareTo(a.acquired));
    return results;
  }
}
