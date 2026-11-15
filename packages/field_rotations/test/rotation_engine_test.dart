import 'package:field_core/field_core.dart';
import 'package:field_rotations/field_rotations.dart';
import 'package:test/test.dart';

Parcel parcel({FarmPlanning? planning, double latitude = -6.73}) => Parcel(
  id: 'test',
  name: 'Parcela de la prueba',
  geometry: FieldGeometry([
    GeoPoint(latitude, -79.78),
    GeoPoint(latitude, -79.77),
    GeoPoint(latitude + 0.01, -79.77),
  ]),
  farm: FarmRecord(crop: 'Maíz', history: 'Frijol 2024', planning: planning),
  updatedAt: DateTime.utc(2026),
);

FarmPlanning profile({
  int month = 3,
  FarmWater? water = FarmWater.secured,
  FarmBudget? budget = FarmBudget.canEvaluate,
  double? conductivity = 1.5,
}) => FarmPlanning(
  crop: FarmCrop.maize,
  region: FarmRegion.lambayequeCoast,
  sowingMonth: month,
  texture: SoilTexture.sandyLoam,
  drainage: SoilDrainage.good,
  water: water,
  irrigation: IrrigationMethod.gravity,
  budget: budget,
  soilConductivity: conductivity,
);

void main() {
  const engine = RotationEngine();

  test('March pilot gives current reference and two distinct crop options', () {
    final comparison = engine.compare(parcel(planning: profile()));
    expect(comparison.currentCrop, 'Maíz amarillo duro');
    expect(comparison.history, 'Frijol 2024');
    expect(comparison.alternatives.map((a) => a.crop), [
      'Frijol caupí INIA 432',
      'Frijol blanco mediano',
    ]);
    expect(comparison.outstanding, isEmpty);
  });

  test('season and soil criteria can leave only one applicable option', () {
    for (final profile in [
      FarmPlanning.fromJson({...profile().toJson(), 'sowingMonth': 4}),
      FarmPlanning.fromJson({...profile().toJson(), 'soilConductivity': 2.1}),
    ]) {
      final comparison = engine.compare(parcel(planning: profile));
      expect(comparison.alternatives.single.crop, 'Frijol blanco mediano');
      expect(comparison.outstanding, isNotEmpty);
    }
  });

  test('unknown water, restricted budget, outside pilot or unknown data do not invent alternatives', () {
    final parcels = [
      parcel(planning: profile(water: null)),
      parcel(planning: profile(budget: FarmBudget.currentCropOnly)),
      parcel(planning: profile(), latitude: -13.71),
      parcel(),
    ];
    for (final input in parcels) {
      final comparison = engine.compare(input);
      expect(comparison.alternatives, isEmpty);
      expect(comparison.outstanding, isNotEmpty);
    }
    expect(engine.compare(parcel()).currentCrop, 'Maíz');
  });
}
