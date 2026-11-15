import 'dart:async';
import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:http/http.dart' as http;

/// HTTP transport for browser and mobile apps. The server runs the same worker
/// used by the desktop app.
class RemoteRasterProcessor implements RasterProcessor {
  RemoteRasterProcessor(this.client, this.api);

  final http.Client client;
  final Uri api;
  Completer<void>? _abort;
  bool offline = false;

  Future<Map<String, dynamic>> _post(
    String route,
    Map<String, dynamic> body,
  ) async {
    if (_abort != null) throw StateError('An analysis request is in progress.');
    final abort = Completer<void>();
    _abort = abort;
    try {
      final request =
          http.AbortableRequest(
              'POST',
              api.resolve(route),
              abortTrigger: abort.future,
            )
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode(body);
      final result = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            const Duration(minutes: 4),
            onTimeout: () {
              cancel();
              throw TimeoutException('The analysis service timed out.');
            },
          );
      final isJson = result.headers['content-type']?.contains('json') ?? false;
      if (!isJson) {
        throw StateError(
          'Analysis service unavailable (HTTP ${result.statusCode}).',
        );
      }
      final data = jsonDecode(utf8.decode(result.bodyBytes));
      if (data is! Map<String, dynamic>) {
        throw StateError('Invalid response from the analysis service.');
      }
      if (result.statusCode != 200) {
        throw StateError(
          data['detail'] is String
              ? data['detail'] as String
              : 'Analysis service unavailable (HTTP ${result.statusCode}).',
        );
      }
      return data;
    } finally {
      _abort = null;
    }
  }

  @override
  Future<RasterResult> process({
    required Scene scene,
    required Parcel parcel,
    required Observation observation,
  }) async => RasterResult(
    await _post('/api/raster', {
      'collection': scene.collection,
      'sceneId': scene.id,
      'parcelId': parcel.id,
      'geometry': parcel.geometry.toJson(),
      'observation': observation.name,
    }),
  );

  @override
  Future<PixelSample> sample(RasterResult result, GeoPoint point) async {
    if (offline) {
      return PixelSample.fromJson({
        'values': null,
        'reason': 'Connect to inspect a pixel in this observation.',
      });
    }
    return PixelSample.fromJson(
      await _post('/api/raster/${result.id}/sample', {
        'longitude': point.longitude,
        'latitude': point.latitude,
      }),
    );
  }

  @override
  void cancel() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
  }
}
