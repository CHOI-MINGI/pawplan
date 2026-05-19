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
    required this.scheduleType,
    required this.urgency,
    required this.delivery,
    this.critical = false,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String scheduleType;
  final String urgency;
  final String delivery;
  final bool critical;
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
        notificationDetails: _notificationDetails(critical: reminder.critical),
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
      notificationDetails: _notificationDetails(critical: false),
    );
  }

  NotificationDetails _notificationDetails({required bool critical}) {
    final android = AndroidNotificationDetails(
      critical ? 'pawplan_critical_care' : 'pawplan_care',
      critical ? 'PawPlan critical care' : 'PawPlan care reminders',
      channelDescription: critical
          ? 'Important care plan reminders and missed recurring schedules'
          : 'Care schedule reminders generated on device',
      importance: critical ? Importance.max : Importance.high,
      priority: critical ? Priority.max : Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
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

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static ({List<int> leadDays, int hour, int minute, String delivery})
  _policyFor(String scheduleType, String priority) {
    final highPriority = priority == 'high';
    if (scheduleType == 'vaccine' || scheduleType == 'checkup') {
      return (
        leadDays: highPriority ? [7, 1, 0] : [3, 0],
        hour: 9,
        minute: 0,
        delivery: highPriority ? 'push_candidate' : 'local',
      );
    }
    if (scheduleType == 'heartworm' || scheduleType == 'medication') {
      return (
        leadDays: highPriority ? [1, 0] : [0],
        hour: 8,
        minute: 0,
        delivery: highPriority ? 'push_candidate' : 'local',
      );
    }
    if (scheduleType == 'deworming') {
      return (
        leadDays: [3, 0],
        hour: 9,
        minute: 0,
        delivery: highPriority ? 'push_candidate' : 'local',
      );
    }
    return (
      leadDays: highPriority ? [1, 0] : [0],
      hour: scheduleType == 'grooming' ? 10 : 9,
      minute: 0,
      delivery: 'local',
    );
  }

  static int _notificationId(int scheduleId, int slot) {
    return ((scheduleId % 100000000) * 10 + slot) & 0x7fffffff;
  }

  static String _responsibleLabel(JsonMap schedule) {
    final carePlan = schedule['carePlan'] as JsonMap?;
    final label = carePlan?['responsibleLabel'] as String?;
    if (label != null && label.isNotEmpty) return '담당: $label';
    final assignee = schedule['assigneeName'] as String?;
    if (assignee != null && assignee.isNotEmpty) return '담당: $assignee';
    return '담당자 확인 필요';
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
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
    final today = _startOfDay(effectiveNow);

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

      final title = schedule['title'] as String? ?? '돌봄 일정';
      final scheduleType = schedule['scheduleType'] as String? ?? 'custom';
      final priority = schedule['priority'] as String? ?? 'medium';
      final dueDay = _startOfDay(dueDate);
      final overdueDays = today.difference(dueDay).inDays;
      final repeatCycleDays = _asInt(schedule['repeatCycleDays']);
      final repeatFailureThreshold = repeatCycleDays == null
          ? 3
          : (repeatCycleDays * 0.1).ceil().clamp(2, 7);
      final responsible = _responsibleLabel(schedule);

      if (overdueDays > 0) {
        final repeatedMiss = overdueDays >= repeatFailureThreshold;
        reminders.add(
          CareReminderPlan(
            id: _notificationId(scheduleId, 8),
            title: repeatedMiss ? '반복 케어 점검 필요' : '지난 케어 일정 확인',
            body: repeatedMiss
                ? '$title 일정이 $overdueDays일 지났습니다. 완료/건너뛰기와 $responsible.'
                : '$title 일정 예정일이 지났습니다. $responsible.',
            scheduledAt: effectiveNow.add(const Duration(minutes: 5)),
            scheduleType: scheduleType,
            urgency: repeatedMiss ? 'missed_repeated' : 'overdue',
            delivery: 'push_candidate',
            critical: true,
          ),
        );
        if (reminders.length >= limit) break;
        continue;
      }

      final policy = _policyFor(scheduleType, priority);
      for (var index = 0; index < policy.leadDays.length; index++) {
        if (reminders.length >= limit) break;
        final leadDays = policy.leadDays[index];
        final reminderDay = dueDay.subtract(Duration(days: leadDays));
        final reminderAt = DateTime(
          reminderDay.year,
          reminderDay.month,
          reminderDay.day,
          policy.hour,
          policy.minute,
        );
        if (!reminderAt.isAfter(effectiveNow)) continue;
        final isDueDay = leadDays == 0;
        final critical =
            priority == 'high' || policy.delivery == 'push_candidate';
        final timing = isDueDay ? '오늘' : '$leadDays일 후';
        reminders.add(
          CareReminderPlan(
            id: _notificationId(scheduleId, index),
            title: critical ? '중요 케어 일정' : '케어 일정 알림',
            body: '$timing $title 일정을 챙겨야 합니다. $responsible.',
            scheduledAt: reminderAt,
            scheduleType: scheduleType,
            urgency: isDueDay ? 'due_today' : 'upcoming',
            delivery: critical ? 'push_candidate' : 'local',
            critical: critical,
          ),
        );
      }
    }

    return reminders;
  }
}
