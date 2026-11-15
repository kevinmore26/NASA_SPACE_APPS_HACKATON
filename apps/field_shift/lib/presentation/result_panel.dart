import 'dart:convert';

import 'package:field_imagery/field_imagery.dart';
import 'package:flutter/material.dart';

import '../application/field_controller.dart';
import 'field_strings.dart';
import 'workspace_widgets.dart';

class ResultPanel extends StatelessWidget {
  final FieldController model;
  final bool previewMissing;

  const ResultPanel({
    super.key,
    required this.model,
    required this.previewMissing,
  });

  @override
  Widget build(BuildContext context) {
    final result = model.result;
    if (result == null) return const SizedBox.shrink();
    final stats = result.statistics;
    final quality = result.quality;
    final observation = result.observation;
    final comparison = model.comparison;
    final canInterpret = quality != RasterQuality.unusable;
    final technical = _technicalDetails(context, result);
    return Surface(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.observationLabel(observation),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            context.dateLabel(result.acquired),
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 9),
          Notice(
            context.qualityLabel(quality),
            icon: quality == RasterQuality.available
                ? Icons.check_circle_outline
                : Icons.info_outline,
            warning: quality != RasterQuality.available,
          ),
          const SizedBox(height: 9),
          if (canInterpret) ...[
            Text(
              context.t(
                '${context.number(stats.validPercent, decimals: 1)}% of the image inside your field is usable.',
                'Se puede leer el ${context.number(stats.validPercent, decimals: 1)} % de la imagen dentro de tu terreno.',
              ),
            ),
            const SizedBox(height: 5),
            Text(_plainMeaning(context, observation)),
            if (observation == Observation.temperature)
              Text(
                context.t(
                  'Average surface temperature: ${context.number(stats.mean, decimals: 1)} °C.',
                  'Temperatura media de la superficie: ${context.number(stats.mean, decimals: 1)} °C.',
                ),
              ),
          ] else
            Text(
              context.t(
                'Try an image from another day. Clouds and gaps can hide the field.',
                'Prueba una imagen de otro día. Las nubes o los huecos pueden tapar el terreno.',
              ),
            ),
          if (previewMissing) ...[
            const SizedBox(height: 8),
            Text(
              context.t(
                'The map image has left the cache. The saved numbers are still available.',
                'La imagen del mapa salió de la caché. Los datos guardados siguen disponibles.',
              ),
              style: const TextStyle(color: muted),
            ),
          ] else if (canInterpret &&
              (observation == Observation.ndvi ||
                  observation == Observation.ndmi ||
                  observation == Observation.temperature)) ...[
            const SizedBox(height: 11),
            _Legend(
              temperature: observation == Observation.temperature,
              technical: model.advanced,
            ),
          ],
          if (comparison != null) ...[
            const Divider(),
            Text(
              context.t(
                'Comparing with ${context.dateLabel(comparison.acquired)}',
                'Comparación con el ${context.dateLabel(comparison.acquired)}',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              context.t(
                'Compare where the field is visible in both images. Cloud cover can change between dates.',
                'Compara las zonas visibles en ambas imágenes. La nubosidad puede variar entre fechas.',
              ),
            ),
            if (model.advanced)
              Text(
                context.t(
                  'Earlier mean: ${context.number(comparison.statistics.mean, decimals: 3)}',
                  'Promedio anterior: ${context.number(comparison.statistics.mean, decimals: 3)}',
                ),
              ),
          ],
          ExpansionTile(
            key: PageStorageKey('result-details-${result.id}'),
            tilePadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(context.t('Data and method', 'Datos y método')),
            children: [
              CopyValue(
                technical,
                label: context.t('Copy details', 'Copiar detalles'),
              ),
              if (model.advanced && canInterpret)
                Text(
                  context.t(
                    'Click the map to inspect the value at that pixel.',
                    'Haz clic en el mapa para consultar el valor de ese píxel.',
                  ),
                ),
              if (model.pixel != null)
                Text(
                  context.t(
                    'Selected pixel: ${jsonEncode(model.pixel?.toJson())}',
                    'Píxel seleccionado: ${jsonEncode(model.pixel?.toJson())}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _plainMeaning(BuildContext context, Observation observation) =>
      switch (observation) {
        Observation.ndvi => context.t(
          'The colors show how strong the vegetation signal was that day. Crop type and growth stage also affect it.',
          'Los colores muestran la intensidad de la señal de vegetación ese día. El cultivo y su etapa de crecimiento también influyen.',
        ),
        Observation.ndmi => context.t(
          'The colors show a moisture signal from vegetation. Check the soil in the field before making irrigation decisions.',
          'Los colores muestran una señal de humedad de la vegetación. Revisa el suelo en campo antes de decidir el riego.',
        ),
        Observation.temperature => context.t(
          'The satellite measured the ground and crop surface. Use weather history to check air temperature.',
          'El satélite midió la superficie del suelo y el cultivo. Consulta el historial del clima para ver la temperatura del aire.',
        ),
        _ => context.t(
          'Use the image to see what was visible that day and compare it with a clearer date.',
          'Usa la imagen para ver qué era visible ese día y compárala con una fecha más despejada.',
        ),
      };

  String _technicalDetails(BuildContext context, RasterResult result) {
    final s = result.statistics;
    final details = result.data;
    final rawBands = details['bands'];
    final noData = context.t('No data', 'Sin datos');
    final bands = rawBands is List ? rawBands.join(', ') : noData;
    final variable = switch (result.observation) {
      Observation.ndvi => 'NDVI',
      Observation.ndmi => 'NDMI',
      _ => context.observationLabel(result.observation),
    };
    final citation =
        '${result.provider} · ${result.product} · ${context.number(result.resolution, decimals: 0)} m';
    return [
      citation,
      '${context.dateLabel(result.acquired)} UTC',
      context.t('Scene: ${result.sceneId}', 'Escena: ${result.sceneId}'),
      context.t(
        'Product version: ${details['productVersion'] ?? noData}',
        'Versión del producto: ${details['productVersion'] ?? noData}',
      ),
      context.t(
        'Method: ${details['method'] ?? noData}',
        'Método: ${details['method'] ?? noData}',
      ),
      '$variable · ${result.observation.formula}',
      if (details['unit'] case final String unit)
        context.t('Unit: $unit', 'Unidad: $unit'),
      context.t(
        'Valid pixels: ${s.validPixels}/${s.totalPixels}',
        'Píxeles válidos: ${s.validPixels}/${s.totalPixels}',
      ),
      context.t(
        'Mean: ${context.number(s.mean, decimals: 3)} · SD: ${context.number(s.stdDev, decimals: 3)}',
        'Promedio: ${context.number(s.mean, decimals: 3)} · Desv. estándar: ${context.number(s.stdDev, decimals: 3)}',
      ),
      context.t(
        'Min: ${context.number(s.min)} · Median: ${context.number(s.median)} · Max: ${context.number(s.max)}',
        'Mín: ${context.number(s.min)} · Mediana: ${context.number(s.median)} · Máx: ${context.number(s.max)}',
      ),
      context.t(
        'Cloud: ${s.cloudPixels} · Shadow: ${s.shadowPixels} · Missing: ${s.missingPixels}',
        'Nubes: ${s.cloudPixels} · Sombras: ${s.shadowPixels} · Sin dato: ${s.missingPixels}',
      ),
      context.t('Bands: $bands', 'Bandas: $bands'),
      context.t(
        'Mask: ${details['quality'] ?? noData}',
        'Máscara: ${details['quality'] ?? noData}',
      ),
      context.t(
        'Resampling: ${details['resampling'] ?? noData}',
        'Remuestreo: ${details['resampling'] ?? noData}',
      ),
      'CRS: ${details['crs'] ?? noData} · WGS84: ${result.bounds.toJson().map((n) => n.toStringAsFixed(4)).join(', ')}',
      context.t(
        'Cloud masks and mixed pixels along field boundaries limit interpretation. Light gray marks cloud, purple is shadow, and clear areas have no usable data.',
        'Las máscaras de nubes y los píxeles mixtos en los bordes limitan la interpretación. El gris claro marca nubes, el violeta sombras y la transparencia indica zonas sin datos utilizables.',
      ),
    ].join('\n');
  }
}

class _Legend extends StatelessWidget {
  final bool temperature, technical;
  const _Legend({required this.temperature, required this.technical});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        height: 9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 210, 95, 45),
              Color.fromARGB(255, 30, 145, 85),
            ],
          ),
        ),
      ),
      const SizedBox(height: 3),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            temperature
                ? context.t('Cooler', 'Más frío')
                : context.t('Weaker signal', 'Señal más débil'),
          ),
          Text(
            temperature
                ? context.t('Warmer', 'Más cálido')
                : context.t('Stronger signal', 'Señal más fuerte'),
          ),
        ],
      ),
      if (technical)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(temperature ? '−10 °C' : '−1'),
            Text(temperature ? '25 °C' : '0'),
            Text(temperature ? '60 °C' : '+1'),
          ],
        ),
    ],
  );
}
