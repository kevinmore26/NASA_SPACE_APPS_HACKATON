import 'dart:math' as math;

import 'package:field_core/field_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Map presentation contract v1: no provider URLs, scientific calculations or storage.
class MapTiles {
  final String template, attribution;
  final int maxNativeZoom;
  const MapTiles({
    required this.template,
    required this.attribution,
    this.maxNativeZoom = 19,
  });
}

class MapRaster {
  final ImageProvider image;
  final GeoBounds bounds;
  const MapRaster(this.image, this.bounds);
}

class FieldMapController {
  final MapController _map = MapController();
  bool _ready = false;
  VoidCallback? _pendingMove;

  void _attach() {
    _ready = true;
    final move = _pendingMove;
    _pendingMove = null;
    move?.call();
  }

  void locate(GeoPoint p, {double zoom = 15}) {
    if (!_ready) {
      _pendingMove = () => locate(p, zoom: zoom);
      return;
    }
    _map.move(LatLng(p.latitude, p.longitude), zoom);
  }

  /// Centers the view with the requested local radius on its shortest axis.
  void locateAround(GeoPoint p, {required double radiusMeters}) {
    if (!radiusMeters.isFinite || radiusMeters <= 0) {
      throw ArgumentError.value(radiusMeters, 'radiusMeters');
    }
    if (!_ready) {
      _pendingMove = () => locateAround(p, radiusMeters: radiusMeters);
      return;
    }
    final camera = _map.camera;
    final mapSize = math.max(1.0, camera.nonRotatedSize.shortestSide);
    final latitude = p.latitude * math.pi / 180;
    final metersPerWorld =
        2 * math.pi * SphericalMercator.r * math.cos(latitude);
    final worldSize = mapSize * metersPerWorld / (2 * radiusMeters);
    locate(p, zoom: camera.clampZoom(camera.crs.zoom(worldSize)));
  }

  void fit(GeoBounds b) {
    if (!_ready) {
      _pendingMove = () => fit(b);
      return;
    }
    if (_ready) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(b.south, b.west),
            LatLng(b.north, b.east),
          ),
          padding: const EdgeInsets.all(70),
          maxZoom: 18,
        ),
      );
    }
  }

  void zoom(double delta) {
    if (_ready) {
      _map.move(_map.camera.center, (_map.camera.zoom + delta).clamp(2, 19));
    }
  }

  void dispose() => _map.dispose();
}

class FieldMap extends StatefulWidget {
  final FieldMapController controller;
  final http.Client tileClient;
  final MapTiles? base, layer;
  final MapRaster? raster;
  final double opacity;
  final List<GeoPoint> vertices;
  final int? selectedVertex;
  final bool editing;
  final ValueChanged<GeoPoint> onTap;
  final ValueChanged<int> onVertex;
  const FieldMap({
    super.key,
    required this.controller,
    required this.tileClient,
    this.base,
    this.layer,
    this.raster,
    this.opacity = 1,
    required this.vertices,
    this.selectedVertex,
    required this.editing,
    required this.onTap,
    required this.onVertex,
  });
  @override
  State<FieldMap> createState() => _FieldMapState();
}

class _FieldMapState extends State<FieldMap> {
  late final NetworkTileProvider _tiles = NetworkTileProvider(
    httpClient: widget.tileClient,
    cachingProvider: const DisabledMapCachingProvider(),
  );
  String _coordinates = '';
  bool _tileError = false;
  Widget _layer(MapTiles source) => TileLayer(
    key: ValueKey(source.template),
    urlTemplate: source.template,
    tileProvider: _tiles,
    userAgentPackageName: 'org.nasafieldshift.app',
    maxNativeZoom: source.maxNativeZoom,
    maxZoom: 19,
    panBuffer: 0,
    errorTileCallback: (tile, error, stack) {
      if (!_tileError && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _tileError = true);
        });
      }
    },
  );
  @override
  void didUpdateWidget(covariant FieldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer?.template != widget.layer?.template ||
        oldWidget.base != widget.base) {
      _tileError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    String t(String en, String es) => spanish ? es : en;
    final points = widget.vertices
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.controller._map,
          options: MapOptions(
            initialCenter: const LatLng(-13.718, -76.148),
            initialZoom: 13,
            minZoom: 2,
            maxZoom: 19,
            backgroundColor: const Color(0xffe9eddf),
            onMapReady: widget.controller._attach,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, p) => widget.onTap(GeoPoint(p.latitude, p.longitude)),
            onPositionChanged: (camera, gesture) {
              setState(
                () => _coordinates =
                    '${camera.center.latitude.toStringAsFixed(5)}, ${camera.center.longitude.toStringAsFixed(5)}',
              );
            },
          ),
          children: [
            if (widget.base != null) _layer(widget.base!),
            if (widget.layer != null)
              Opacity(opacity: widget.opacity, child: _layer(widget.layer!)),
            if (widget.raster != null)
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: LatLngBounds(
                      LatLng(
                        widget.raster!.bounds.south,
                        widget.raster!.bounds.west,
                      ),
                      LatLng(
                        widget.raster!.bounds.north,
                        widget.raster!.bounds.east,
                      ),
                    ),
                    imageProvider: widget.raster!.image,
                    opacity: widget.opacity,
                    filterQuality: FilterQuality.none,
                  ),
                ],
              ),
            if (points.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: points,
                    color: widget.raster == null
                        ? const Color(0x58bad264)
                        : Colors.transparent,
                    borderColor: const Color(0xff183e2d),
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            if (points.length == 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: const Color(0xff143d29),
                    strokeWidth: 3,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (var i = 0; i < points.length; i++)
                  Marker(
                    point: points[i],
                    width: 44,
                    height: 44,
                    child: Semantics(
                      label: t(
                        'Point ${i + 1}. Select to move',
                        'Punto ${i + 1}. Seleccionar para mover',
                      ),
                      button: true,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: i == widget.selectedVertex
                              ? const Color(0xffa95126)
                              : const Color(0xff23523a),
                          disabledBackgroundColor: const Color(0x3823523a),
                          disabledForegroundColor: const Color(0xff183e2d),
                          shape: const CircleBorder(),
                        ),
                        onPressed: widget.editing
                            ? () => widget.onVertex(i)
                            : null,
                        child: Text('${i + 1}'),
                      ),
                    ),
                  ),
              ],
            ),
            const Scalebar(
              alignment: Alignment.bottomLeft,
              padding: EdgeInsets.fromLTRB(18, 10, 10, 54),
            ),
          ],
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'zoomIn',
                tooltip: t('Zoom in', 'Acercar mapa'),
                onPressed: () => widget.controller.zoom(1),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoomOut',
                tooltip: t('Zoom out', 'Alejar mapa'),
                onPressed: () => widget.controller.zoom(-1),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
        if (_tileError)
          Positioned(
            left: 16,
            top: 16,
            right: 78,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t(
                          'Part of the base map is unavailable. You can still draw.',
                          'Mapa de fondo incompleto. Puedes seguir editando.',
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: t('Dismiss notice', 'Cerrar aviso'),
                      onPressed: () => setState(() => _tileError = false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(
            color: Colors.white.withValues(alpha: 0.95),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${[widget.base?.attribution, widget.layer?.attribution].whereType<String>().join(' · ')}   |   WGS84 $_coordinates',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
