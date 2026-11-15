/// Structured, farmer-reported inputs. A missing value means "No sé".
enum FarmCrop {
  maize('Maíz amarillo duro'),
  cowpea('Frijol caupí'),
  dryBean('Frijol común'),
  other('Otro cultivo');

  const FarmCrop(this.label);
  final String label;
}

enum FarmRegion { lambayequeCoast, other }

enum SoilTexture { sandyLoam, loam, clay, other }

enum SoilDrainage { good, poor }

enum FarmWater { secured, limited, unavailable }

enum IrrigationMethod { gravity, sprinkler, drip, none }

enum FarmBudget { canEvaluate, currentCropOnly }

enum FarmPriority {
  water('Cuidar el agua'),
  soil('Proteger el suelo'),
  resilience('Diversificar los cultivos'),
  cost('Cuidar el presupuesto');

  const FarmPriority(this.label);
  final String label;
}

class FarmPlanning {
  final FarmCrop? crop;
  final FarmRegion? region;
  final int? sowingMonth;
  final SoilTexture? texture;
  final SoilDrainage? drainage;
  final double? soilConductivity;
  final FarmWater? water;
  final IrrigationMethod? irrigation;
  final FarmBudget? budget;
  final FarmPriority? priority;
  final String referenceNextCrop;

  const FarmPlanning({
    this.crop,
    this.region,
    this.sowingMonth,
    this.texture,
    this.drainage,
    this.soilConductivity,
    this.water,
    this.irrigation,
    this.budget,
    this.priority,
    this.referenceNextCrop = '',
  });

  Map<String, dynamic> toJson() => {
    'schema': 1,
    if (crop != null) 'crop': crop!.name,
    if (region != null) 'region': region!.name,
    if (sowingMonth != null) 'sowingMonth': sowingMonth,
    if (texture != null) 'texture': texture!.name,
    if (drainage != null) 'drainage': drainage!.name,
    if (soilConductivity != null) 'soilConductivity': soilConductivity,
    if (water != null) 'water': water!.name,
    if (irrigation != null) 'irrigation': irrigation!.name,
    if (budget != null) 'budget': budget!.name,
    if (priority != null) 'priority': priority!.name,
    if (referenceNextCrop.isNotEmpty) 'referenceNextCrop': referenceNextCrop,
  };

  static FarmPlanning? fromJson(Map<String, dynamic>? data) {
    if (data == null || data['schema'] != 1) return null;
    final month = data['sowingMonth'];
    final conductivity = data['soilConductivity'];
    return FarmPlanning(
      crop: FarmCrop.values.asNameMap()[data['crop']],
      region: FarmRegion.values.asNameMap()[data['region']],
      sowingMonth: month is int && month >= 1 && month <= 12 ? month : null,
      texture: SoilTexture.values.asNameMap()[data['texture']],
      drainage: SoilDrainage.values.asNameMap()[data['drainage']],
      soilConductivity:
          conductivity is num && conductivity.isFinite && conductivity >= 0
          ? conductivity.toDouble()
          : null,
      water: FarmWater.values.asNameMap()[data['water']],
      irrigation: IrrigationMethod.values.asNameMap()[data['irrigation']],
      budget: FarmBudget.values.asNameMap()[data['budget']],
      priority: FarmPriority.values.asNameMap()[data['priority']],
      referenceNextCrop: data['referenceNextCrop'] as String? ?? '',
    );
  }
}
