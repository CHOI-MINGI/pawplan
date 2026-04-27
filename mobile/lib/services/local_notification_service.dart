import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../api/api_client.dart';

@visibleForTesting
class CareReminderPlan {
  const CareReminderPlan({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
}

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    bool enabled = true,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _enabled = enabled;

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _enabled;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!_enabled || kIsWeb) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(settings: settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> syncCareReminders(List<JsonMap> schedules) async {
    if (!_canScheduleOnThisPlatform || !_initialized) return;
    await _plugin.cancelAll();

    for (final reminder in buildCareReminderPlan(schedules)) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, tz.local),
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> showReportReady(String dogName) async {
    if (!_canScheduleOnThisPlatform || !_initialized) return;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '방문 리포트 생성 완료',
      body: '$dogName 병원 방문 리포트를 확인할 수 있습니다.',
      notificationDetails: _notificationDetails(),
    );
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      'pawplan_care',
      'PawPlan care reminders',
      channelDescription: 'Care schedule reminders generated on device',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  bool get _canScheduleOnThisPlatform {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  static int? _stableNotificationId(Object? value) {
    if (value is int) return value & 0x7fffffff;
    if (value is num) return value.toInt() & 0x7fffffff;
    if (value is String) return int.tryParse(value)?.remainder(0x7fffffff);
    return null;
  }

  @visibleForTesting
  static List<CareReminderPlan> buildCareReminderPlan(
    List<JsonMap> schedules, {
    DateTime? now,
    int limit = 20,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final reminders = <CareReminderPlan>[];

    for (final schedule in schedules) {
      if (reminders.length >= limit) break;
      if (schedule['status'] != null && schedule['status'] != 'pending') {
        continue;
      }
      if (schedule['reminderEnabled'] == false) continue;

      final dueDateText = schedule['dueDate'] as String?;
      final scheduleId = _stableNotificationId(schedule['id']);
      if (dueDateText == null || scheduleId == null) continue;

      final dueDate = DateTime.tryParse(dueDateText)?.toLocal();
      if (dueDate == null) continue;

      final reminderAt = DateTime(dueDate.year, dueDate.month, dueDate.day, 9);
      if (!reminderAt.isAfter(effectiveNow)) continue;

      final title = schedule['title'] as String? ?? '돌봄 일정';
      reminders.add(
        CareReminderPlan(
          id: scheduleId,
          title: title,
          body: '오늘 챙길 PawPlan 일정이 있습니다.',
          scheduledAt: reminderAt,
        ),
      );
    }

    return reminders;
  }
}
