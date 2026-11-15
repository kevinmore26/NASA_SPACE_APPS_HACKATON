import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'crop_suitability.dart';
import 'field_language.dart';
import 'parcel_observations.dart';

enum FieldPage {
  home('Inicio'),
  parcels('Mis terrenos'),
  map('Explorar mapa'),
  analysis('Análisis'),
  rotations('Planificador'),
  settings('Configuración');

  const FieldPage(this.label);
  final String label;
}

enum NetworkStatus { unverified, reachable, failed }

/// App orchestration. Domain contracts are constructor-injected.
class FieldController extends ChangeNotifier {
  final ParcelRepository parcels;
  final LocalDocuments documents;
  final SceneCatalog sentinel, landsat;
  final ClimateProvider climate;
  final RasterProcessor processor;
  final CropSuitabilityClient? cropSuitabilityClient;

  FieldController({
    required this.parcels,
    required this.documents,
    required this.sentinel,
    required this.landsat,
    required this.climate,
    required this.processor,
    this.cropSuitabilityClient,
  });

  List<Parcel> saved = [];
  Parcel? selected;
  List<GeoPoint> vertices = [];
  final List<List<GeoPoint>> _undo = [];
  final Map<String, ParcelObservations> _archive = {};
  final _cropReviews = <String, ({String input, CropSuitability result})>{};
  List<Scene> scenes = [];
  Observation analysisVariable = Observation.rgb;
  bool showingWeather = false;
  RasterResult? result, comparison;
  PixelSample? pixel;
  bool editing = false,
      advanced = false,
      offline = false,
      gibs = false,
      showRaster = true,
      useLandsat = false;
  String base = 'roads', message = '', busy = '';
  final language = ValueNotifier(FieldLanguage.english);
  String t(String english, String spanish) =>
      language.value.pick(english, spanish);

  Future<void> setLanguage(FieldLanguage value) async {
    if (language.value == value || isBusy) return;
    language.value = value;
    feedback('');
    await preferences();
  }

  void setPeriod(DateTime from, DateTime to) {
    if (isBusy) return;
    start = from;
    end = to;
    scenes = [];
    feedback('');
  }

  FieldPage page = FieldPage.home;
  NetworkStatus networkStatus = NetworkStatus.unverified;
  bool hasError = false;
  bool _canCancel = false;
  bool _cancelled = false;
  bool _disposed = false;
  int? selectedVertex;
  double opacity = 0.85, maxCloud = 80;
  DateTime start = DateTime.now().subtract(const Duration(days: 120));
  DateTime end = DateTime.now().subtract(const Duration(days: 7));
  DateTime gibsDate = DateTime.now().subtract(const Duration(days: 2));

  bool get isBusy => busy.isNotEmpty;
  bool get canCancel => _canCancel && !_cancelled;
  ParcelObservations observationsFor(Parcel parcel) =>
      _archive[parcel.id] ?? const ParcelObservations();
  ParcelObservations get observations => selected == null
      ? const ParcelObservations()
      : observationsFor(selected!);
  List<RasterResult> get results => observations.rasters;
  ClimateSeries? get weather => observations.climate;
  CropSuitability? get cropReview {
    final parcel = selected;
    if (parcel == null) return null;
    final savedReview = _cropReviews[parcel.id];
    return savedReview?.input == jsonEncode(cropSuitabilityInputs(parcel))
        ? savedReview?.result
        : null;
  }

  void emit() {
    if (!_disposed) notifyListeners();
  }

  void feedback(String text, {bool error = false}) {
    message = text;
    hasError = error;
    emit();
  }

