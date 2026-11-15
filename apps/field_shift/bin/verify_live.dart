import 'dart:convert';
import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final out = Directory(args.isEmpty ? '../../docs/evidence' : args.single);
  await out.create(recursive: true);
  final client = http.Client();
  final report = <String, dynamic>{
    'verificationUtc': DateTime.now().toUtc().toIso8601String(),
    'bbox': [-76.18, -13.75, -76.12, -13.69],
  };
  try {
    for (final entry in {
      'sentinel': StacCatalog.sentinel(client),
      'landsat': landsatCatalog(client),
    }.entries) {
      final result = await entry.value.search(
        bounds: const GeoBounds(-76.18, -13.75, -76.12, -13.69),
        start: DateTime.utc(2025, 2, 1),
        end: DateTime.utc(2025, 3, 1),
        maxCloud: 40,
      );
      if (result.isEmpty) throw StateError('No scenes from ${entry.key}');
      await File('${out.path}/${entry.key}_dart_live.json')
          .writeAsString(jsonEncode(result.map((s) => s.toJson()).toList()));
      report[entry.key] = {
        'scenes': result.length,
        'firstId': result.first.id,
        'provider': result.first.provider,
        'date': result.first.acquired.toIso8601String(),
      };
    }
    final weather = await NasaPower(client).daily(
      GeoPoint(-13.718, -76.148),
      DateTime.utc(2025, 2, 1),
      DateTime.utc(2025, 2, 7),
    );
    await File('${out.path}/power_live.json')
        .writeAsString(jsonEncode(weather.data));
    report['power'] = {
      'days': weather.days.length,
      'units': weather.units,
      'firstDay': weather.days.first,
    };
    final template = GibsLayer.template(DateTime(2025, 2, 28));
    final url = template
        .replaceAll('{z}', '9')
        .replaceAll('{x}', '147')
        .replaceAll('{y}', '275');
    final tile = await client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (tile.statusCode != 200 || tile.bodyBytes.length < 100) {
      throw StateError('GIBS failed ${tile.statusCode}');
    }
    await File('${out.path}/gibs_live.jpg').writeAsBytes(tile.bodyBytes);
    report['gibs'] = {
      'url': url,
      'status': tile.statusCode,
      'bytes': tile.bodyBytes.length,
      'mime': tile.headers['content-type'],
    };
    report['status'] = 'PASS';
  } catch (e) {
    report['status'] = 'FAIL';
    report['error'] = e.toString();
    exitCode = 1;
  } finally {
    client.close();
    await File('${out.path}/live_adapters.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(jsonEncode(report));
  }
}
