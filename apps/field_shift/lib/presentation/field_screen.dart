import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:field_maps/field_maps.dart';
import 'package:field_nasa/field_nasa.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../application/field_controller.dart';
import 'farm_dialog.dart';
import 'result_panel.dart';

class FieldScreen extends StatefulWidget {
  final FieldController model;
  final http.Client tiles;
  final String dataDirectory;
  const FieldScreen({
    super.key,
    required this.model,
    required this.tiles,
    required this.dataDirectory,
  });
  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen> {
  final map = FieldMapController();
  final coordinates = TextEditingController();
  Observation variable = Observation.rgb;
  FieldController get m => widget.model;
  static const roads = MapTiles(
    template: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors · openstreetmap.org/copyright',
  );
  @override
  void dispose() {
    map.dispose();
    coordinates.dispose();
    super.dispose();
  }

  void locate() {
    try {
      final parts = coordinates.text.trim().split(RegExp(r'[,;\s]+'));
      if (parts.length != 2) throw const FormatException();
      map.locate(GeoPoint(double.parse(parts[0]), double.parse(parts[1])));
      m.message = 'Ubicación encontrada. Marca los límites de tu terreno.';
    } catch (_) {
      m.message =
          'Escribe latitud y longitud en grados, por ejemplo: -13.718, -76.148';
    }
    m.emit();
  }

  Future<void> save() async {
    final error = FieldGeometry.validate(m.vertices);
    if (error != null) {
      m.message = error;
      m.emit();
      return;
    }
    final data = await showDialog<({String name, FarmRecord farm})>(
      context: context,
      builder: (_) => FarmDialog(parcel: m.selected),
    );
    if (data != null) await m.save(data.name, data.farm);
  }

  Future<void> delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este terreno?'),
        content: Text(
          'Se eliminarán los límites y el registro de ${m.selected!.name} de este equipo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conservar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar terreno'),
          ),
        ],
      ),
    );
    if (yes == true) await m.deleteSelected();
  }

  Future<void> pickDate(bool first) async {
    final d = await showDatePicker(
      context: context,
      initialDate: first ? m.start : m.end,
      firstDate: DateTime(2013),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      if (first) {
        m.start = d;
      } else {
        m.end = d;
      }
      m.emit();
    }
  }

  Widget action(
    String text,
    IconData icon,
    VoidCallback? onPressed, {
    bool primary = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(
      width: double.infinity,
      child: primary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(text),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(text),
            ),
    ),
  );
  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle),
      ],
    ),
  );
  Widget navigation() => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final item in [
        ('Inicio', Icons.home_outlined),
        ('Mis terrenos', Icons.grass),
        ('Explorar mapa', Icons.map_outlined),
        ('Análisis', Icons.insights),
        ('Configuración', Icons.settings_outlined),
      ])
        TextButton.icon(
          onPressed: () => m.navigate(item.$1),
          style: TextButton.styleFrom(
            backgroundColor: m.page == item.$1 ? const Color(0xffdcecdf) : null,
            foregroundColor: const Color(0xff164b32),
          ),
          icon: Icon(item.$2, size: 20),
          label: Text(item.$1),
        ),
    ],
  );
  Widget controls() {
    final disabled = m.busy.isNotEmpty;
    if (m.page == 'Configuración') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            'A tu manera',
            'Tus terrenos y resultados se guardan en este equipo.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Modo avanzado'),
            subtitle: const Text('Bandas, fórmulas y valores por píxel'),
            value: m.advanced,
            onChanged: (v) {
              m.advanced = v;
              m.emit();
              m.preferences();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Trabajar sin internet'),
            subtitle: const Text(
              'Solo mapas ya consultados y resultados guardados',
            ),
            value: m.offline,
            onChanged: disabled
                ? null
                : (v) {
                    m.offline = v;
                    m.emit();
                    m.preferences();
                  },
          ),
          const Divider(),
          const Text(
            'Caché de mapas: hasta 128 MB. Se conservan las zonas consultadas, no mapas completos. Recursos antiguos pueden reutilizarse sin conexión.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Los análisis se conservan hasta 512 MB; los más antiguos pueden retirarse. Los terrenos y registros nunca se eliminan al limpiar la caché.',
          ),
          const SizedBox(height: 16),
          SelectableText(
            'Datos locales:\n${widget.dataDirectory}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          action(
            'Licencias de software',
            Icons.info_outline,
            () => showLicensePage(
              context: context,
              applicationName: 'NASA Field Shift',
              applicationVersion: '0.1.0',
            ),
          ),
          const Text(
            'NASA/USGS y ESA/Copernicus son las fuentes de observación. Esta aplicación no está certificada por ellas. No sustituye una visita de campo.',
          ),
        ],
      );
    }
    if (m.page == 'Mis terrenos') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            'Mis terrenos',
            'Guardados aquí. Disponibles aunque no tengas internet.',
          ),
          action(
            'Marcar otro terreno',
            Icons.add_location_alt_outlined,
            disabled ? null : m.newParcel,
            primary: true,
          ),
          if (m.saved.isEmpty)
            const Text(
              'Todavía no guardaste terrenos. Empieza marcando uno en el mapa.',
            ),
          for (final p in m.saved)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const Icon(Icons.landscape_outlined),
                title: Text(p.name),
                subtitle: Text(
                  '${p.geometry.hectares.toStringAsFixed(2)} ha · ${p.farm.crop.isEmpty ? 'Sin cultivo registrado' : p.farm.crop}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: disabled
                    ? null
                    : () async {
                        await m.select(p);
                        map.fit(p.geometry.bounds);
                      },
              ),
            ),
        ],
      );
    }
    if (m.page == 'Análisis') return analysisPanel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          m.editing
              ? '2. Marca tu terreno'
              : m.selected?.name ?? 'Tu terreno, más claro',
          m.editing
              ? 'Toca cada esquina. Para mover un punto, toca su número y después su nueva posición.'
              : 'Encuentra tu terreno, marca sus límites y observa imágenes reales.',
        ),
        const Text(
          '1. Encuentra el lugar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: coordinates,
          decoration: const InputDecoration(
            labelText: 'Latitud, longitud',
            hintText: '-13.718, -76.148',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (_) => locate(),
        ),
        const SizedBox(height: 8),
        action('Ir a estas coordenadas', Icons.near_me_outlined, locate),
        if (!m.editing)
          action(
            m.selected == null ? '2. Marcar mi terreno' : 'Marcar otro terreno',
            Icons.add_location_alt_outlined,
            disabled ? null : m.newParcel,
            primary: true,
          ),
        if (m.editing) ...[
          Text(
            '${m.vertices.length} puntos · ${FieldGeometry.validate(m.vertices) == null ? '${FieldGeometry(m.vertices).hectares.toStringAsFixed(2)} ha aproximadas' : 'Completa un contorno sin cruces'}',
          ),
          const SizedBox(height: 12),
          action(
            'Deshacer último cambio',
            Icons.undo,
            disabled ? null : m.undo,
          ),
          if (m.selectedVertex != null)
            action(
              'Quitar punto seleccionado',
              Icons.remove_circle_outline,
              disabled ? null : m.removeVertex,
            ),
          action(
            'Guardar mi terreno',
            Icons.save_outlined,
            disabled ? null : save,
            primary: true,
          ),
          action(
            'Cancelar cambios',
            Icons.close,
            disabled ? null : m.cancelEdit,
          ),
        ] else if (m.selected != null) ...[
          Text(
            '${m.selected!.geometry.hectares.toStringAsFixed(2)} hectáreas aproximadas\n${m.selected!.farm.crop.isEmpty ? 'Cultivo sin registrar' : m.selected!.farm.crop}',
          ),
          const Text(
            'Superficie geodésica esférica. No es una medición catastral.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          action(
            '3. Qué quiero observar',
            Icons.satellite_alt,
            () => m.navigate('Análisis'),
            primary: true,
          ),
          action(
            'Corregir límites',
            Icons.edit_location_alt_outlined,
            disabled ? null : m.edit,
          ),
          action(
            'Datos de mi terreno',
            Icons.edit_note,
            disabled ? null : save,
          ),
          action(
            'Eliminar terreno',
            Icons.delete_outline,
            disabled ? null : delete,
          ),
        ],
        const Divider(),
        layerControls(),
      ],
    );
  }

  Widget layerControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: m.base,
        decoration: const InputDecoration(labelText: 'Mapa de fondo'),
        items: const [
          DropdownMenuItem(value: 'roads', child: Text('Caminos y lugares')),
          DropdownMenuItem(value: 'none', child: Text('Solo mis límites')),
        ],
        onChanged: (v) {
          m.base = v!;
          m.emit();
          m.preferences();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Vista regional NASA'),
        subtitle: const Text(
          'MODIS · 250 m · no permite evaluar plantas individuales',
        ),
        value: m.gibs,
        onChanged: (v) {
          m.gibs = v;
          m.emit();
          m.preferences();
        },
      ),
      if (m.gibs)
        action(
          'Fecha NASA: ${dateLabel(m.gibsDate)}',
          Icons.calendar_month,
          () async {
            final d = await showDatePicker(
              context: context,
              initialDate: m.gibsDate,
              firstDate: DateTime(2000, 2, 24),
              lastDate: DateTime.now(),
            );
            if (d != null) {
              m.gibsDate = d;
              m.emit();
              m.preferences();
            }
          },
        ),
      if (m.result != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar mi análisis'),
          value: m.showRaster,
          onChanged: (v) {
            m.showRaster = v;
            m.emit();
          },
        ),
      if (m.gibs || m.result != null) ...[
        const Text('Intensidad de la capa'),
        Slider(
          value: m.opacity,
          min: 0,
          max: 1,
          divisions: 10,
          label: '${(m.opacity * 100).round()}%',
          onChanged: (v) {
            m.opacity = v;
            m.emit();
          },
          onChangeEnd: (_) => m.preferences(),
        ),
      ],
      if (m.gibs)
        const Text(
          'Imagen RGB NASA GIBS. No se calculan índices a partir de estos colores. Puede haber nubes o días sin cobertura.',
        ),
    ],
  );
  Widget analysisPanel() {
    final disabled = m.busy.isNotEmpty || m.editing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          '3. Observa y compara',
          m.selected?.name ?? 'Primero marca y guarda tu terreno.',
        ),
        if (m.selected == null)
          action(
            'Marcar un terreno',
            Icons.add_location_alt_outlined,
            m.newParcel,
            primary: true,
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => pickDate(true),
                  child: Text('Desde\n${dateLabel(m.start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => pickDate(false),
                  child: Text('Hasta\n${dateLabel(m.end)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Observation>(
            initialValue: variable,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Qué quiero observar'),
            items: [
              for (final v in Observation.values.where(
                (v) =>
                    m.advanced ||
                    [
                      Observation.rgb,
                      Observation.ndvi,
                      Observation.ndmi,
                    ].contains(v),
              ))
                DropdownMenuItem(
                  value: v,
                  child: Text(v.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => variable = v!),
          ),
          if (m.advanced) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar Landsat 8/9'),
              subtitle: const Text(
                'USGS/NASA · no mezclar con Sentinel-2 sin armonización',
              ),
              value: m.useLandsat,
              onChanged: disabled
                  ? null
                  : (v) {
                      m.useLandsat = v;
                      m.scenes = [];
                      m.emit();
                    },
            ),
            Text('Nubosidad máxima de escena: ${m.maxCloud.round()}%'),
            Slider(
              value: m.maxCloud,
              min: 0,
              max: 100,
              divisions: 10,
              onChanged: (v) {
                m.maxCloud = v;
                m.emit();
              },
            ),
          ],
          const SizedBox(height: 12),
          action(
            'Buscar imágenes',
            Icons.satellite_alt,
            disabled ? null : m.searchScenes,
            primary: true,
          ),
          if (m.scenes.isNotEmpty)
            const Text('Elige una fecha para procesar solo tu terreno:'),
          for (final s in m.scenes)
            Card(
              child: ListTile(
                title: Text(dateLabel(s.acquired)),
                subtitle: Text(
                  '${s.clouds?.toStringAsFixed(1) ?? '?'}% nubes de escena${m.advanced ? '\n${s.id}' : ''}',
                ),
                trailing: const Icon(Icons.play_circle_outline),
                onTap: disabled ? null : () => m.analyze(s, variable),
              ),
            ),
          const SizedBox(height: 8),
          ResultPanel(model: m),
          if (m.result != null) layerControls(),
          const Divider(),
          Text(
            'Historial guardado',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (m.results.isEmpty)
            const Text('Todavía no hay análisis guardados para estos límites.'),
          for (final r in m.results)
            Card(
              child: ListTile(
                title: Text(
                  '${dateLabel(r.acquired)} · ${r.observation.label}',
                ),
                subtitle: Text(
                  'Media: ${number(r.statistics.mean)} · ${number(r.statistics.validPercent)}% válido',
                ),
                onTap: () {
                  m.result = r;
                  m.comparison = null;
                  m.showRaster = true;
                  m.gibs = false;
                  m.emit();
                  map.fit(r.bounds);
                },
                trailing:
                    m.result != null &&
                        m.result!.id != r.id &&
                        m.comparable(m.result!, r)
                    ? IconButton(
                        tooltip: 'Comparar esta fecha',
                        icon: const Icon(Icons.compare_arrows),
                        onPressed: () {
                          m.comparison = r;
                          m.emit();
                        },
                      )
                    : null,
              ),
            ),
          if (m.comparison != null)
            action('Alternar fecha en el mapa', Icons.swap_horiz, () {
              final other = m.comparison;
              m.comparison = m.result;
              m.result = other;
              m.emit();
            }),
          const Divider(),
          action(
            'Cuánto ha llovido · NASA POWER',
            Icons.water_drop_outlined,
            disabled ? null : m.loadWeather,
          ),
          if (m.weather != null) ...[
            const Text(
              'Clima regional · NASA POWER\nMeteorología aprox. 0,5° × 0,625°; radiación aprox. 1° × 1°. No es una medición dentro del terreno. Días en UTC.',
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Día')),
                  for (final item in [
                    ('Lluvia', 'PRECTOTCORR'),
                    ('Aire', 'T2M'),
                    ('HR', 'RH2M'),
                    ('Sol', 'ALLSKY_SFC_SW_DWN'),
                  ])
                    DataColumn(
                      label: Text(
                        '${item.$1}\n${(m.weather!.units[item.$2] as Map<String, dynamic>)['units']}',
                      ),
                    ),
                ],
                rows: [
                  for (final day in m.weather!.days)
                    DataRow(
                      cells: [
                        DataCell(Text(day)),
                        for (final p in [
                          'PRECTOTCORR',
                          'T2M',
                          'RH2M',
                          'ALLSKY_SFC_SW_DWN',
                        ])
                          DataCell(Text(number(m.weather!.value(p, day)))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: m,
    builder: (context, _) {
      if (!m.advanced &&
          ![
            Observation.rgb,
            Observation.ndvi,
            Observation.ndmi,
          ].contains(variable)) {
        variable = Observation.rgb;
      }
      final mapWidget = FieldMap(
        controller: map,
        tileClient: widget.tiles,
        base: m.base == 'roads' ? roads : null,
        layer: m.gibs
            ? MapTiles(
                template: GibsLayer.template(m.gibsDate),
                attribution: GibsLayer.attribution,
                maxNativeZoom: 9,
              )
            : null,
        raster:
            m.showRaster &&
                m.result != null &&
                File(m.result!.imagePath).existsSync()
            ? MapRaster(FileImage(File(m.result!.imagePath)), m.result!.bounds)
            : null,
        opacity: m.opacity,
        vertices: m.vertices,
        selectedVertex: m.selectedVertex,
        editing: m.editing,
        onTap: (p) {
          if (m.editing) {
            m.tap(p);
          } else {
            m.inspect(p);
          }
        },
        onVertex: m.chooseVertex,
      );
      final panel = Material(
        color: const Color(0xfff8faf7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: controls(),
        ),
      );
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xffdce5db))),
                ),
                child: LayoutBuilder(
                  builder: (context, c) => c.maxWidth > 1000
                      ? Row(
                          children: [
                            const Icon(
                              Icons.eco,
                              size: 32,
                              color: Color(0xff185b3a),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'NASA Field Shift',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: navigation(),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NASA Field Shift',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            navigation(),
                          ],
                        ),
                ),
              ),
              if (m.offline)
                Container(
                  width: double.infinity,
                  color: const Color(0xfff5e6bd),
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Sin internet: solo recursos guardados. Las imágenes ausentes no se descargarán.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (m.busy.isNotEmpty)
                Column(
                  children: [
                    const LinearProgressIndicator(),
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(child: Text(m.busy)),
                        TextButton.icon(
                          onPressed: m.cancel,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ],
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => c.maxWidth >= 850
                      ? Row(
                          children: [
                            SizedBox(width: 370, child: panel),
                            Expanded(child: mapWidget),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 5, child: mapWidget),
                            Expanded(flex: 5, child: panel),
                          ],
                        ),
                ),
              ),
              if (m.message.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: const Color(0xffe5efe3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    m.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