  Future<void> initialize() async {
    try {
      saved = await parcels.listParcels();
      final p = await documents.readDocument('preferences-v1');
      if (p != null) {
        language.value = FieldLanguage.fromCode(p['language']);
        advanced = p['advanced'] == true;
        offline = p['offline'] == true;
        base = p['base'] == 'none' ? 'none' : 'roads';
        gibs = p['gibs'] == true;
        opacity = ((p['opacity'] as num?)?.toDouble() ?? .85).clamp(0, 1);
        gibsDate =
            DateTime.tryParse(p['gibsDate'] as String? ?? '') ?? gibsDate;
      }
      final activeId = p?['activeParcelId'];
      final recent = [...saved]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      selected =
          saved.where((p) => p.id == activeId).firstOrNull ??
          recent.firstOrNull;
      vertices = List.of(selected?.geometry.vertices ?? []);
      await Future.wait([
        for (final parcel in saved)
          ParcelObservations.read(documents, parcel).then((entry) {
            _archive[parcel.id] = entry;
          }),
        if (cropSuitabilityClient != null)
          for (final parcel in saved) _openCropReview(parcel),
      ]);
    } catch (_) {
      message = t(
        'Some saved data could not be opened. Check access to local storage.',
        'No se pudieron recuperar algunos datos locales. Comprueba el acceso al disco.',
      );
      hasError = true;
    }
    emit();
  }

  Future<void> _preferenceWrites = Future.value();
  Future<void> preferences() {
    final snapshot = <String, dynamic>{
      'schema': 1,
      'language': language.value.code,
      'advanced': advanced,
      'offline': offline,
      'base': base,
      'gibs': gibs,
      'opacity': opacity,
      'gibsDate': gibsDate.toIso8601String(),
      'activeParcelId': selected?.id,
    };
    _preferenceWrites = _preferenceWrites.then((_) async {
      try {
        await documents.writeDocument('preferences-v1', snapshot);
      } catch (_) {
        feedback(
          t(
            'Could not save your settings.',
            'No se pudo guardar la configuración.',
          ),
          error: true,
        );
      }
    });
    return _preferenceWrites;
  }

  void goTo(FieldPage next) {
    if (page == next) return;
    page = next;
    if (!isBusy) {
      message = '';
      hasError = false;
    }
    emit();
  }

  // Preserve the V1 entry point used by desktop verification and callers.
  void navigate(String next) {
    final destination = FieldPage.values
        .where((p) => p.label == next)
        .firstOrNull;
    if (destination != null) goTo(destination);
  }

  void viewObservations({bool weather = false}) {
    showingWeather = weather;
    if (page == FieldPage.analysis) {
      emit();
    } else {
      goTo(FieldPage.analysis);
    }
  }

  void newParcel() {
    if (isBusy) return;
    selected = null;
    vertices = [];
    _resetSelection();
    editing = true;
    page = FieldPage.map;
    feedback(
      t(
        'Click the corners of your field on the map.',
        'Marca las esquinas de tu terreno sobre el mapa.',
      ),
    );
  }

  Future<void> select(
    Parcel parcel, {
    FieldPage destination = FieldPage.map,
  }) async {
    if (isBusy) return;
    if (selected?.id == parcel.id && !editing) {
      goTo(destination);
      return;
    }
    selected = parcel;
    vertices = List.of(parcel.geometry.vertices);
    _resetSelection();
    page = destination;
    if (!_archive.containsKey(parcel.id)) {
      await run(
        t('Opening saved data…', 'Abriendo datos guardados…'),
        () async {
          _archive[parcel.id] = await ParcelObservations.read(
            documents,
            parcel,
          );
        },
      );
    } else {
      feedback('');
    }
    await preferences();
  }

  void _resetSelection() {
    _undo.clear();
    selectedVertex = null;
    editing = false;
    result = null;
    comparison = null;
    pixel = null;
    scenes = [];
  }

  void edit() {
    if (selected == null || isBusy) return;
    editing = true;
    _undo.clear();
    result = null;
    comparison = null;
    pixel = null;
    feedback(
      t(
        'Select a numbered point, then click where it should go.',
        'Selecciona un punto numerado y luego su nueva posición.',
      ),
    );
  }

