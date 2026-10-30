import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../router/app_router.dart';
import '../../prescription/presentation/prescription_screen.dart';
import 'my_medicines_screen.dart';
import 'today_medicine_screen.dart';

/// Segments of the Medicines tab, as written in `?tab=`.
enum MedicinesSegment {
  today('today'),
  mine('mine'),
  prescriptions('prescriptions');

  const MedicinesSegment(this.query);
  final String query;

  static MedicinesSegment parse(String? value) =>
      values.firstWhere((s) => s.query == value, orElse: () => MedicinesSegment.today);
}

/// The Medicines tab: today's doses, my medicines and prescriptions under
/// one tab, switched by a segmented control at the top. The segment is in
/// the URL, so pushes and links open the right one.
class MedicinesTabScreen extends ConsumerWidget {
  const MedicinesTabScreen({super.key, required this.segment});

  final MedicinesSegment segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.medicinesTab),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<MedicinesSegment>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: MedicinesSegment.today, label: Text(strings.today)),
                  ButtonSegment(value: MedicinesSegment.mine, label: Text(strings.myMedicines)),
                  ButtonSegment(value: MedicinesSegment.prescriptions, label: Text(strings.prescriptionsButton)),
                ],
                selected: {segment},
                onSelectionChanged: (s) => context.go(AppRoutes.medicinesTabPath(s.first.query)),
              ),
            ),
          ),
        ),
      ),
      body: switch (segment) {
        MedicinesSegment.today => const TodaysMedicineScreen(),
        MedicinesSegment.mine => const MyMedicinesScreen(),
        MedicinesSegment.prescriptions => const PrescriptionScreen(),
      },
    );
  }
}
