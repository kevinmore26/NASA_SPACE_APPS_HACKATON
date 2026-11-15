import 'farm_planning.dart';
import 'geometry.dart';

/// Local agricultural record. Free-text V1 fields remain available in V2.
class FarmRecord {
  final String crop, history, soil, water, irrigation, budget, priorities;
  final FarmPlanning? planning;
  const FarmRecord({
    this.crop = '',
    this.history = '',
    this.soil = '',
    this.water = '',
    this.irrigation = '',
    this.budget = '',
    this.priorities = '',
    this.planning,
  });
  String get currentCropLabel {
    final kind = planning?.crop;
    return kind == null || kind == FarmCrop.other ? crop : kind.label;
  }

  Map<String, dynamic> toJson() => {
    'crop': crop,
    'history': history,
    'soil': soil,
    'water': water,
    'irrigation': irrigation,
    'budget': budget,
    'priorities': priorities,
    if (planning != null) 'planning': planning!.toJson(),
  };
  factory FarmRecord.fromJson(Map<String, dynamic> j) => FarmRecord(
    crop: j['crop'] as String? ?? '',
    history: j['history'] as String? ?? '',
    soil: j['soil'] as String? ?? '',
    water: j['water'] as String? ?? '',
    irrigation: j['irrigation'] as String? ?? '',
    budget: j['budget'] as String? ?? '',
    priorities: j['priorities'] as String? ?? '',
    planning: FarmPlanning.fromJson(j['planning'] as Map<String, dynamic>?),
  );
}

class Parcel {
  final String id, name;
  final FieldGeometry geometry;
  final FarmRecord farm;
  final DateTime updatedAt;
  Parcel({
    required this.id,
    required this.name,
    required this.geometry,
    this.farm = const FarmRecord(),
    required this.updatedAt,
  }) {
    if (id.isEmpty || name.trim().isEmpty) {
      throw ArgumentError('El terreno necesita un nombre.');
    }
  }
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'id': id,
    'name': name,
    'geometry': geometry.toJson(),
    'farm': farm.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  factory Parcel.fromJson(Map<String, dynamic> j) => Parcel(
    id: j['id'] as String,
    name: j['name'] as String,
    geometry: FieldGeometry.fromJson(j['geometry'] as List),
    farm: FarmRecord.fromJson(j['farm'] as Map<String, dynamic>? ?? {}),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );
}

abstract interface class ParcelRepository {
  Future<List<Parcel>> listParcels();
  Future<void> saveParcel(Parcel parcel);
  Future<void> deleteParcel(String id);
}

/// Non-secret, versioned JSON documents owned by their consumer.
abstract interface class LocalDocuments {
  Future<Map<String, dynamic>?> readDocument(String key);
  Future<void> writeDocument(String key, Map<String, dynamic> value);
  Future<List<Map<String, dynamic>>> listDocuments(String prefix);
}
