import 'dart:io';

import 'package:field_compute/field_compute.dart';
import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:test/test.dart';

void main() {
  test(
    'missing local runtime reports failure, releases lock, and supports cancel',
    () async {
      final p = LocalRasterProcessor(
        executable: 'this-runtime-does-not-exist.exe',
        outputDirectory: Directory.systemTemp.path,
      );
      final parcel = Parcel(
        id: 'x',
        name: 'x',
        geometry: FieldGeometry([
          GeoPoint(0, 0),
          GeoPoint(0, 1),
          GeoPoint(1, 1),
        ]),
        updatedAt: DateTime.utc(2025),
      );
      final scene = Scene.fromStac({
        'id': 'fixture',
        'collection': 'test',
        'properties': {'datetime': '2025-01-01T00:00:00Z'},
        'assets': {},
      }, 'fixture');
      for (var i = 0; i < 2; i++) {
        await expectLater(
          p.process(
            scene: scene,
            parcel: parcel,
            observation: Observation.ndvi,
          ),
          throwsA(isA<ProcessException>()),
        );
      }
      p.cancel();
    },
  );
}
