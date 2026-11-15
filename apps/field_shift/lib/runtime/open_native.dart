import 'dart:io';

import 'package:field_compute/field_compute.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:field_storage/field_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app.dart';
import '../application/crop_suitability.dart';
import '../application/field_controller.dart';

Future<FieldShiftApp> openFieldShift() async {
  final support = await getApplicationSupportDirectory();
  await support.create(recursive: true);
  final store = await LocalStore.open(
    p.join(support.path, 'field_shift.sqlite'),
  );
  final tiles = CachedTileClient(Directory(p.join(support.path, 'tiles')));
  final client = http.Client();
  const configuredApi = String.fromEnvironment('FIELD_SHIFT_API_URL');
  var executable = p.join(
    p.dirname(Platform.resolvedExecutable),
    'workers',
    'raster_worker',
    'raster_worker.exe',
  );
  var arguments = <String>[];
  if (!File(executable).existsSync()) {
    var directory = Directory.current;
    for (var i = 0; i < 8; i++) {
      final script = File(
        p.join(
          directory.path,
          'packages',
          'field_compute',
          'worker',
          'raster_worker.py',
        ),
      );
      if (script.existsSync()) {
        executable = p.join(directory.path, '.venv', 'Scripts', 'python.exe');
        arguments = [script.path];
        break;
      }
      directory = directory.parent;
    }
  }
  final model = FieldController(
    parcels: store,
    documents: store,
    sentinel: StacCatalog.sentinel(client),
    landsat: landsatCatalog(client),
    climate: NasaPower(client),
    processor: LocalRasterProcessor(
      executable: executable,
      arguments: arguments,
      outputDirectory: p.join(support.path, 'results'),
    ),
    cropSuitabilityClient: configuredApi.isEmpty
        ? null
        : CropSuitabilityClient(
            client,
            Uri.parse(configuredApi).resolve('/api/crops/suitability'),
          ),
  );
  await model.initialize();
  tiles.offline = model.offline;
  model.addListener(() => tiles.offline = model.offline);
  return FieldShiftApp(model: model, tiles: tiles, dataDirectory: support.path);
}