  void cancelEdit() {
    vertices = List.of(selected?.geometry.vertices ?? []);
    editing = false;
    selectedVertex = null;
    _undo.clear();
    feedback(t('Changes discarded.', 'Cambios descartados.'));
  }

  void tap(GeoPoint p) {
    if (!editing || isBusy) return;
    _undo.add(List.of(vertices));
    if (selectedVertex != null) {
      vertices = List.of(vertices)..[selectedVertex!] = p;
      selectedVertex = null;
    } else {
      vertices = [...vertices, p];
    }
    feedback('');
  }

  void chooseVertex(int i) {
    if (!editing || isBusy) return;
    selectedVertex = i;
    feedback(
      t(
        'Click the new position for point ${i + 1}.',
        'Marca la nueva posición del punto ${i + 1}.',
      ),
    );
  }

  void undo() {
    if (_undo.isEmpty || isBusy) return;
    vertices = _undo.removeLast();
    selectedVertex = null;
    emit();
  }

  void removeVertex() {
    if (selectedVertex == null || isBusy) return;
    _undo.add(List.of(vertices));
    vertices = List.of(vertices)..removeAt(selectedVertex!);
    selectedVertex = null;
    emit();
  }

  Future<bool> save(String name, FarmRecord farm) =>
      _saveParcel(name, farm, vertices);

  Future<bool> saveFarm(FarmRecord farm) async {
    final parcel = selected;
    if (parcel == null || editing) return false;
    return _saveParcel(parcel.name, farm, parcel.geometry.vertices);
  }

  Future<bool> _saveParcel(
    String name,
    FarmRecord farm,
    List<GeoPoint> points,
  ) => run(t('Saving field…', 'Guardando terreno…'), () async {
    final previous = selected;
    final parcel = Parcel(
      id: previous?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      geometry: FieldGeometry(points),
      farm: farm,
      updatedAt: DateTime.now(),
    );
    final geometryChanged =
        previous != null &&
        jsonEncode(previous.geometry.toJson()) !=
            jsonEncode(parcel.geometry.toJson());
    await parcels.saveParcel(parcel);
    saved = [
      for (final other in saved)
        if (other.id != parcel.id) other,
      parcel,
    ];
    selected = parcel;
    vertices = List.of(parcel.geometry.vertices);
    editing = false;
    selectedVertex = null;
    _undo.clear();
    if (geometryChanged) {
      _resetSelection();
      _archive[parcel.id] = await ParcelObservations.read(documents, parcel);
    }
    await preferences();
    message = t('Field saved.', 'Terreno guardado en este equipo.');
  });

  Future<void> deleteSelected() async {
    final parcel = selected;
    if (parcel == null) return;
    await run(t('Removing field…', 'Eliminando terreno…'), () async {
      await parcels.deleteParcel(parcel.id);
      saved = saved.where((p) => p.id != parcel.id).toList();
      _archive.remove(parcel.id);
      _cropReviews.remove(parcel.id);
      selected = null;
      vertices = [];
      _resetSelection();
      page = FieldPage.parcels;
      await preferences();
      message = t(
        'Field removed. Archived observations remain on this device.',
        'Terreno eliminado. Los análisis archivados se conservan.',
      );
    });
  }

  Future<bool> run(
    String label,
    Future<void> Function() task, {
    bool cancelable = false,
    bool network = false,
  }) async {
    if (isBusy) return false;
    busy = label;
    message = '';
    hasError = false;
    _canCancel = cancelable;
    _cancelled = false;
    emit();
    try {
      await task();
      if (network && !_cancelled) networkStatus = NetworkStatus.reachable;
      return !_cancelled;
    } catch (e) {
      if (!_cancelled) {
        hasError = true;
        if (network &&
            (e is SocketException ||
                e is http.ClientException ||
                e is TimeoutException)) {
          networkStatus = NetworkStatus.failed;
          message = t(
            'The service did not respond. Check your connection and try again.',
            'El servicio no respondió. Revisa la conexión y vuelve a intentar.',
          );
        } else {
          final details = e.toString().replaceFirst(
            RegExp(r'^(Bad state: |Invalid argument\(s\): |Exception: )'),
            '',
          );
          message = advanced
              ? details
              : t(
                  'Could not finish that action. Try again.',
                  'No se pudo completar la acción. Intenta de nuevo.',
                );
        }
      }
      return false;
    } finally {
      if (_cancelled) {
        message = t('Analysis canceled.', 'Procesamiento cancelado.');
      }
      busy = '';
      _canCancel = false;
      emit();
    }
  }

