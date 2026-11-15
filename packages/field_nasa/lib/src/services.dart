import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:http/http.dart' as http;

class GibsLayer {
  static const id = 'MODIS_Terra_CorrectedReflectance_TrueColor';
  static const attribution =
      'NASA EOSDIS GIBS · MODIS Terra · RGB de visualización · 250 m';
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
      (data['properties'] as Map<String, dynamic>)['parameter']
          as Map<String, dynamic>;
  Map<String, dynamic> get units => data['parameters'] as Map<String, dynamic>;
  List<String> get days =>
      (parameters.values.first as Map<String, dynamic>).keys.toList()..sort();
  double? value(String parameter, String day) {
    final raw =
        (parameters[parameter] as Map<String, dynamic>? ?? {})[day] as num?;
    final fill =
        (data['header'] as Map<String, dynamic>?)?['fill_value'] as num? ??
        -999;
    return raw == null || raw == fill ? null : raw.toDouble();
  }
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
    return ClimateSeries(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
