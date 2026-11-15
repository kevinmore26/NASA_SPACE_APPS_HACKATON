import 'package:flutter/material.dart';

import '../application/crop_suitability.dart';
import '../application/field_controller.dart';
import 'field_strings.dart';
import 'workspace_widgets.dart';

class CropSuitabilityPanel extends StatelessWidget {
  final FieldController model;
  const CropSuitabilityPanel({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final review = model.cropReview;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Crops to consider', 'Cultivos para evaluar'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'Explore options for this field using regional climate history and any soil data you recorded.',
              'Explora opciones para este terreno con el clima histórico de la zona y los datos de suelo que registraste.',
            ),
          ),
          if (review != null) ...[
            const SizedBox(height: 12),
            _CropResults(review),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: model.offline || model.isBusy
                ? null
                : model.evaluateCrops,
            icon: const Icon(Icons.eco_outlined, size: 18),
            label: Text(
              review == null
                  ? context.t('Evaluate crops', 'Evaluar cultivos')
                  : context.t('Refresh results', 'Actualizar resultados'),
            ),
          ),
          if (model.offline)
            Text(
              context.t(
                'Connect to evaluate crops again.',
                'Conéctate a internet para consultar cultivos.',
              ),
              style: const TextStyle(color: muted),
            ),
        ],
      ),
    );
  }
}

class _CropResults extends StatelessWidget {
  final CropSuitability review;
  const _CropResults(this.review);

  @override
  Widget build(BuildContext context) {
    final scoreLabel = switch (review.status) {
      CropSuitabilityStatus.candidates => context.t(
        'Score with historical rainfall',
        'Puntaje con lluvia histórica',
      ),
      CropSuitabilityStatus.conditional =>
        review.usesSoil
            ? context.t(
                'Temperature and soil score',
                'Puntaje de temperatura y suelo',
              )
            : context.t('Temperature score', 'Puntaje de temperatura'),
      CropSuitabilityStatus.empty => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.status == CropSuitabilityStatus.empty)
          Notice(
            context.t(
              'The evaluation returned zero scores for the available options.',
              'Las opciones evaluadas obtuvieron puntajes de cero.',
            ),
          ),
        if (review.status == CropSuitabilityStatus.conditional) ...[
          Notice(
            context.t(
              'Review water availability for these options.',
              'Revisa la disponibilidad de agua para estas opciones.',
            ),
            warning: true,
          ),
          const SizedBox(height: 8),
        ],
        if (review.crops.isNotEmpty) ...[
          Text(scoreLabel, style: const TextStyle(color: muted)),
          for (final crop in review.crops)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(crop.name),
              subtitle: crop.scientificName.isEmpty
                  ? null
                  : Text(crop.scientificName),
              trailing: Text(
                '${context.number(crop.score, decimals: 1)} / 100',
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          '${review.source} · ${review.catalog} · ${review.start.year}–${review.end.year}',
          style: const TextStyle(color: muted),
        ),
        Text(
          context.t(
            'Discuss these options with a local adviser before planting.',
            'Revisa estas opciones con asesoría local antes de sembrar.',
          ),
          style: const TextStyle(color: muted),
        ),
      ],
    );
  }
}