  Future<void> searchScenes() async {
    final parcel = selected;
    if (parcel == null || editing) {
      feedback(
        t(
          'Save the field boundary first.',
          'Guarda primero los límites del terreno.',
        ),
        error: true,
      );
      return;
    }
    if (offline) {
      feedback(
        t(
          'Connect to the internet to find new images. You can still open saved results.',
          'Conecta internet para buscar imágenes nuevas. Tus resultados guardados siguen disponibles.',
        ),
      );
      return;
    }
    final from = DateTime.utc(start.year, start.month, start.day);
    final to = DateTime.utc(end.year, end.month, end.day, 23, 59, 59);
    if (to.isBefore(from)) {
      feedback(
        t(
          'The end date must be on or after the start date.',
          'La fecha final debe ser igual o posterior a la inicial.',
        ),
        error: true,
      );
      return;
    }
    await run(
      t('Looking for satellite images…', 'Buscando imágenes satelitales…'),
      () async {
        scenes = await (useLandsat ? landsat : sentinel).search(
          bounds: parcel.geometry.bounds,
          start: from,
          end: to,
          maxCloud: maxCloud,
        );
        message = scenes.isEmpty
            ? t(
                'No images found. Try a different period or a higher cloud limit.',
                'No hay escenas en estas fechas. Prueba otro período.',
              )
            : t(
                'Found ${scenes.length} images.',
                '${scenes.length} escenas encontradas. La nubosidad corresponde a la imagen completa.',
              );
      },
      network: true,
    );
  }

  Future<void> analyze(Scene scene, Observation variable) async {
    final parcel = selected;
    if (parcel == null || editing) return;
    if (offline) {
      feedback(
        t(
          'Open a saved result or connect to analyze another image.',
          'Abre un resultado guardado o conecta internet para analizar otra escena.',
        ),
      );
      return;
    }
    await run(
      t('Processing the image for your field…', 'Leyendo bandas y calculando…'),
      () async {
        final computed = await processor.process(
          scene: scene,
          parcel: parcel,
          observation: variable,
        );
        if (_cancelled) return;
        _canCancel = false;
        busy = t('Saving observation…', 'Guardando resultado…');
        emit();
        await documents.writeDocument(
          'result:${parcel.id}:${computed.id}',
          computed.data,
        );
        final previous = observations;
        final rasters = [
          ...previous.rasters.where((r) => r.id != computed.id),
          computed,
        ]..sort((a, b) => a.acquired.compareTo(b.acquired));
        _archive[parcel.id] = ParcelObservations(
          rasters: List.unmodifiable(rasters),
          climate: previous.climate,
          incomplete: previous.incomplete,
        );
        _showResult(computed);
        if (computed.quality == RasterQuality.unusable) {
          message = t(
            'This image has no usable data for your field. Try a different date.',
            'Sin datos utilizables. Se guardó el diagnóstico de esta escena.',
          );
          hasError = true;
        } else if (computed.quality == RasterQuality.limited) {
          message = t(
            'Saved. Only part of the field has usable image data.',
            'Resultado limitado guardado. Revisa la cobertura antes de interpretarlo.',
          );
        } else {
          message = t(
            'Observation saved.',
            'Resultado guardado en este equipo.',
          );
        }
      },
      cancelable: true,
    );
  }

