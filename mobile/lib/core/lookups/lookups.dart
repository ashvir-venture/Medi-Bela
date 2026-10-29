import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../constants/api_endpoints.dart';

/// One row of a lookup table (dropdown option). Every dropdown reads these
/// tables from the server; nothing is hard-coded in the app.
class LookupOption {
  const LookupOption({required this.id, required this.name, this.parentId});

  final int id;
  final String name;

  /// divisionId for a district, districtId for an upazila.
  final int? parentId;

  factory LookupOption.fromJson(Map<String, dynamic> json, {String? parentKey}) {
    return LookupOption(
      id: json['id'] as int,
      name: json['name'] as String,
      parentId: parentKey == null ? null : json[parentKey] as int?,
    );
  }
}

class Lookups {
  const Lookups({
    required this.genders,
    required this.divisions,
    required this.districts,
    required this.mealTimings,
  });

  final List<LookupOption> genders;
  final List<LookupOption> divisions;
  final List<LookupOption> districts;
  final List<LookupOption> mealTimings;

  factory Lookups.fromJson(Map<String, dynamic> json) {
    List<LookupOption> list(String key, {String? parentKey}) => (json[key] as List<dynamic>? ?? [])
        .map((e) => LookupOption.fromJson(e as Map<String, dynamic>, parentKey: parentKey))
        .toList();
    return Lookups(
      genders: list('genders'),
      divisions: list('divisions'),
      districts: list('districts', parentKey: 'divisionId'),
      mealTimings: list('mealTimings'),
    );
  }

  String? nameOf(List<LookupOption> options, int? id) {
    if (id == null) return null;
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    return null;
  }
}

/// Dropdown data (public endpoint: the signup form needs it too). Kept for
/// the app session once loaded.
final lookupsProvider = FutureProvider<Lookups>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final response = await dio.get<Map<String, dynamic>>(ApiEndpoints.lookups);
  return Lookups.fromJson(response.data!);
});

/// Upazilas of one district, loaded when a district is chosen.
final upazilasProvider = FutureProvider.family<List<LookupOption>, int>((ref, districtId) async {
  final dio = ref.watch(dioClientProvider).dio;
  final response = await dio.get<List<dynamic>>(
    ApiEndpoints.upazilas,
    queryParameters: {'districtId': districtId},
  );
  return response.data!
      .map((e) => LookupOption.fromJson(e as Map<String, dynamic>, parentKey: 'districtId'))
      .toList();
});
