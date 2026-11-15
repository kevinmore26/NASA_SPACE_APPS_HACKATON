import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:field_maps/field_maps.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../application/field_controller.dart';
import 'analysis_page.dart';
import 'field_strings.dart';
import 'workspace_widgets.dart';

class MapWorkspace extends StatefulWidget {
  final FieldController model;
  final http.Client tiles;
  final bool analyzing;
  final VoidCallback save, delete;
  const MapWorkspace({
    super.key,
    required this.model,
    required this.tiles,
    required this.analyzing,
    required this.save,
    required this.delete,
  });

  @override
  State<MapWorkspace> createState() => _MapWorkspaceState();
}

class _MapWorkspaceState extends State<MapWorkspace> {
  final _map = FieldMapController();
  final _coordinates = TextEditingController();
  FieldController get m => widget.model;
  FieldGeometry? _geometry;
  String? _resultPath;
  Future<bool>? _preview;
  bool _fitOnEntry = true;

  static const _roads = MapTiles(
    template: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors · openstreetmap.org/copyright',
  );

  @override
  void dispose() {
    _map.dispose();
    _coordinates.dispose();
    super.dispose();
  }

  void _locate() {
    try {
      final parts = _coordinates.text.trim().split(RegExp(r'[,;\s]+'));
      if (parts.length != 2) throw const FormatException();
      _map.locate(GeoPoint(double.parse(parts[0]), double.parse(parts[1])));
      m.feedback(context.t('Map centered.', 'Mapa centrado.'));
    } catch (_) {
      m.feedback(
        context.t(
          'Enter latitude and longitude like this: -6.724, -79.777',
          'Escribe la latitud y la longitud así: -6.724, -79.777',
        ),
        error: true,
      );
    }
  }

  void _fit() {
    final geometry = m.selected?.geometry;
    if (geometry != null) _map.fit(geometry.bounds);
  }

