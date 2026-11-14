import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'STAC request includes area, dates and cloud filter; preserves metadata',
    () async {
      final client = MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['bbox'], [-76.2, -13.8, -76.1, -13.7]);
        expect(body['collections'], ['sentinel-2-l2a']);
        expect(body['query']['eo:cloud_cover']['lte'], 25);
        return http.Response(
          jsonEncode({
            'features': [
              {
                'id': 'known',
                'collection': 'sentinel-2-l2a',
                'properties': {
                  'datetime': '2025-01-01T10:00:00Z',
                  'eo:cloud_cover': 3.5,
                },
                'assets': {},
              },
            ],
          }),
          200,
        );
      });
      final results = await StacCatalog.sentinel(client).search(
        bounds: const GeoBounds(-76.2, -13.8, -76.1, -13.7),
        start: DateTime.utc(2025),
        end: DateTime.utc(2025, 2),
        maxCloud: 25,
      );
      expect(results.single.clouds, 3.5);
      expect(Scene.fromJson(results.single.toJson()).id, 'known');
      client.close();
    },
  );
  test('HTTP errors do not produce fake scenes', () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    expect(
      () => StacCatalog.sentinel(client).search(
        bounds: const GeoBounds(0, 0, 1, 1),
        start: DateTime.utc(2025),
        end: DateTime.utc(2025, 2),
      ),
      throwsA(isA<http.ClientException>()),
    );
    client.close();
  });
}
