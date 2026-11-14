import 'package:field_core/field_core.dart';
import 'package:test/test.dart';

void main() {
  List<GeoPoint> square() => [
    GeoPoint(0, 0),
    GeoPoint(0, .001),
    GeoPoint(.001, .001),
    GeoPoint(.001, 0),
  ];
  test(
    'spherical geodesic area known equatorial square; orientation invariant',
    () {
      final g = FieldGeometry(square());
      expect(g.hectares, closeTo(1.236434, 0.00001));
      expect(
        FieldGeometry(square().reversed.toList()).hectares,
        closeTo(g.hectares, 1e-8),
      );
    },
  );
  test(
    'reject insufficient, duplicate, crossing, collinear and dateline rings',
    () {
      expect(
        () => FieldGeometry([GeoPoint(0, 0), GeoPoint(1, 1)]),
        throwsArgumentError,
      );
      expect(
        () => FieldGeometry([...square(), square().first]),
        throwsArgumentError,
      );
      expect(
        () => FieldGeometry([
          GeoPoint(0, 0),
          GeoPoint(1, 1),
          GeoPoint(0, 1),
          GeoPoint(1, 0),
        ]),
        throwsArgumentError,
      );
      expect(
        () => FieldGeometry([GeoPoint(0, 0), GeoPoint(0, 1), GeoPoint(0, 2)]),
        throwsArgumentError,
      );
      expect(
        () => FieldGeometry([
          GeoPoint(0, 179),
          GeoPoint(1, -179),
          GeoPoint(0, -179),
        ]),
        throwsArgumentError,
      );
    },
  );
  test('coordinates reject NaN and outside supported map range', () {
    expect(() => GeoPoint(double.nan, 0), throwsArgumentError);
    expect(() => GeoPoint(86, 0), throwsArgumentError);
    expect(() => GeoPoint(0, 181), throwsArgumentError);
  });
  test('parcel contract preserves geometry and farmer information', () {
    final p = Parcel(
      id: 'p',
      name: 'Terreno',
      geometry: FieldGeometry(square()),
      farm: const FarmRecord(
        crop: 'Maíz',
        history: '2024: frijol',
        soil: 'Franco',
        water: 'Estacional',
        irrigation: 'Goteo',
        budget: 'Limitado',
        priorities: 'Ahorrar agua',
      ),
      updatedAt: DateTime.utc(2026),
    );
    final copy = Parcel.fromJson(p.toJson());
    expect(copy.toJson(), p.toJson());
    expect(copy.geometry.toGeoJson()['type'], 'Polygon');
  });
}
