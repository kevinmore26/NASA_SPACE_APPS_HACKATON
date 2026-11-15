import 'package:field_core/field_core.dart';

class RotationSource {
  final String title, url;
  const RotationSource(this.title, this.url);
}

enum RotationCrop { cowpea, dryBean }

class RotationAlternative {
  final RotationCrop type;
  final String crop, benefit, risk;
  final String? soilRequirement;
  final String plantingWindow;
  final Set<int> months;
  final RotationSource source;

  const RotationAlternative._({
    required this.type,
    required this.crop,
    required this.plantingWindow,
    required this.months,
    required this.benefit,
    required this.risk,
    required this.source,
    this.soilRequirement,
  });
}

enum RotationIssue {
  missingCrop('Confirma el tipo de cultivo actual.'),
  unsupportedCrop('El catálogo piloto parte de maíz amarillo duro.'),
  missingRegion('Confirma la zona agrícola y su altitud.'),
  unsupportedRegion(
    'Las reglas cargadas se aplican a la costa de Lambayeque. Revisa la zona y las coordenadas.',
  ),
  missingSowingMonth('Indica el mes en que puedes sembrar.'),
  missingDrainage('Confirma cómo drena el suelo.'),
  poorDrainage(
    'Confirma cómo resolver el encharcamiento antes de evaluar estas leguminosas.',
  ),
  uncertainWater(
    'Confirma disponibilidad de agua para la campaña. El catálogo requiere riego disponible.',
  ),
  missingIrrigation('Registra un sistema de riego disponible.'),
  restrictedBudget('El presupuesto registrado solo cubre el cultivo actual.'),
  cowpeaSeason('El caupí INIA 432 se evalúa de octubre a marzo.'),
  cowpeaSoil(
    'Para evaluar caupí INIA 432, confirma suelo franco arenoso y conductividad de hasta 2 dS/m.',
  ),
  dryBeanSeason('El frijol blanco mediano se evalúa de marzo a mayo.');

  const RotationIssue(this.message);
  final String message;
}

class RotationComparison {
  final String currentCrop, currentPlan, history;
  final FarmPriority? priority;
  final List<RotationAlternative> alternatives;
  final List<RotationIssue> issues;
  List<String> get outstanding => issues.map((issue) => issue.message).toList();

  const RotationComparison._({
    required this.currentCrop,
    required this.currentPlan,
    required this.history,
    required this.priority,
    required this.alternatives,
    required this.issues,
  });
}

/// Conditional options for one documented pilot. No forecast, yield or score.
class RotationEngine {
  const RotationEngine();

  static const rotationGuide = RotationSource(
    'SENASA · Guía de maíz amarillo duro, § 3.4',
    'https://www.senasa.gob.pe/senasa/descargasarchivos/2020/07/Guia-BPA-MAIZ-AMARILLO-DURO.pdf',
  );
  static const cowpeaGuide = RotationSource(
    'INIA · Ficha técnica Caupí INIA 432 – Vaina Verde',
    'https://agroshow.s3.us-east-2.amazonaws.com/catalogs/mbh4457l0txnl3.pdf',
  );
  static const _cowpea = RotationAlternative._(
    type: RotationCrop.cowpea,
    crop: 'Frijol caupí INIA 432',
    plantingWindow: 'Octubre a marzo',
    soilRequirement:
        'Suelo franco arenoso y conductividad de hasta 2 dS/m según ficha.',
    months: {10, 11, 12, 1, 2, 3},
    benefit:
        'Añade una leguminosa entre campañas de maíz y diversifica el cultivo.',
    risk:
        'Confirma semilla, venta, riego y manejo de plagas con personal local.',
    source: RotationSource(
      'INIA · Compendio de cultivares, pp. 208–209',
      'https://repositorio.inia.gob.pe/server/api/core/bitstreams/00d5f440-ebef-4b68-a70a-d240ac46bc1f/content',
    ),
  );
  static const _dryBean = RotationAlternative._(
    type: RotationCrop.dryBean,
    crop: 'Frijol blanco mediano',
    plantingWindow: 'Marzo a mayo',
    months: {3, 4, 5},
    benefit: 'Intercala una leguminosa de grano. Separar campañas de maíz puede ayudar a interrumpir ciclos de algunas plagas.',
    risk: 'Confirma variedad, salinidad, riego y comercialización. Revisa el historial de frijol y de herbicidas.',
    source: RotationSource(
      'SENASA · Guía de frijol, § 3.4',
      'https://www.senasa.gob.pe/senasa/descargasarchivos/2020/07/Guia-BPA-FRIJOL.pdf',
    ),
  );

  RotationComparison compare(Parcel parcel) {
    final farm = parcel.farm;
    final p = farm.planning ?? const FarmPlanning();
    final issues = <RotationIssue>[
      if (p.crop == null) RotationIssue.missingCrop,
      if (p.crop != null && p.crop != FarmCrop.maize)
        RotationIssue.unsupportedCrop,
      if (p.region == null) RotationIssue.missingRegion,
      if (p.region == FarmRegion.other ||
          (p.region == FarmRegion.lambayequeCoast &&
              !_nearLambayeque(parcel.geometry.bounds.center)))
        RotationIssue.unsupportedRegion,
      if (p.sowingMonth == null) RotationIssue.missingSowingMonth,
      if (p.drainage == null) RotationIssue.missingDrainage,
      if (p.drainage == SoilDrainage.poor) RotationIssue.poorDrainage,
      if (p.water != FarmWater.secured) RotationIssue.uncertainWater,
      if (p.irrigation == null || p.irrigation == IrrigationMethod.none)
        RotationIssue.missingIrrigation,
      if (p.budget == FarmBudget.currentCropOnly)
        RotationIssue.restrictedBudget,
    ];
    final alternatives = <RotationAlternative>[];
    if (issues.isEmpty) {
      if (!_cowpea.months.contains(p.sowingMonth)) {
        issues.add(RotationIssue.cowpeaSeason);
      } else if (p.texture != SoilTexture.sandyLoam ||
          p.soilConductivity == null ||
          p.soilConductivity! > 2) {
        issues.add(RotationIssue.cowpeaSoil);
      } else {
        alternatives.add(_cowpea);
      }
      if (_dryBean.months.contains(p.sowingMonth)) {
        alternatives.add(_dryBean);
      } else {
        issues.add(RotationIssue.dryBeanSeason);
      }
    }
    return RotationComparison._(
      currentCrop: farm.currentCropLabel,
      currentPlan: p.referenceNextCrop,
      history: farm.history,
      priority: p.priority,
      alternatives: List.unmodifiable(alternatives),
      issues: List.unmodifiable(issues),
    );
  }

  // A coarse geographic sanity check. The farmer confirms coastal conditions
  // and altitude; this rectangle is not an administrative boundary.
  bool _nearLambayeque(GeoPoint site) =>
      site.latitude >= -7.35 &&
      site.latitude <= -5.4 &&
      site.longitude >= -80.6 &&
      site.longitude <= -79.3;
}
