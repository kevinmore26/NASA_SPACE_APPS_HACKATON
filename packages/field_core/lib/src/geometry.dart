import 'dart:math' as math;

/// Public contract v1. WGS84 longitude/latitude, decimal degrees.
class GeoPoint {
  final double latitude;
  final double longitude;
  GeoPoint(this.latitude, this.longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 85 ||
        longitude.abs() > 180) {
      throw ArgumentError(
        'Coordenadas inválidas: latitud −85…85, longitud −180…180.',
      );
    }
  }
  List<double> toJson() => [longitude, latitude];
  factory GeoPoint.fromJson(List<dynamic> v) =>
      GeoPoint((v[1] as num).toDouble(), (v[0] as num).toDouble());
}

class GeoBounds {
  final double west, south, east, north;
  const GeoBounds(this.west, this.south, this.east, this.north);
  List<double> toJson() => [west, south, east, north];
  GeoPoint get center => GeoPoint((north + south) / 2, (east + west) / 2);
  factory GeoBounds.fromPoints(List<GeoPoint> points) => GeoBounds(
    points.map((p) => p.longitude).reduce(math.min),
    points.map((p) => p.latitude).reduce(math.min),
    points.map((p) => p.longitude).reduce(math.max),
    points.map((p) => p.latitude).reduce(math.max),
  );
}

enum GeometryIssue {
  tooFewPoints('Marca al menos tres puntos.'),
  tooManyPoints('Máximo 500 puntos por terreno.'),
  dateLineCrossing('No se admite cruzar el meridiano 180°.'),
  overlappingEdges('Hay bordes superpuestos. Corrige los puntos.'),
  duplicatePoints('Hay puntos repetidos.'),
  intersectingEdges('Los bordes se cruzan. Corrige los puntos.'),
  tooSmall('El terreno no tiene una superficie suficiente.');

  const GeometryIssue(this.message);
  final String message;
}

/// A simple ring without repeated closing point. Dateline crossings are rejected.
class FieldGeometry {
  final List<GeoPoint> vertices;
  FieldGeometry(List<GeoPoint> points) : vertices = List.unmodifiable(points) {
    final error = validate(points);
    if (error != null) throw ArgumentError(error);
  }
  GeoBounds get bounds => GeoBounds.fromPoints(vertices);
  static String? validate(List<GeoPoint> points) =>
      validationIssue(points)?.message;

  static GeometryIssue? validationIssue(List<GeoPoint> p) {
    if (p.length < 3) return GeometryIssue.tooFewPoints;
    if (p.length > 500) return GeometryIssue.tooManyPoints;
    if (GeoBounds.fromPoints(p).east - GeoBounds.fromPoints(p).west > 180) {
      return GeometryIssue.dateLineCrossing;
    }
    for (var i = 0; i < p.length; i++) {
      final a = p[(i + p.length - 1) % p.length],
          b = p[i],
          c = p[(i + 1) % p.length];
      final dot =
          (b.longitude - a.longitude) * (c.longitude - b.longitude) +
          (b.latitude - a.latitude) * (c.latitude - b.latitude);
      if (_cross(a, b, c).abs() < 1e-14 && dot < 0) {
        return GeometryIssue.overlappingEdges;
      }
      for (var j = i + 1; j < p.length; j++) {
        if ((p[i].latitude - p[j].latitude).abs() < 1e-10 &&
            (p[i].longitude - p[j].longitude).abs() < 1e-10) {
          return GeometryIssue.duplicatePoints;
        }
      }
    }
    for (var i = 0; i < p.length; i++) {
      for (var j = i + 1; j < p.length; j++) {
        if (j == i + 1 || (i == 0 && j == p.length - 1)) continue;
        if (_intersects(
          p[i],
          p[(i + 1) % p.length],
          p[j],
          p[(j + 1) % p.length],
        )) {
          return GeometryIssue.intersectingEdges;
        }
      }
    }
    if (_area(p) < 0.1) return GeometryIssue.tooSmall;
    return null;
  }

  static double _cross(GeoPoint a, GeoPoint b, GeoPoint c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);
  static bool _on(GeoPoint a, GeoPoint b, GeoPoint c) =>
      c.longitude >= math.min(a.longitude, b.longitude) &&
      c.longitude <= math.max(a.longitude, b.longitude) &&
      c.latitude >= math.min(a.latitude, b.latitude) &&
      c.latitude <= math.max(a.latitude, b.latitude);
  static bool _intersects(GeoPoint a, GeoPoint b, GeoPoint c, GeoPoint d) {
    final x = _cross(a, b, c),
        y = _cross(a, b, d),
        z = _cross(c, d, a),
        w = _cross(c, d, b);
    return (x * y < 0 && z * w < 0) ||
        (x.abs() < 1e-14 && _on(a, b, c)) ||
        (y.abs() < 1e-14 && _on(a, b, d)) ||
        (z.abs() < 1e-14 && _on(c, d, a)) ||
        (w.abs() < 1e-14 && _on(c, d, b));
  }

  /// Spherical geodesic area, authalic Earth radius 6371007.18 m.
  /// Approximation, not a cadastral survey; ellipsoidal differences may reach ~0.5%.
  static double _area(List<GeoPoint> p) {
    var sum = 0.0;
    for (var i = 0; i < p.length; i++) {
      final a = p[i], b = p[(i + 1) % p.length];
      sum +=
          (b.longitude - a.longitude) *
          math.pi /
          180 *
          (2 +
              math.sin(a.latitude * math.pi / 180) +
              math.sin(b.latitude * math.pi / 180));
    }
    return (sum * 6371007.18 * 6371007.18 / 2).abs();
  }

  double get hectares => _area(vertices) / 10000;
  Map<String, dynamic> toGeoJson() => {
    'type': 'Polygon',
    'coordinates': [
      [...vertices.map((p) => p.toJson()), vertices.first.toJson()],
    ],
  };
  List<List<double>> toJson() => vertices.map((p) => p.toJson()).toList();
  factory FieldGeometry.fromJson(List<dynamic> v) => FieldGeometry(
    v.map((p) => GeoPoint.fromJson(p as List<dynamic>)).toList(),
  );
}
