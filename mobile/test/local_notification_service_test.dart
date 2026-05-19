import 'package:flutter_test/flutter_test.dart';
import 'package:pawplan_mobile/services/local_notification_service.dart';

void main() {
  test('buildCareReminderPlan filters disabled and non-pending schedules', () {
    final now = DateTime(2026, 4, 26, 7);
    final reminders = LocalNotificationService.buildCareReminderPlan([
      {
        'id': 1,
        'title': '심장사상충 예방',
        'dueDate': '2026-04-26',
        'scheduleType': 'heartworm',
        'status': 'pending',
        'reminderEnabled': true,
      },
      {
        'id': 2,
        'title': '알림 꺼짐',
        'dueDate': '2026-04-26',
        'status': 'pending',
        'reminderEnabled': false,
      },
      {
        'id': 3,
        'title': '완료 일정',
        'dueDate': '2026-04-26',
        'status': 'completed',
        'reminderEnabled': true,
      },
    ], now: now);

    expect(reminders, hasLength(1));
    expect(reminders.first.id, 10);
    expect(reminders.first.title, '케어 일정 알림');
    expect(reminders.first.scheduledAt, DateTime(2026, 4, 26, 8));
  });

  test('buildCareReminderPlan limits scheduled reminders', () {
    final schedules = List.generate(
      25,
      (index) => {
        'id': index + 1,
        'title': '일정 $index',
        'dueDate': '2026-04-27',
        'status': 'pending',
        'reminderEnabled': true,
      },
    );

    final reminders = LocalNotificationService.buildCareReminderPlan(
      schedules,
      now: DateTime(2026, 4, 26, 8),
      limit: 20,
    );

    expect(reminders, hasLength(20));
    expect(reminders.first.id, 10);
    expect(reminders.last.id, 200);
  });

  test('buildCareReminderPlan uses type-specific advance reminders', () {
    final reminders = LocalNotificationService.buildCareReminderPlan([
      {
        'id': 31,
        'title': '정기 건강검진',
        'dueDate': '2026-05-10',
        'scheduleType': 'checkup',
        'priority': 'high',
        'status': 'pending',
        'reminderEnabled': true,
        'carePlan': {'responsibleLabel': '나'},
      },
    ], now: DateTime(2026, 5, 1, 8));

    expect(reminders, hasLength(3));
    expect(reminders.map((item) => item.scheduledAt), [
      DateTime(2026, 5, 3, 9),
      DateTime(2026, 5, 9, 9),
      DateTime(2026, 5, 10, 9),
    ]);
    expect(reminders.every((item) => item.critical), isTrue);
    expect(reminders.first.delivery, 'push_candidate');
    expect(reminders.first.body, contains('담당: 나'));
  });

  test('buildCareReminderPlan escalates missed recurring schedules', () {
    final reminders = LocalNotificationService.buildCareReminderPlan([
      {
        'id': 41,
        'title': '심장사상충 예방',
        'dueDate': '2026-04-22',
        'scheduleType': 'heartworm',
        'priority': 'high',
        'repeatCycleDays': 30,
        'status': 'pending',
        'reminderEnabled': true,
      },
    ], now: DateTime(2026, 4, 26, 8));

    expect(reminders, hasLength(1));
    expect(reminders.first.id, 418);
    expect(reminders.first.title, '반복 케어 점검 필요');
    expect(reminders.first.urgency, 'missed_repeated');
    expect(reminders.first.delivery, 'push_candidate');
    expect(reminders.first.critical, isTrue);
    expect(reminders.first.scheduledAt, DateTime(2026, 4, 26, 8, 5));
  });
}
