import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:http/http.dart' as http;

class GibsLayer {
  static const id = 'MODIS_Terra_CorrectedReflectance_TrueColor';
  static const attribution = 'NASA EOSDIS GIBS · MODIS Terra RGB · 250 m';
  static String template(DateTime date) =>
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/$id/default/${date.toIso8601String().substring(0, 10)}/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg';
}

SceneCatalog landsatCatalog(http.Client client) => StacCatalog(
  client: client,
  endpoint: Uri.parse(
    'https://planetarycomputer.microsoft.com/api/stac/v1/search',
  ),
  collection: 'landsat-c2-l2',
  provider: 'USGS/NASA · Planetary Computer',
);

class ClimateSeries {
  final Map<String, dynamic> data;
  ClimateSeries(this.data);

  Map<String, dynamic> get parameters =>
      _object(_object(data['properties'])['parameter']);
  Map<String, dynamic> get units => _object(data['parameters']);

  String? unitFor(String parameter) {
    final unit = _object(units[parameter])['units'];
    return unit is String ? unit : null;
  }

  List<String> get days => {
    for (final series in parameters.values)
      for (final day in _object(series).keys)
        if (day.length == 8 && DateTime.tryParse(day) != null) day,
  }.toList()..sort();

  double? value(String parameter, String day) {
    final raw = _object(parameters[parameter])[day];
    final fill = _object(data['header'])['fill_value'] ?? -999;
    return raw is num && raw.isFinite && raw != fill ? raw.toDouble() : null;
  }

  static Map<String, dynamic> _object(Object? value) =>
      value is Map<String, dynamic> ? value : const {};
}

abstract interface class ClimateProvider {
  Future<ClimateSeries> daily(GeoPoint point, DateTime start, DateTime end);
}

class NasaPower implements ClimateProvider {
  final http.Client client;
  NasaPower(this.client);
  @override
  Future<ClimateSeries> daily(
    GeoPoint point,
    DateTime start,
    DateTime end,
  ) async {
    String date(DateTime d) =>
        d.toIso8601String().substring(0, 10).replaceAll('-', '');
    if (end.isBefore(start) || end.difference(start).inDays > 366) {
      throw ArgumentError('Selecciona hasta un año de datos climáticos.');
    }
    final uri = Uri.https('power.larc.nasa.gov', '/api/temporal/daily/point', {
      'parameters': 'T2M,PRECTOTCORR,RH2M,ALLSKY_SFC_SW_DWN',
      'community': 'AG',
      'longitude': '${point.longitude}',
      'latitude': '${point.latitude}',
      'start': date(start),
      'end': date(end),
      'format': 'JSON',
      'time-standard': 'UTC',
    });
    final response = await client.get(uri).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'NASA POWER no disponible (HTTP ${response.statusCode}).',
      );
    }
    return ClimateSeries(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
