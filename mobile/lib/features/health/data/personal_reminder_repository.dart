import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/result.dart';
import '../../../notifications/notification_scheduler.dart';
import '../domain/personal_reminder_models.dart';

/// Personal reminders over HTTP. `forUserId` = the caregiver acting for a member.
class PersonalReminderApi {
  PersonalReminderApi(this._dio);

  final Dio _dio;

  Map<String, dynamic> _for(String? forUserId) => {if (forUserId != null) 'forUserId': forUserId};

  Future<List<PersonalReminderModel>> list({String? forUserId}) async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.personalReminders, queryParameters: _for(forUserId));
    return response.data!.map((r) => PersonalReminderModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> create(Map<String, dynamic> body, {String? forUserId}) =>
      _dio.post<void>(ApiEndpoints.personalReminders, data: body, queryParameters: _for(forUserId));

  Future<void> update(String id, Map<String, dynamic> body, {String? forUserId}) =>
      _dio.patch<void>(ApiEndpoints.personalReminder(id), data: body, queryParameters: _for(forUserId));

  Future<void> remove(String id, {String? forUserId}) =>
      _dio.delete<void>(ApiEndpoints.personalReminder(id), queryParameters: _for(forUserId));

  /// The member pressed Later on one ring ([at]); tells the caregiver who set it up.
  Future<void> later(String id, DateTime at) => _dio.post<void>(
        ApiEndpoints.personalReminderLater(id),
        data: {'at': at.toUtc().toIso8601String()},
      );
}

/// My personal reminders: kept on the phone (so they ring offline), pulled
/// from the server on every refresh. Changes are made online (form screen),
/// then pulled again.
class PersonalReminderRepository {
  PersonalReminderRepository({
    required PersonalReminderApi api,
    required AppDatabase database,
    required NotificationScheduler notificationScheduler,
  })  : _api = api,
        _db = database,
        _notifications = notificationScheduler;

  final PersonalReminderApi _api;
  final AppDatabase _db;
  final NotificationScheduler _notifications;

  Stream<List<PersonalReminderModel>> watchAll() =>
      _db.select(_db.cachedPersonalReminders).watch().map((rows) => rows.map(_toModel).toList());

  Future<void> reconcileLocalNotifications() async {
    final rows = await _db.select(_db.cachedPersonalReminders).get();
    await _notifications.reconcilePersonalReminders(rows.map(_toModel).toList());
  }

  Future<Result<void>> refreshFromServer() async {
    try {
      final reminders = await _api.list();
      final now = DateTime.now();
      await _db.transaction(() async {
        await _db.delete(_db.cachedPersonalReminders).go();
        for (final r in reminders) {
          await _db.into(_db.cachedPersonalReminders).insert(
                CachedPersonalRemindersCompanion.insert(
                  id: r.id,
                  name: r.name,
                  description: Value(r.description),
                  scheduleTimes: jsonEncode(r.scheduleTimes),
                  intervalDays: Value(r.intervalDays),
                  startDate: r.startDate,
                  endDate: Value(r.endDate),
                  byCaregiver: Value(r.byCaregiver),
                  cachedAt: now,
                ),
              );
        }
      });
      await reconcileLocalNotifications();
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  PersonalReminderModel _toModel(CachedPersonalReminder row) => PersonalReminderModel(
        id: row.id,
        name: row.name,
        description: row.description,
        scheduleTimes: (jsonDecode(row.scheduleTimes) as List).cast<String>(),
        intervalDays: row.intervalDays,
        startDate: row.startDate,
        endDate: row.endDate,
        byCaregiver: row.byCaregiver,
      );
}
