import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';
import '../core/lookups/lookups.dart';
import 'state_views.dart';

/// The personal details asked at signup and in "Edit your details":
/// date of birth, gender and the division -> district -> upazila chain.
class PersonalDetails {
  const PersonalDetails({
    this.dateOfBirth,
    this.genderId,
    this.divisionId,
    this.districtId,
    this.upazilaId,
  });

  final DateTime? dateOfBirth;
  final int? genderId;
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;

  bool get isComplete =>
      dateOfBirth != null && genderId != null && divisionId != null && districtId != null && upazilaId != null;

  PersonalDetails copyWith({
    DateTime? dateOfBirth,
    int? genderId,
    int? divisionId,
    int? districtId,
    int? upazilaId,
    bool clearDistrict = false,
    bool clearUpazila = false,
  }) {
    return PersonalDetails(
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      genderId: genderId ?? this.genderId,
      divisionId: divisionId ?? this.divisionId,
      districtId: clearDistrict ? null : districtId ?? this.districtId,
      upazilaId: clearUpazila || clearDistrict ? null : upazilaId ?? this.upazilaId,
    );
  }

  /// API body fields (dateOfBirth as YYYY-MM-DD).
  Map<String, dynamic> toJson() => {
        if (dateOfBirth != null) 'dateOfBirth': formatYmd(dateOfBirth!),
        if (genderId != null) 'genderId': genderId,
        if (divisionId != null) 'divisionId': divisionId,
        if (districtId != null) 'districtId': districtId,
        if (upazilaId != null) 'upazilaId': upazilaId,
      };
}

String formatYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Date of birth, gender and address dropdowns, all required. Options come
/// from the lookup tables. Validation runs with the surrounding Form.
class PersonalDetailsFields extends ConsumerWidget {
  const PersonalDetailsFields({super.key, required this.value, required this.onChanged});

  final PersonalDetails value;
  final ValueChanged<PersonalDetails> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final lookupsAsync = ref.watch(lookupsProvider);

    return lookupsAsync.when(
      loading: () => const SkeletonLines(lines: 4),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(strings.couldNotLoadOptions)),
            TextButton(onPressed: () => ref.invalidate(lookupsProvider), child: Text(strings.retry)),
          ],
        ),
      ),
      data: (lookups) {
        final districts = lookups.districts.where((d) => d.parentId == value.divisionId).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateOfBirthField(value: value.dateOfBirth, onChanged: (d) => onChanged(value.copyWith(dateOfBirth: d))),
            const SizedBox(height: 16),
            _Dropdown(
              label: strings.gender,
              icon: Icons.wc_outlined,
              options: lookups.genders,
              value: value.genderId,
              onChanged: (id) => onChanged(value.copyWith(genderId: id)),
            ),
            const SizedBox(height: 16),
            _Dropdown(
              label: strings.division,
              icon: Icons.map_outlined,
              options: lookups.divisions,
              value: value.divisionId,
              onChanged: (id) => onChanged(value.copyWith(divisionId: id, clearDistrict: true)),
            ),
            const SizedBox(height: 16),
            _Dropdown(
              label: strings.district,
              icon: Icons.location_city_outlined,
              options: districts,
              value: value.districtId,
              enabled: value.divisionId != null,
              onChanged: (id) => onChanged(value.copyWith(districtId: id, clearUpazila: true)),
            ),
            const SizedBox(height: 16),
            if (value.districtId == null)
              _Dropdown(
                label: strings.upazila,
                icon: Icons.place_outlined,
                options: const [],
                value: null,
                enabled: false,
                onChanged: (_) {},
              )
            else
              ref.watch(upazilasProvider(value.districtId!)).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => TextButton(
                      onPressed: () => ref.invalidate(upazilasProvider(value.districtId!)),
                      child: Text(strings.retry),
                    ),
                    data: (upazilas) => _Dropdown(
                      label: strings.upazila,
                      icon: Icons.place_outlined,
                      options: upazilas,
                      value: value.upazilaId,
                      onChanged: (id) => onChanged(value.copyWith(upazilaId: id)),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _Dropdown extends ConsumerWidget {
  const _Dropdown({
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final List<LookupOption> options;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    // A value missing from the options (e.g. list still loading) shows as empty.
    final current = options.any((o) => o.id == value) ? value : null;
    return DropdownButtonFormField<int>(
      // Rebuild when the parent choice changes, so the field resets cleanly.
      key: ValueKey('$label-${options.length}-$current'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: options
          .map((o) => DropdownMenuItem<int>(value: o.id, child: Text(o.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (v) => v == null ? strings.requiredField : null,
    );
  }
}

class _DateOfBirthField extends ConsumerWidget {
  const _DateOfBirthField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return FormField<DateTime>(
      key: ValueKey(value),
      initialValue: value,
      validator: (v) => v == null ? strings.requiredField : null,
      builder: (field) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime(now.year - 40),
            firstDate: DateTime(now.year - 120),
            lastDate: now,
            helpText: strings.dateOfBirth,
          );
          if (picked != null) {
            field.didChange(picked);
            onChanged(picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: strings.dateOfBirth,
            prefixIcon: const Icon(Icons.cake_outlined),
            errorText: field.errorText,
          ),
          isEmpty: value == null,
          child: Text(value == null ? '' : formatYmd(value!)),
        ),
      ),
    );
  }
}
