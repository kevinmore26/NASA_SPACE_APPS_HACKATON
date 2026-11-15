import 'package:field_imagery/field_imagery.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:http/http.dart' as http;

import '../app.dart';
import '../application/crop_suitability.dart';
import '../application/field_controller.dart';
import 'browser_store.dart';
import 'remote_raster_processor.dart';

Future<FieldShiftApp> openFieldShift() async {
  const configuredApi = String.fromEnvironment('FIELD_SHIFT_API_URL');
  final api = Uri.base.resolve(configuredApi);
  final store = await BrowserStore.open();
  final client = http.Client();
  final processor = RemoteRasterProcessor(client, api);
  final model = FieldController(
    parcels: store,
    documents: store,
    sentinel: StacCatalog.sentinel(
      client,
      endpoint: api.resolve('/api/catalog/sentinel'),
    ),
    landsat: landsatCatalog(
      client,
      endpoint: api.resolve('/api/catalog/landsat'),
    ),
    climate: NasaPower(client, endpoint: api.resolve('/api/weather')),
    processor: processor,
    cropSuitabilityClient: CropSuitabilityClient(
      client,
      api.resolve('/api/crops/suitability'),
    ),
  );
  await model.initialize();
  processor.offline = model.offline;
  model.addListener(() => processor.offline = model.offline);
  return FieldShiftApp(
    model: model,
    tiles: _BrowserTiles(http.Client(), model),
    dataDirectory: null,
  );
}

class _BrowserTiles extends http.BaseClient {
  _BrowserTiles(this.client, this.model);

  final http.Client client;
  final FieldController model;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (model.offline) {
      throw http.ClientException('Map tiles require an internet connection.');
    }
    return client.send(request);
  }

  @override
  void close() {
    client.close();
    super.close();
  }
}
