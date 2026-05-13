/// @file species.dart
/// @description Species model for allometric equation lookup in offline mode.
library;

class Species {
  final String id;
  final String scientificName;
  final String commonName;
  final String familyName;
  final String vegetationType;
  final double woodDensity;
  final double rootShootRatio;
  final String growthRate;
  final bool isNative;
  final Map<String, dynamic> allometricEquations;

  const Species({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.familyName,
    required this.vegetationType,
    required this.woodDensity,
    required this.rootShootRatio,
    required this.growthRate,
    required this.isNative,
    required this.allometricEquations,
  });

  factory Species.fromJson(Map<String, dynamic> json) => Species(
    id: json['id'] as String,
    scientificName: json['scientificName'] as String,
    commonName: json['commonName'] as String,
    familyName: json['familyName'] as String? ?? '',
    vegetationType: json['vegetationType'] as String? ?? '',
    woodDensity: (json['woodDensity'] as num).toDouble(),
    rootShootRatio: (json['rootShootRatio'] as num).toDouble(),
    growthRate: json['growthRate'] as String? ?? 'medium',
    isNative: json['isNative'] as bool? ?? true,
    allometricEquations: (json['allometricEquations'] as Map?)?.cast<String, dynamic>() ?? {},
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'scientificName': scientificName,
    'commonName': commonName,
    'familyName': familyName,
    'vegetationType': vegetationType,
    'woodDensity': woodDensity,
    'rootShootRatio': rootShootRatio,
    'growthRate': growthRate,
    'isNative': isNative,
    'allometricEquations': allometricEquations,
  };

  /// Quick AGB estimate (kg) using default equation coefficients — for UI hints only.
  /// Authoritative calculation is done server-side via BiomassCalculation.service.js.
  double? quickAgbKg({double? dbhCm}) {
    if (dbhCm == null) return null;
    final eq = (allometricEquations['tropical_moist'] ?? allometricEquations.values.firstOrNull) as Map?;
    if (eq == null) return null;
    final a = (eq['a'] as num?)?.toDouble() ?? 0.1;
    final b = (eq['b'] as num?)?.toDouble() ?? 2.0;
    return a * (dbhCm * dbhCm) * b / 1000; // rough approx
  }
}
