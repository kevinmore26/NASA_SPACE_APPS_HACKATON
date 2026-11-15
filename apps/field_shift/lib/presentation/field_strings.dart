import 'package:field_core/field_core.dart';
import 'package:field_imagery/field_imagery.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../application/field_language.dart';

extension FieldStrings on BuildContext {
  FieldLanguage get fieldLanguage =>
      FieldLanguage.fromCode(Localizations.localeOf(this).languageCode);

  String t(String english, String spanish) =>
      fieldLanguage.pick(english, spanish);

  String dateLabel(DateTime date) =>
      DateFormat.yMMMd(fieldLanguage.code).format(date);

  String monthLabel(int month) =>
      DateFormat.MMMM(fieldLanguage.code).format(DateTime(2000, month));

  String number(num? value, {int decimals = 2}) {
    if (value == null || !value.isFinite) return t('No data', 'Sin datos');
    final format = NumberFormat.decimalPattern(fieldLanguage.code)
      ..minimumFractionDigits = decimals
      ..maximumFractionDigits = decimals;
    return format.format(value);
  }

  String cropLabel(FarmCrop crop) => switch (crop) {
    FarmCrop.maize => t('Yellow field corn', 'Maíz amarillo duro'),
    FarmCrop.cowpea => t('Cowpea', 'Frijol caupí'),
    FarmCrop.dryBean => t('Common bean', 'Frijol común'),
    FarmCrop.other => t('Another crop', 'Otro cultivo'),
  };

  String currentCrop(FarmRecord record) {
    final type = record.planning?.crop;
    return type == null || type == FarmCrop.other
        ? record.crop
        : cropLabel(type);
  }

  String observationLabel(Observation observation) => switch (observation) {
    Observation.rgb => t('Field image', 'Imagen del terreno'),
    Observation.ndvi => t('Vegetation greenness', 'Verdor de la vegetación'),
    Observation.ndmi => t(
      'Vegetation moisture signal',
      'Señal de humedad de la vegetación',
    ),
    Observation.falseColor => t(
      'Vegetation in infrared',
      'Vegetación en infrarrojo',
    ),
    Observation.swir => t(
      'Shortwave infrared image',
      'Imagen de infrarrojo de onda corta',
    ),
    Observation.red => t('Red band', 'Banda roja'),
    Observation.temperature => t(
      'Surface temperature',
      'Temperatura de la superficie',
    ),
  };

  String qualityLabel(RasterQuality quality) => switch (quality) {
    RasterQuality.available => t('Usable image', 'Imagen utilizable'),
    RasterQuality.limited => t('Limited coverage', 'Cobertura limitada'),
    RasterQuality.unusable => t(
      'No usable image data',
      'Sin datos utilizables',
    ),
  };

  String priorityLabel(FarmPriority priority) => switch (priority) {
    FarmPriority.water => t('Use water carefully', 'Cuidar el agua'),
    FarmPriority.soil => t('Protect the soil', 'Proteger el suelo'),
    FarmPriority.resilience => t(
      'Grow a wider mix of crops',
      'Diversificar los cultivos',
    ),
    FarmPriority.cost => t('Keep costs manageable', 'Cuidar el presupuesto'),
  };
  String geometryIssue(GeometryIssue issue) => t(switch (issue) {
    GeometryIssue.tooFewPoints => 'Mark at least three corners.',
    GeometryIssue.tooManyPoints => 'A field can have up to 500 corners.',
    GeometryIssue.dateLineCrossing =>
      'Keep the outline on one side of the date line.',
    GeometryIssue.overlappingEdges =>
      'Move corners to separate overlapping edges.',
    GeometryIssue.duplicatePoints => 'Each corner needs a different position.',
    GeometryIssue.intersectingEdges =>
      'Move corners so the edges do not cross.',
    GeometryIssue.tooSmall => 'Mark a wider outline.',
  }, issue.message);
}
