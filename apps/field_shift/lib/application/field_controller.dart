import 'dart:convert';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:flutter/foundation.dart';

/// App orchestration. Domain contracts are constructor-injected.
class FieldController extends ChangeNotifier {
  final ParcelRepository parcels;
  final LocalDocuments documents;
  final SceneCatalog sentinel, landsat;
  final ClimateProvider climate;
  final RasterProcessor processor;
  FieldController({
    required this.parcels,
    required this.documents,
    required this.sentinel,
    required this.landsat,
    required this.climate,
    required this.processor,
  });
  List<Parcel> saved = [];
  Parcel? selected;
  List<GeoPoint> vertices = [];
  final List<List<GeoPoint>> _undo = [];
  List<Scene> scenes = [];
  List<RasterResult> results = [];
  RasterResult? result, comparison;
  ClimateSeries? weather;
  PixelSample? pixel;
  bool editing = false,
      advanced = false,
      offline = false,
      gibs = false,
      showRaster = true,
      useLandsat = false;
  String base = 'roads', page = 'Inicio', message = '', busy = '';
  int? selectedVertex;
  double opacity = 0.85, maxCloud = 80;
  DateTime start = DateTime.now().subtract(const Duration(days: 120));
  DateTime end = DateTime.now().subtract(const Duration(days: 7));
  DateTime gibsDate = DateTime.now().subtract(const Duration(days: 2));
  int _generation = 0;
  bool _disposed = false;
  void emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      saved = await parcels.listParcels();
      final p = await documents.readDocument('preferences-v1');
      if (p != null) {
        advanced = p['advanced'] as bool? ?? false;
        offline = p['offline'] as bool? ?? false;
        base = p['base'] as String? ?? 'roads';
        gibs = p['gibs'] as bool? ?? false;
        opacity = (p['opacity'] as num?)?.toDouble() ?? .85;
        gibsDate =
            DateTime.tryParse(p['gibsDate'] as String? ?? '') ?? gibsDate;
      }
    } catch (_) {
      message = 'No se pudieron recuperar los datos locales. Comprueba el acceso al disco.';
    }
    emit();
  }

  Future<void> preferences() async {
    try {
      await documents.writeDocument('preferences-v1', {
        'schema': 1,
        'advanced': advanced,
        'offline': offline,
        'base': base,
        'gibs': gibs,
        'opacity': opacity,
        'gibsDate': gibsDate.toIso8601String(),
      });
    } catch (_) {
      message = 'No se pudo guardar la configuración.';
      emit();
    }
  }

  void navigate(String next) {
    page = next;
    emit();
  }

  void newParcel() {
    _generation++;
    processor.cancel();
    busy = '';
    selected = null;
    vertices = [];
    _undo.clear();
    selectedVertex = null;
    editing = true;
    result = null;
    comparison = null;
    weather = null;
    results = [];
    scenes = [];
    page = 'Explorar mapa';
    message = 'Marca las esquinas de tu terreno sobre el mapa.';
    emit();
  }

  Future<void> select(Parcel parcel) async {
    _generation++;
    processor.cancel();
    busy = '';
    selected = parcel;
    vertices = List.of(parcel.geometry.vertices);
    editing = false;
    selectedVertex = null;
    result = null;
    comparison = null;
    pixel = null;
    weather = null;
    scenes = [];
    _undo.clear();
    page = 'Explorar mapa';
    message = 'Terreno guardado en este equipo.';
    final epoch = _generation;
    try {
      final docs = await documents.listDocuments('result:${parcel.id}:');
      if (epoch != _generation) return;
      results =
          docs
              .map(RasterResult.new)
              .where(
                (r) =>
                    jsonEncode(r.data['geometry']) ==
                    jsonEncode(parcel.geometry.toGeoJson()),
              )
              .toList()
            ..sort((a, b) => a.acquired.compareTo(b.acquired));
      final cached = await documents.readDocument('power:${parcel.id}');
      if (epoch != _generation) return;
      if (cached != null) weather = ClimateSeries(cached);
    } catch (_) {
      message = 'Algunos resultados locales no se pudieron leer.';
      results = [];
    }
    emit();
  }

  void edit() {
    if (selected == null) return;
    editing = true;
    _undo.clear();
    result = null;
    comparison = null;
    message = 'Toca un punto numerado y luego su nueva posición. O añade otra esquina.';
    emit();
  }

  void cancelEdit() {
    vertices = selected == null ? [] : List.of(selected!.geometry.vertices);
    editing = false;
    selectedVertex = null;
    _undo.clear();
    message = 'Cambios descartados.';
    emit();
  }

  void tap(GeoPoint p) {
    if (!editing) return;
    _undo.add(List.of(vertices));
    if (selectedVertex != null) {
      vertices = List.of(vertices)..[selectedVertex!] = p;
      selectedVertex = null;
    } else {
      vertices = [...vertices, p];
    }
    message =
        '${vertices.length} puntos marcados. ${FieldGeometry.validate(vertices) ?? 'Puedes guardar tu terreno.'}';
    emit();
  }

  void chooseVertex(int i) {
    selectedVertex = i;
    message = 'Toca la nueva posición del punto ${i + 1}.';
    emit();
  }

  void undo() {
    if (_undo.isNotEmpty) {
      vertices = _undo.removeLast();
      selectedVertex = null;
      emit();
    }
  }

  void removeVertex() {
    if (selectedVertex != null) {
      _undo.add(List.of(vertices));
      vertices = List.of(vertices)..removeAt(selectedVertex!);
      selectedVertex = null;
      emit();
    }
  }

  Future<void> save(String name, FarmRecord farm) async {
    await run('Guardando terreno…', () async {
      final sameGeometry =
          selected != null &&
          jsonEncode(selected!.geometry.toJson()) ==
              jsonEncode(vertices.map((p) => p.toJson()).toList());
      final parcel = Parcel(
        id: selected?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        geometry: FieldGeometry(vertices),
        farm: farm,
        updatedAt: DateTime.now(),
      );
      await parcels.saveParcel(parcel);
      saved = await parcels.listParcels();
      selected = parcel;
      editing = false;
      selectedVertex = null;
      _undo.clear();
      if (!sameGeometry) {
        result = null;
        comparison = null;
        results = [];
        weather = null;
      }
      message = 'Terreno guardado. Puedes consultarlo sin internet.';
    });
  }

  Future<void> deleteSelected() async {
    final parcel = selected;
    if (parcel == null) return;
    await run('Eliminando terreno…', () async {
      await parcels.deleteParcel(parcel.id);
      saved = await parcels.listParcels();
      selected = null;
      vertices = [];
      results = [];
      result = null;
      comparison = null;
      weather = null;
      message = 'Terreno eliminado. Los análisis archivados se conservan en el equipo.';
      page = 'Mis terrenos';
    });
  }

  Future<void> run(String label, Future<void> Function() task) async {
    if (busy.isNotEmpty) return;
    busy = label;
    message = '';
    emit();
    try {
      await task();
    } catch (e) {
      message = e.toString().replaceFirst(
        RegExp(r'^(Bad state: |Invalid argument\(s\): |Exception: )'),
        '',
      );
    } finally {
      busy = '';
      emit();
    }
  }

  Future<void> searchScenes() async {
    if (selected == null || editing) {
      message = 'Guarda primero los límites del terreno.';
      emit();
      return;
    }
    if (offline) {
      message = 'Conecta internet para buscar imágenes nuevas. Tus resultados guardados siguen disponibles.';
      emit();
      return;
    }
    final epoch = _generation;
    final parcel = selected!;
    await run('Buscando imágenes reales…', () async {
      final found = await (useLandsat ? landsat : sentinel).search(
        bounds: parcel.geometry.bounds,
        start: DateTime.utc(start.year, start.month, start.day),
        end: DateTime.utc(end.year, end.month, end.day, 23, 59, 59),
        maxCloud: maxCloud,
      );
      if (epoch != _generation) return;
      scenes = found;
      message = found.isEmpty
          ? 'No hay escenas en estas fechas. Prueba otro período.'
          : '${found.length} escenas (hasta 30 por consulta). La nubosidad es de la escena completa.';
    });
  }

  Future<void> analyze(Scene scene, Observation variable) async {
    final parcel = selected;
    if (parcel == null || editing) return;
    if (offline) {
      message = 'Abre un resultado guardado o conecta internet para analizar otra escena.';
      emit();
      return;
    }
    final epoch = _generation;
    await run('Leyendo bandas y calculando…', () async {
      final computed = await processor.process(
        scene: scene,
        parcel: parcel,
        observation: variable,
      );
      await documents.writeDocument(
        'result:${parcel.id}:${computed.id}',
        computed.data,
      );
      if (epoch != _generation) return;
      result = computed;
      comparison = null;
      pixel = null;
      results.removeWhere((r) => r.id == computed.id);
      results.add(computed);
      results.sort((a, b) => a.acquired.compareTo(b.acquired));
      showRaster = true;
      gibs = false;
      message =
          'Análisis guardado. ${computed.statistics.validPixels} píxeles válidos. ${(computed.data['warnings'] as List).join(' ')}';
    });
  }

  void cancel() {
    _generation++;
    processor.cancel();
    message = 'Cancelando tarea…';
    emit();
  }

  Future<void> loadWeather() async {
    final parcel = selected;
    if (parcel == null) return;
    if (offline) {
      message = weather == null ? 'No hay clima descargado para este terreno.' : 'Mostrando el clima guardado; puede no corresponder al período elegido.';
      emit();
      return;
    }
    final epoch = _generation;
    await run('Consultando NASA POWER…', () async {
      final data = await climate.daily(
        parcel.geometry.bounds.center,
        start,
        end,
      );
      await documents.writeDocument('power:${parcel.id}', data.data);
      if (epoch != _generation) return;
      weather = data;
      message = 'Datos regionales de NASA POWER guardados. No son una estación dentro del terreno.';
    });
  }

  Future<void> inspect(GeoPoint point) async {
    if (!advanced || result == null || editing || busy.isNotEmpty) return;
    await run('Leyendo píxel local…', () async {
      pixel = await processor.sample(result!, point);
    });
  }

  bool comparable(RasterResult a, RasterResult b) =>
      a.observation == b.observation &&
      a.parcelFingerprint == b.parcelFingerprint &&
      a.provider == b.provider &&
      a.resolution == b.resolution &&
      a.data['crs'] == b.data['crs'] &&
      jsonEncode(a.data['transform']) == jsonEncode(b.data['transform']);
  @override
  void dispose() {
    _disposed = true;
    processor.cancel();
    super.dispose();
  }
}