  void cancel() {
    if (!canCancel) return;
    _cancelled = true;
    processor.cancel();
    feedback(t('Canceling analysis…', 'Cancelando procesamiento…'));
  }

  void _showResult(RasterResult value) {
    result = value;
    comparison = null;
    pixel = null;
    showRaster = true;
    gibs = false;
  }

  void openResult(RasterResult value) {
    _showResult(value);
    emit();
  }

  void swapComparison() {
    final other = comparison;
    if (other == null) return;
    comparison = result;
    result = other;
    pixel = null;
    emit();
  }

  Future<void> loadWeather() async {
    final parcel = selected;
    if (parcel == null || editing) return;
    if (offline) {
      feedback(
        weather == null
            ? t(
                'This field has no saved weather data.',
                'No hay clima descargado para este terreno.',
              )
            : t(
                'Showing saved regional weather.',
                'Mostrando clima regional guardado.',
              ),
      );
      return;
    }
    final point = parcel.geometry.bounds.center;
    await run(
      t('Getting regional weather from NASA POWER…', 'Consultando NASA POWER…'),
      () async {
        final data = await climate.daily(
          point,
          DateTime.utc(start.year, start.month, start.day),
          DateTime.utc(end.year, end.month, end.day),
        );
        await documents.writeDocument('power:${parcel.id}', {
          ...data.data,
          'fieldShiftQueryPoint': point.toJson(),
        });
        final previous = observations;
        _archive[parcel.id] = ParcelObservations(
          rasters: previous.rasters,
          climate: data,
          incomplete: previous.incomplete,
        );
        message = t(
          'Weather history saved.',
          'Datos regionales de NASA POWER guardados.',
        );
      },
      network: true,
    );
  }

  Future<void> inspect(GeoPoint point) async {
    final current = result;
    if (!advanced ||
        current == null ||
        editing ||
        isBusy ||
        current.quality == RasterQuality.unusable) {
      return;
    }
    await run(
      t('Looking up the selected pixel…', 'Leyendo píxel local…'),
      () async {
        pixel = await processor.sample(current, point);
      },
    );
  }

  Future<void> _openCropReview(Parcel parcel) async {
    try {
      final entry = await documents.readDocument(
        'crop-suitability:${parcel.id}',
      );
      if (entry == null) return;
      _cropReviews[parcel.id] = (
        input: entry['input'] as String,
        result: CropSuitability.fromJson(
          entry['result'] as Map<String, dynamic>,
        ),
      );
    } on Object {
      // Ignore a malformed optional record when opening a field.
      _cropReviews.remove(parcel.id);
    }
  }

  Future<void> evaluateCrops() async {
    final parcel = selected;
    final client = cropSuitabilityClient;
    if (parcel == null || client == null || editing || offline) return;
    final inputs = cropSuitabilityInputs(parcel);
    final inputKey = jsonEncode(inputs);
    await run(t('Evaluating crops…', 'Evaluando cultivos…'), () async {
      final review = await client.evaluate(inputs);
      await documents.writeDocument('crop-suitability:${parcel.id}', {
        'input': inputKey,
        'result': review.data,
      });
      _cropReviews[parcel.id] = (input: inputKey, result: review);
    }, network: true);
  }

  bool comparable(RasterResult a, RasterResult b) =>
      a.quality != RasterQuality.unusable &&
      b.quality != RasterQuality.unusable &&
      a.observation == b.observation &&
      a.parcelFingerprint == b.parcelFingerprint &&
      a.provider == b.provider &&
      a.product == b.product &&
      a.data['method'] == b.data['method'] &&
      a.resolution == b.resolution &&
      a.data['crs'] == b.data['crs'] &&
      jsonEncode(a.data['transform']) == jsonEncode(b.data['transform']);

  @override
  void dispose() {
    _disposed = true;
    processor.cancel();
    language.dispose();
    super.dispose();
  }
}
