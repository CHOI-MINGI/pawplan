import 'package:flutter_test/flutter_test.dart';
import 'package:pawplan_mobile/services/local_notification_service.dart';

void main() {
  test(
    'buildCareReminderPlan filters disabled non-pending and past schedules',
    () {
      final now = DateTime(2026, 4, 26, 8);
      final reminders = LocalNotificationService.buildCareReminderPlan([
        {
          'id': 1,
          'title': '심장사상충 예방',
          'dueDate': '2026-04-26',
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
        {
          'id': 4,
          'title': '지난 일정',
          'dueDate': '2026-04-25',
          'status': 'pending',
          'reminderEnabled': true,
        },
      ], now: now);

      expect(reminders, hasLength(1));
      expect(reminders.first.id, 1);
      expect(reminders.first.title, '심장사상충 예방');
      expect(reminders.first.scheduledAt, DateTime(2026, 4, 26, 9));
    },
  );

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
    expect(reminders.first.id, 1);
    expect(reminders.last.id, 20);
  });
}
