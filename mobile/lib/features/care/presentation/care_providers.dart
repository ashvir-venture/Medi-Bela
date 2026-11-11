import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
export '../../../core/localization/app_strings.dart' show AppStrings, Round15Strings, Round15StringsOf;
import '../../../core/localization/locale_controller.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/health_controller.dart';
import '../domain/care_content.dart';
import '../domain/care_models.dart';

/// My care (cached GET /care), updated live from the local copy.
final careOverviewProvider = StreamProvider<CareOverview>((ref) => ref.watch(careRepositoryProvider).watchCare());

/// Health records 2.0 (cached GET /records).
final recordsOverviewProvider = StreamProvider<RecordsOverview>((ref) => ref.watch(careRepositoryProvider).watchRecords());

/// The owner's condition and test lists (online first, cached copy offline).
final careLookupsProvider = FutureProvider<CareLookups>((ref) => ref.watch(careRepositoryProvider).lookups());

/// A member's care and records for their caregiver (online, never cached).
final memberCareProvider = FutureProvider.autoDispose.family<CareOverview, String>((ref, memberId) async {
  return CareOverview.fromJson(await ref.watch(careApiProvider).overview(forUserId: memberId));
});

final memberRecordsProvider = FutureProvider.autoDispose.family<RecordsOverview, String>((ref, memberId) async {
  return RecordsOverview.fromJson(await ref.watch(careApiProvider).records(forUserId: memberId));
});

final memberReadingsProvider = FutureProvider.autoDispose.family<List<HealthRecordModel>, String>((ref, memberId) {
  return ref.watch(healthApiProvider).getRecords(forUserId: memberId);
});

/// Whose care a screen shows: mine (null) or a member's (caregiver).
class CareSubject {
  const CareSubject({this.memberId, this.memberName});

  final String? memberId;
  final String? memberName;

  bool get isMember => memberId != null;
}

/// The care data a screen reads, mine (offline cache) or a member's (online).
AsyncValue<CareOverview> watchCareOf(WidgetRef ref, CareSubject who) =>
    who.isMember ? ref.watch(memberCareProvider(who.memberId!)) : ref.watch(careOverviewProvider);

AsyncValue<RecordsOverview> watchRecordsOf(WidgetRef ref, CareSubject who) =>
    who.isMember ? ref.watch(memberRecordsProvider(who.memberId!)) : ref.watch(recordsOverviewProvider);

AsyncValue<List<HealthRecordModel>> watchReadingsOf(WidgetRef ref, CareSubject who) =>
    who.isMember ? ref.watch(memberReadingsProvider(who.memberId!)) : ref.watch(healthRecordsProvider);

/// After a caregiver change, reload the member's data.
void invalidateMember(WidgetRef ref, CareSubject who) {
  if (!who.isMember) return;
  ref.invalidate(memberCareProvider(who.memberId!));
  ref.invalidate(memberRecordsProvider(who.memberId!));
  ref.invalidate(memberReadingsProvider(who.memberId!));
}

/// Runs a change and shows the error as a snackbar; true when it worked.
Future<bool> runCareAction(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? done}) async {
  final strings = ref.read(stringsProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, strings))));
    return false;
  }
}

/// The name of a condition: the owner's table, else the built-in one.
String conditionName(String code, CareLookups? lookups, bool bn) {
  final c = lookups?.condition(code);
  if (c != null) return c.name(bn);
  final f = conditionFallbackNames[code];
  return f == null ? code : tr(f, bn);
}

String? conditionSubtitle(String code, CareLookups? lookups, bool bn) => lookups?.condition(code)?.subtitle(bn);

/// The name of a test kind (or the typed "Other" name).
String testName(String? kindCode, String? otherName, CareLookups? lookups, bool bn) {
  final k = lookups?.testKind(kindCode);
  if (k != null) return k.name(bn);
  return otherName ?? kindCode ?? '';
}

IconData conditionIcon(String code) => switch (code) {
      'diabetes' => Icons.water_drop_outlined,
      'bp' => Icons.speed_outlined,
      'heart' => Icons.favorite_border,
      'kidney' => Icons.water_outlined,
      'cancer' => Icons.event_available_outlined,
      'asthma' => Icons.air,
      'thyroid' => Icons.monitor_heart_outlined,
      'pregnancy' => Icons.child_friendly_outlined,
      _ => Icons.healing_outlined,
    };

const _enMonthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _bnMonthsShort = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি', 'মে', 'জুন', 'জুলাই', 'আগ', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];

/// "6 Nov" / "৬ নভে", with the year when it is not this year.
String shortDate(DateTime d, Round15Strings s, {DateTime? now}) {
  final thisYear = (now ?? DateTime.now()).year == d.year;
  final m = s.bn ? _bnMonthsShort[d.month - 1] : _enMonthsShort[d.month - 1];
  return thisYear ? '${s.n(d.day)} $m' : '${s.n(d.day)} $m ${s.n(d.year)}';
}

String monthShort(DateTime d, Round15Strings s) => s.bn ? _bnMonthsShort[d.month - 1] : _enMonthsShort[d.month - 1];

/// "today", "yesterday", "6 Nov".
String dayLabel(DateTime d, Round15Strings s, {DateTime? now}) {
  final diff = dateOnly(d).difference(dateOnly(now ?? DateTime.now())).inDays;
  if (diff == 0) return s.today;
  if (diff == -1) return s.yesterday;
  return shortDate(d, s, now: now);
}

/// "in 5 days" for a date ahead (or ago).
String inDaysLabel(DateTime d, Round15Strings s, {DateTime? now}) =>
    s.inDays(dateOnly(d).difference(dateOnly(now ?? DateTime.now())).inDays);

String timeLabel(BuildContext context, DateTime t, Round15Strings s) => s.n(TimeOfDay.fromDateTime(t).format(context));

String hhmmLabel(BuildContext context, String hhmm, Round15Strings s) {
  final p = hhmm.split(':');
  return s.n(TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])).format(context));
}

/// A number for display: whole numbers without decimals.
String numText(double v, Round15Strings s, {int decimals = 1}) =>
    s.n(v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(decimals));

/// Bengali digits typed into a number field, as Western ones.
String westernDigits(String s) =>
    s.replaceAllMapped(RegExp('[০-৯]'), (m) => '${'০১২৩৪৫৬৭৮৯'.indexOf(m[0]!)}');

double? parseNumber(String raw) => double.tryParse(westernDigits(raw.trim()).replaceAll(',', '.'));

AppStrings stringsOf(WidgetRef ref) => ref.watch(stringsProvider);
