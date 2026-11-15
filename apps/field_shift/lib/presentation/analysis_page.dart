import 'package:field_imagery/field_imagery.dart';
import 'package:flutter/material.dart';

import '../application/field_controller.dart';
import 'field_strings.dart';
import 'period_picker.dart';
import 'result_panel.dart';
import 'weather_panel.dart';
import 'workspace_widgets.dart';

class AnalysisPage extends StatefulWidget {
  final FieldController model;
  final bool previewMissing;
  final VoidCallback fitResult;
  const AnalysisPage({
    super.key,
    required this.model,
    required this.previewMissing,
    required this.fitResult,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final _resultAnchor = GlobalKey();
  FieldController get m => widget.model;
  bool get _canQuery => !m.isBusy && !m.offline && !m.editing;

  Future<void> _changePeriod() async {
    final period = await choosePeriod(context, from: m.start, to: m.end);
    if (period != null && mounted) m.setPeriod(period.start, period.end);
  }

  void _revealResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _resultAnchor.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          context.t('Field observations', 'Observaciones del terreno'),
        ),
        if (m.saved.isNotEmpty) ...[
          ParcelPicker(m, FieldPage.analysis),
          const SizedBox(height: 12),
        ],
        if (m.editing || m.selected == null)
          EmptyPanel(
            icon: Icons.satellite_alt_outlined,
            title: context.t(
              'Save a field to get started',
              'Guarda un terreno para empezar',
            ),
            detail: context.t(
              'Choose a saved field or mark its boundary on the map.',
              'Elige un terreno guardado o marca sus límites en el mapa.',
            ),
            action: OutlinedButton(
              onPressed: m.editing ? () => m.goTo(FieldPage.map) : m.newParcel,
              child: Text(context.t('Go to map', 'Ir al mapa')),
            ),
          )
        else ...[
          Text(
            context.t('Period', 'Período'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            key: const ValueKey('analysis-period'),
            onPressed: m.isBusy ? null : _changePeriod,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(periodLabel(context, m.start, m.end)),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                selected: !m.showingWeather,
                label: Text(
                  context.t('Satellite images', 'Imágenes satelitales'),
                ),
                onSelected: (_) => m.viewObservations(),
              ),
              ChoiceChip(
                selected: m.showingWeather,
                label: Text(
                  context.t('Weather history', 'Historial del clima'),
                ),
                onSelected: (_) => m.viewObservations(weather: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (m.offline) ...[
            Notice(
              context.t(
                'Offline mode. Saved observations are available.',
                'Modo sin conexión. Puedes abrir tus observaciones guardadas.',
              ),
              icon: Icons.cloud_off_outlined,
            ),
            const SizedBox(height: 12),
          ],
          if (m.showingWeather) _weather(context) else ..._satellite(context),
        ],
      ],
    );
  }

  List<Widget> _satellite(BuildContext context) {
    final allowed = Observation.values.where((value) {
      if (value == Observation.temperature) return m.advanced && m.useLandsat;
      return m.advanced ||
          value == Observation.rgb ||
          value == Observation.ndvi ||
          value == Observation.ndmi;
    }).toList();
    final variable = allowed.contains(m.analysisVariable)
        ? m.analysisVariable
        : Observation.rgb;
    final result = m.result;
    final title = Theme.of(context).textTheme.titleMedium;
    return [
      DropdownButtonFormField<Observation>(
        key: ValueKey((m.advanced, m.useLandsat)),
        initialValue: variable,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.t('What do you want to see?', '¿Qué quieres ver?'),
        ),
        items: [
          for (final v in allowed)
            DropdownMenuItem(
              value: v,
              child: Text(
                context.observationLabel(v),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: m.isBusy
            ? null
            : (value) {
                if (value == null) return;
                m.analysisVariable = value;
                m.emit();
              },
      ),
      if (m.advanced)
        ExpansionTile(
          key: const PageStorageKey('catalog-options'),
          tilePadding: EdgeInsets.zero,
          title: Text(context.t('Satellite settings', 'Opciones de satélite')),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Use Landsat 8/9', 'Usar Landsat 8/9')),
              subtitle: const Text('USGS/NASA · Collection 2 Level 2'),
              value: m.useLandsat,
              onChanged: m.isBusy
                  ? null
                  : (v) {
                      m.useLandsat = v;
                      m.scenes = [];
                      m.emit();
                    },
            ),
            Text(
              context.t(
                'Max. cloud cover: ${m.maxCloud.round()}%',
                'Nubosidad máxima: ${m.maxCloud.round()} %',
              ),
            ),
            Slider(
              value: m.maxCloud,
              max: 100,
              divisions: 10,
              onChanged: m.isBusy
                  ? null
                  : (v) {
                      m.maxCloud = v;
                      m.scenes = [];
                      m.emit();
                    },
            ),
          ],
        )
      else
        const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _canQuery ? m.searchScenes : null,
        icon: const Icon(Icons.search, size: 20),
        label: Text(context.t('Find images', 'Buscar imágenes')),
      ),
      if (result != null) ...[
        const SizedBox(height: 16),
        ResultPanel(
          key: _resultAnchor,
          model: m,
          previewMissing: widget.previewMissing,
        ),
        if (!widget.previewMissing)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.t('Show image on map', 'Mostrar imagen en el mapa'),
            ),
            value: m.showRaster,
            onChanged: (value) {
              m.showRaster = value;
              m.emit();
            },
          ),
        if (m.comparison != null)
          OutlinedButton.icon(
            onPressed: m.isBusy ? null : m.swapComparison,
            icon: const Icon(Icons.swap_horiz),
            label: Text(
              context.t('Switch image on map', 'Cambiar fecha en el mapa'),
            ),
          ),
      ],
      if (m.scenes.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(
          context.t('Images in this period', 'Imágenes del período'),
          style: title,
        ),
        if (m.advanced)
          Text(
            context.t(
              'Cloud cover is for the whole image. The field check runs when you open it.',
              'La nubosidad corresponde a la imagen completa. La cobertura del terreno se calcula al abrirla.',
            ),
          ),
        const SizedBox(height: 5),
        for (final scene in m.scenes) _scene(context, scene, variable),
      ],
      const Divider(height: 24),
      Text(
        context.t('Saved observations', 'Observaciones guardadas'),
        style: title,
      ),
      if (m.observations.incomplete)
        Text(
          context.t(
            'Some saved results could not be opened.',
            'Algunos resultados guardados no se pudieron abrir.',
          ),
        ),
      if (m.results.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            context.t(
              'No observations saved for this field yet.',
              'Aún no hay observaciones guardadas para este terreno.',
            ),
          ),
        ),
      for (final previous in m.results.reversed)
        _history(context, previous, result),
    ];
  }

  Widget _scene(BuildContext context, Scene scene, Observation variable) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.satellite_alt_outlined, size: 20),
        title: Text(context.dateLabel(scene.acquired)),
        subtitle: Text(
          [
            if (scene.clouds != null)
              context.t(
                '${context.number(scene.clouds, decimals: 0)}% cloud cover',
                '${context.number(scene.clouds, decimals: 0)} % de nubes',
              ),
            if (m.advanced) scene.provider,
            if (m.advanced) scene.id,
          ].join('\n'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _canQuery
            ? () async {
                await m.analyze(scene, variable);
                if (mounted && m.result?.sceneId == scene.id) _revealResult();
              }
            : null,
      );

  Widget _history(
    BuildContext context,
    RasterResult past,
    RasterResult? active,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    selected: active?.id == past.id,
    title: Text(
      '${context.dateLabel(past.acquired)} · ${context.observationLabel(past.observation)}',
    ),
    subtitle: Text(context.qualityLabel(past.quality)),
    onTap: m.isBusy
        ? null
        : () {
            m.openResult(past);
            widget.fitResult();
            _revealResult();
          },
    trailing:
        active != null && active.id != past.id && m.comparable(active, past)
        ? IconButton(
            tooltip: context.t(
              'Compare with this date',
              'Comparar con esta fecha',
            ),
            icon: const Icon(Icons.compare_arrows_outlined),
            onPressed: m.isBusy
                ? null
                : () {
                    m.comparison = past;
                    m.emit();
                    _revealResult();
                  },
          )
        : null,
  );

  Widget _weather(BuildContext context) {
    final tooLong = m.end.difference(m.start).inDays > 366;
    final weather = m.weather;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tooLong) ...[
          Text(
            context.t(
              'Choose up to a year for weather history.',
              'Elige hasta un año para consultar el historial del clima.',
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _canQuery && !tooLong ? m.loadWeather : null,
          icon: const Icon(Icons.water_drop_outlined, size: 20),
          label: Text(
            context.t('Get weather history', 'Consultar historial del clima'),
          ),
        ),
        const SizedBox(height: 12),
        if (weather != null)
          WeatherPanel(weather, start: m.start, end: m.end)
        else
          Text(
            context.t(
              'Rain and temperature records for the area around your field.',
              'Registros de lluvia y temperatura de la zona de tu terreno.',
            ),
          ),
      ],
    );
  }
}
