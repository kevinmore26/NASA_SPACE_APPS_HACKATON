import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';

/// Desktop process adapter, JSON protocol v1. No Flutter dependencies.
class LocalRasterProcessor implements RasterProcessor {
  final String executable, outputDirectory;
  final List<String> arguments;
  Process? _process;
  bool _busy = false;
  bool _cancelled = false;
  LocalRasterProcessor({
    required this.executable,
    required this.outputDirectory,
    this.arguments = const [],
  });
  Future<Map<String, dynamic>> _run(Map<String, dynamic> request) async {
    if (_busy) throw StateError('Ya hay un análisis en curso.');
    _busy = true;
    _cancelled = false;
    try {
      _process = await Process.start(
        executable,
        arguments,
        mode: ProcessStartMode.normal,
      );
      if (_cancelled) {
        _process!.kill();
        throw StateError('Análisis cancelado.');
      }
      final process = _process!;
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(jsonEncode({'schema': 1, ...request}));
      await process.stdin.close();
      final code = await process.exitCode.timeout(
        const Duration(minutes: 4),
        onTimeout: () {
          process.kill();
          throw TimeoutException(
            'El proveedor tardó demasiado. Intenta con un terreno menor.',
          );
        },
      );
      final output = await stdout;
      final errors = await stderr;
      if (_cancelled) throw StateError('Análisis cancelado.');
      if (code != 0) {
        String message = 'No se pudo procesar la escena.';
        try {
          message =
              (jsonDecode(errors.trim().split('\n').last)
                      as Map<String, dynamic>)['error']
                  as String;
        } catch (_) {}
        throw StateError(message);
      }
      return jsonDecode(output) as Map<String, dynamic>;
    } finally {
      _busy = false;
      _process = null;
    }
  }

  @override
  Future<RasterResult> process({
    required Scene scene,
    required Parcel parcel,
    required Observation observation,
  }) async => RasterResult(
    await _run({
      'scene': scene.toJson(),
      'parcel': parcel.toJson(),
      'observation': observation.name,
      'output': outputDirectory,
    }),
  );
  @override
  Future<PixelSample> sample(RasterResult result, GeoPoint point) async =>
      PixelSample.fromJson(
        await _run({
          'command': 'sample',
          'numericPath': result.numericPath,
          'latitude': point.latitude,
          'longitude': point.longitude,
        }),
      );
  @override
  void cancel() {
    _cancelled = true;
    _process?.kill();
  }
}