  @override
  Widget build(BuildContext context) {
    final geometry = m.selected?.geometry;
    if (_fitOnEntry || (geometry != null && _geometry != geometry)) {
      _geometry = geometry;
      _fitOnEntry = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
    final path = m.result?.previewPath;
    if (path != _resultPath) {
      _resultPath = path;
      _preview = path == null ? null : File(path).exists();
    }
    return FutureBuilder<bool>(
      future: _preview,
      builder: (context, preview) {
        final havePreview =
            path != null &&
            preview.connectionState == ConnectionState.done &&
            preview.data == true;
        final map = Surface(
          padding: EdgeInsets.zero,
          child: FieldMap(
            controller: _map,
            tileClient: widget.tiles,
            base: m.base == 'roads' ? _roads : null,
            layer: m.gibs
                ? MapTiles(
                    template: GibsLayer.template(m.gibsDate),
                    attribution: GibsLayer.attribution,
                    maxNativeZoom: 9,
                  )
                : null,
            raster:
                havePreview &&
                    m.showRaster &&
                    !(widget.analyzing && m.showingWeather)
                ? MapRaster(FileImage(File(path)), m.result!.bounds)
                : null,
            opacity: m.opacity,
            vertices: m.vertices,
            selectedVertex: m.selectedVertex,
            editing: m.editing,
            onTap: m.editing ? m.tap : m.inspect,
            onVertex: m.chooseVertex,
          ),
        );
        final panel = Surface(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            key: PageStorageKey(
              widget.analyzing
                  ? (m.showingWeather ? 'weather-panel' : 'analysis-panel')
                  : 'map-panel',
            ),
            padding: const EdgeInsets.all(16),
            child: widget.analyzing
                ? AnalysisPage(
                    model: m,
                    previewMissing:
                        path == null ||
                        (preview.connectionState == ConnectionState.done &&
                            preview.data != true),
                    fitResult: () {
                      final result = m.result;
                      if (result != null) _map.fit(result.bounds);
                    },
                  )
                : _explore(context),
          ),
        );
        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 725;
            return Padding(
              padding: EdgeInsets.all(wide ? 18 : 10),
              child: Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: wide ? 1 : 5, child: map),
                  SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 10),
                  if (wide)
                    SizedBox(
                      width: c.maxWidth >= 1050 ? 430 : 341,
                      child: panel,
                    )
                  else
                    Expanded(flex: 4, child: panel),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _explore(BuildContext context) {
    final parcel = m.selected;
    final issue = m.editing ? FieldGeometry.validationIssue(m.vertices) : null;
    final style = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(context.t('Field map', 'Mapa del terreno')),
        if (m.saved.isNotEmpty) ...[
          ParcelPicker(m, FieldPage.map),
          const SizedBox(height: 12),
        ],
        if (m.editing) ...[
          Text(
            context.t('Draw the boundary', 'Marca los límites'),
            style: style,
          ),
          const SizedBox(height: 5),
          Text(
            context.t(
              'Click around the edges of the field. To move a corner, click its number and then its new position.',
              'Haz clic en cada esquina del terreno. Para mover una, haz clic en su número y luego en su nueva posición.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            issue == null
                ? '${context.number(FieldGeometry(m.vertices).hectares)} ha'
                : context.geometryIssue(issue),
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: m.isBusy || issue != null ? null : widget.save,
            icon: const Icon(Icons.save_outlined),
            label: Text(context.t('Save field', 'Guardar terreno')),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: m.isBusy || m.vertices.isEmpty ? null : m.undo,
                icon: const Icon(Icons.undo),
                label: Text(context.t('Undo', 'Deshacer')),
              ),
              if (m.selectedVertex != null)
                TextButton.icon(
                  onPressed: m.isBusy ? null : m.removeVertex,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(context.t('Remove point', 'Quitar punto')),
                ),
              TextButton(
                onPressed: m.isBusy ? null : m.cancelEdit,
                child: Text(context.t('Cancel drawing', 'Cancelar dibujo')),
              ),
            ],
          ),
        ] else ...[
          if (parcel != null) ...[
            Text(parcel.name, style: style),
            Text(
              context.t(
                'About ${context.number(parcel.geometry.hectares)} ha',
                'Unas ${context.number(parcel.geometry.hectares)} ha',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => m.viewObservations(),
              icon: const Icon(Icons.insights_outlined),
              label: Text(context.t('View observations', 'Ver observaciones')),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: _fit,
                  icon: const Icon(Icons.my_location_outlined),
                  label: Text(context.t('Center map', 'Centrar mapa')),
                ),
                OutlinedButton.icon(
                  onPressed: m.isBusy ? null : m.edit,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: Text(context.t('Edit boundary', 'Editar límites')),
                ),
                TextButton(
                  onPressed: m.isBusy ? null : widget.save,
                  child: Text(
                    context.t('Edit information', 'Editar información'),
                  ),
                ),
                TextButton(
                  onPressed: m.isBusy ? null : widget.delete,
                  child: Text(context.t('Remove field', 'Eliminar terreno')),
                ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          OutlinedButton.icon(
            onPressed: m.isBusy ? null : m.newParcel,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(
              parcel == null
                  ? context.t('Mark a field', 'Marcar un terreno')
                  : context.t('Add another field', 'Añadir otro terreno'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        ExpansionTile(
          key: const PageStorageKey('map-coordinates-expansion'),
          tilePadding: EdgeInsets.zero,
          title: Text(context.t('Go to coordinates', 'Ir a coordenadas')),
          children: [
            TextField(
              key: const PageStorageKey('map-coordinates-input'),
              controller: _coordinates,
              decoration: InputDecoration(
                labelText: context.t(
                  'Latitude, longitude',
                  'Latitud, longitud',
                ),
                hintText: '-6.724, -79.777',
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _locate(),
            ),
            OutlinedButton.icon(
              onPressed: _locate,
              icon: const Icon(Icons.near_me_outlined),
              label: Text(
                context.t('Center on this location', 'Centrar en este lugar'),
              ),
            ),
          ],
        ),
        ExpansionTile(
          key: const PageStorageKey('map-layers-expansion'),
          tilePadding: EdgeInsets.zero,
          title: Text(context.t('Map layers', 'Capas del mapa')),
          children: [MapLayers(m)],
        ),
      ],
    );
  }
}

class MapLayers extends StatelessWidget {
  final FieldController model;
  const MapLayers(this.model, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey(model.base),
        isExpanded: true,
        initialValue: model.base,
        decoration: InputDecoration(
          labelText: context.t('Base map', 'Mapa de fondo'),
        ),
        items: [
          DropdownMenuItem(
            value: 'roads',
            child: Text(
              context.t('OpenStreetMap · Roads', 'OpenStreetMap · Caminos'),
            ),
          ),
          DropdownMenuItem(
            value: 'none',
            child: Text(context.t('Field boundaries only', 'Solo mis límites')),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          model.base = value;
          model.emit();
          model.preferences();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.t('Regional satellite layer', 'Vista satelital regional'),
        ),
        subtitle: Text(
          context.t(
            'NASA GIBS · MODIS RGB · 250 m',
            'NASA GIBS · MODIS RGB · 250 m · Capa visual',
          ),
        ),
        value: model.gibs,
        onChanged: (value) {
          model.gibs = value;
          model.emit();
          model.preferences();
        },
      ),
      if (model.gibs)
        OutlinedButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: model.gibsDate,
              firstDate: DateTime(2000, 2, 24),
              lastDate: DateTime.now(),
            );
            if (date == null || !context.mounted) return;
            model.gibsDate = date;
            model.emit();
            model.preferences();
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            context.t(
              'NASA image date · ${context.dateLabel(model.gibsDate)}',
              'Fecha de capa NASA · ${context.dateLabel(model.gibsDate)}',
            ),
          ),
        ),
      if (model.result != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.t('Show saved image on map', 'Mostrar resultado en mapa'),
          ),
          value: model.showRaster,
          onChanged: (value) {
            model.showRaster = value;
            model.emit();
          },
        ),
      if (model.gibs || model.result != null) ...[
        Text(context.t('Layer opacity', 'Opacidad de la capa')),
        Slider(
          value: model.opacity,
          divisions: 10,
          label: '${(model.opacity * 100).round()}%',
          onChanged: (value) {
            model.opacity = value;
            model.emit();
          },
          onChangeEnd: (_) => model.preferences(),
        ),
      ],
      if (model.gibs)
        Text(
          context.t(
            'This layer helps you find a place. The observations above use the original satellite bands.',
            'Vista RGB para orientarte. Los índices del análisis se calculan con las bandas originales.',
          ),
          style: const TextStyle(color: muted),
        ),
    ],
  );
}
