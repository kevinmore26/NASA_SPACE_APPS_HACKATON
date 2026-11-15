import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('GIBS projection, matrix, temporal URL and attribution', () {
    final url = GibsLayer.template(DateTime(2025, 2, 28));
    expect(url, contains('epsg3857'));
    expect(
      url,
      contains('2025-02-28/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg'),
    );
  });
  test('POWER missing values remain missing and units are preserved', () async {
    final client = MockClient((r) async {
      expect(r.url.queryParameters['time-standard'], 'UTC');
      return http.Response(
        jsonEncode({
          'header': {'fill_value': -999},
          'parameters': {
            'T2M': {'units': 'C'},
          },
          'properties': {
            'parameter': {
              'T2M': {'20250101': 24.5, '20250102': -999},
            },
          },
        }),
        200,
      );
    });
    final series = await NasaPower(client)
        .daily(GeoPoint(-13.7, -76.1), DateTime(2025), DateTime(2025, 1, 2));
    expect(series.value('T2M', '20250101'), 24.5);
    expect(series.value('T2M', '20250102'), null);
    expect(series.units['T2M']['units'], 'C');
    client.close();
  });
  test('POWER service errors are explicit', () async {
    final client = MockClient((_) async => http.Response('rate limit', 429));
    expect(
      () =>
          NasaPower(client)
              .daily(GeoPoint(0, 0), DateTime(2025), DateTime(2025, 1, 2)),
      throwsA(isA<http.ClientException>()),
    );
    client.close();
  });
}
