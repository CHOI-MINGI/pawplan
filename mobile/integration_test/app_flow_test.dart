import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawplan_mobile/api/api_client.dart';
import 'package:pawplan_mobile/main.dart';
import 'package:pawplan_mobile/services/local_notification_service.dart';
import 'package:pawplan_mobile/services/session_store.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000/api/v1',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo account can browse dashboard records and reports', (
    tester,
  ) async {
    await _pumpLoggedInApp(tester);

    expect(find.text('돌봄 일정'), findsOneWidget);
    expect(find.text('최근 건강 기록'), findsOneWidget);
    expect(find.text('이번 달 지출'), findsOneWidget);

    await _tapDashboardTab(tester, '기록');
    expect(find.text('기록 요약'), findsOneWidget);
    expect(find.text('통합 타임라인'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.textContaining('food 지출'), findsOneWidget);
    await _tapKey(tester, const ValueKey('timeline-filter-expense'));
    expect(find.textContaining('food 지출'), findsOneWidget);
    await _tapKey(tester, const ValueKey('timeline-filter-all'));
    expect(find.text('건강 기록'), findsWidgets);
    expect(find.text('병원 방문 기록'), findsOneWidget);
    expect(find.text('지출 기록'), findsOneWidget);
    expect(find.text('아침 체중'), findsWidgets);
    expect(find.text('동네동물병원'), findsWidgets);
    expect(find.textContaining('food'), findsWidgets);

    await _tapDashboardTab(tester, '리포트');
    expect(find.text('병원 방문 리포트'), findsOneWidget);
    expect(find.text('리포트 이력'), findsOneWidget);
    expect(find.text('비용 예측'), findsOneWidget);
    expect(find.text('최근 예측 이력'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forecast-recalculate-button')),
      findsOneWidget,
    );
    expect(find.textContaining('최근 증상:'), findsOneWidget);
    await _tapKey(tester, const ValueKey('forecast-recalculate-button'));
    await _pumpUntilFound(tester, find.text('최근 예측 이력'));
  });

  testWidgets('demo account can create edit and delete records from the UI', (
    tester,
  ) async {
    final api = ApiClient(baseUrl: _apiBaseUrl);
    final dogId = await _loginDemoAndDogId(api);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();

    final healthTitle = 'UI 증상 $suffix';
    final updatedHealthTitle = 'UI 증상 수정 $suffix';
    final expenseVendor = 'UI 펫샵 $suffix';
    final updatedExpenseVendor = 'UI 펫샵 수정 $suffix';
    final visitHospital = 'UI 동물병원 $suffix';
    final updatedVisitHospital = 'UI 동물병원 수정 $suffix';
    final attachmentName = 'ui-receipt-$suffix.png';

    addTearDown(() async {
      await _cleanupHealthLogs(api, dogId, [healthTitle, updatedHealthTitle]);
      await _cleanupExpenses(api, dogId, [
        expenseVendor,
        updatedExpenseVendor,
        visitHospital,
        updatedVisitHospital,
      ]);
      await _cleanupMedicalVisits(api, dogId, [
        visitHospital,
        updatedVisitHospital,
      ]);
    });

    await _pumpLoggedInApp(tester);

    await _createHealthLogFromUi(tester, healthTitle);
    final healthLogId = await _waitForRecordId(
      () => api.healthLogs(dogId),
      (item) => item['title'] == healthTitle,
    );
    await _tapDashboardTab(tester, '기록');
    expect(find.text(healthTitle), findsWidgets);

    await _tapKey(tester, ValueKey('health-log-edit-$healthLogId'));
    await _enterTextByKey(
      tester,
      const ValueKey('health-editor-title'),
      updatedHealthTitle,
    );
    await _tapKey(tester, const ValueKey('health-editor-save'));
    await _pumpUntilFound(tester, find.text(updatedHealthTitle));

    await _tapKey(tester, ValueKey('health-log-delete-$healthLogId'));
    await _tapKey(tester, const ValueKey('confirm-delete-button'));
    await _pumpUntilGone(tester, find.text(updatedHealthTitle));

    await _tapDashboardTab(tester, '오늘');
    await _createExpenseFromUi(tester, expenseVendor);
    final expenseId = await _waitForRecordId(
      () => api.expenses(dogId),
      (item) => item['vendorName'] == expenseVendor,
    );
    await _tapDashboardTab(tester, '기록');
    await _pumpUntilFound(tester, find.textContaining(expenseVendor));

    await _tapKey(tester, ValueKey('expense-edit-$expenseId'));
    await _enterTextByKey(
      tester,
      const ValueKey('expense-editor-vendor'),
      updatedExpenseVendor,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('expense-editor-amount'),
      '41000',
    );
    await _tapKey(tester, const ValueKey('expense-editor-save'));
    await _pumpUntilFound(tester, find.textContaining(updatedExpenseVendor));

    await _tapKey(tester, ValueKey('expense-delete-$expenseId'));
    await _tapKey(tester, const ValueKey('confirm-delete-button'));
    await _pumpUntilGone(tester, find.textContaining(updatedExpenseVendor));

    await _tapDashboardTab(tester, '오늘');
    await _createMedicalVisitFromUi(tester, visitHospital);
    final visitId = await _waitForRecordId(
      () => api.medicalVisits(dogId),
      (item) => item['hospitalName'] == visitHospital,
    );
    await _tapDashboardTab(tester, '기록');
    await _pumpUntilFound(tester, find.text(visitHospital));
    await api.uploadVisitAttachment(
      visitId: visitId,
      fileType: 'receipt',
      filename: attachmentName,
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    await _refreshDashboard(tester);
    await _tapDashboardTab(tester, '기록');
    await _expandMedicalVisit(tester, visitHospital);
    await _pumpUntilFound(tester, find.text(attachmentName));
    final attachmentId = await _waitForRecordId(
      () => api.visitAttachments(visitId),
      (item) => item['originalFilename'] == attachmentName,
    );
    await _tapKey(tester, ValueKey('attachment-delete-$attachmentId'));
    await _tapKey(tester, const ValueKey('confirm-delete-button'));
    await _pumpUntilGone(tester, find.text(attachmentName));

    await _tapKey(tester, ValueKey('medical-visit-edit-$visitId'));
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-hospital'),
      updatedVisitHospital,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-reason'),
      'UI 재검진',
    );
    await _tapKey(tester, const ValueKey('medical-visit-editor-save'));
    await _pumpUntilFound(tester, find.text(updatedVisitHospital));

    final visitDeleteKey = ValueKey('medical-visit-delete-$visitId');
    if (find.byKey(visitDeleteKey).evaluate().isEmpty) {
      await _expandMedicalVisit(tester, updatedVisitHospital);
    }
    await _tapKey(tester, visitDeleteKey);
    await _tapKey(tester, const ValueKey('confirm-delete-button'));
    await _pumpUntilGone(tester, find.text(updatedVisitHospital));
  });

  testWidgets('demo account can edit dog profile and manage care schedules', (
    tester,
  ) async {
    final api = ApiClient(baseUrl: _apiBaseUrl);
    final dogId = await _loginDemoAndDogId(api);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final editedDogName = '초코 UI $suffix';
    final scheduleTitle = 'UI 일정 $suffix';
    final updatedScheduleTitle = 'UI 일정 수정 $suffix';

    addTearDown(() async {
      await api.updateDog(
        dogId: dogId,
        payload: {
          'name': '초코',
          'breed': '푸들',
          'birthDate': '2021-04-18',
          'sex': 'female',
          'neutered': true,
          'currentWeightKg': 5.4,
          'targetWeightKg': 5.1,
          'activityLevel': 'medium',
          'insuranceStatus': 'none',
          'notes': '피부와 귀 상태를 주기적으로 확인합니다.',
        },
      );
      await _skipSchedulesByTitle(api, dogId, [
        scheduleTitle,
        updatedScheduleTitle,
      ]);
    });

    await _pumpLoggedInApp(tester);

    await _tapKey(tester, const ValueKey('dog-profile-edit-open'));
    await _enterTextByKey(
      tester,
      const ValueKey('dog-editor-name'),
      editedDogName,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('dog-editor-current-weight'),
      '5.6',
    );
    await _tapKey(tester, const ValueKey('dog-editor-save'));
    await _pumpUntilFound(tester, find.text(editedDogName));

    await _tapKey(tester, const ValueKey('schedule-create-open'));
    await _enterTextByKey(
      tester,
      const ValueKey('schedule-editor-title'),
      scheduleTitle,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('schedule-editor-due-date'),
      _dateInDays(3),
    );
    await _enterTextByKey(
      tester,
      const ValueKey('schedule-editor-description'),
      'UI 테스트 일정',
    );
    await _tapKey(tester, const ValueKey('schedule-editor-save'));
    await _pumpUntilFound(tester, find.text(scheduleTitle));

    final scheduleId = await _waitForRecordId(
      () => api.careSchedules(dogId),
      (item) => item['title'] == scheduleTitle,
    );
    await _tapKey(tester, ValueKey('schedule-edit-$scheduleId'));
    await _enterTextByKey(
      tester,
      const ValueKey('schedule-editor-title'),
      updatedScheduleTitle,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('schedule-editor-due-date'),
      _dateInDays(4),
    );
    await _tapKey(tester, const ValueKey('schedule-editor-save'));
    await _pumpUntilFound(tester, find.text(updatedScheduleTitle));

    await _tapKey(tester, ValueKey('schedule-skip-$scheduleId'));
    await _pumpUntilGone(tester, find.text(updatedScheduleTitle));
  });

  testWidgets('demo account can manage conditions and medications', (
    tester,
  ) async {
    final api = ApiClient(baseUrl: _apiBaseUrl);
    final dogId = await _loginDemoAndDogId(api);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final conditionName = 'UI 만성질환 $suffix';
    final updatedConditionName = 'UI 만성질환 수정 $suffix';
    final medicationName = 'UI 복약 $suffix';
    final updatedMedicationName = 'UI 복약 수정 $suffix';

    addTearDown(() async {
      await _cleanupConditions(api, dogId, [
        conditionName,
        updatedConditionName,
      ]);
      await _cleanupMedications(api, dogId, [
        medicationName,
        updatedMedicationName,
      ]);
    });

    await _pumpLoggedInApp(tester);
    await _tapDashboardTab(tester, '정보');
    expect(find.text('건강정보 요약'), findsOneWidget);

    await _tapKey(tester, const ValueKey('condition-create-open'));
    await _enterTextByKey(
      tester,
      const ValueKey('condition-editor-name'),
      conditionName,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('condition-editor-diagnosed-on'),
      _dateInDays(-30),
    );
    await _enterTextByKey(
      tester,
      const ValueKey('condition-editor-notes'),
      'UI 상태 메모',
    );
    await _tapKey(tester, const ValueKey('condition-editor-save'));
    await _pumpUntilFound(tester, find.text(conditionName));

    final conditionId = await _waitForRecordId(
      () => api.conditions(dogId),
      (item) => item['conditionName'] == conditionName,
    );
    await _expandTile(tester, conditionName);
    await _tapKey(tester, ValueKey('condition-edit-$conditionId'));
    await _enterTextByKey(
      tester,
      const ValueKey('condition-editor-name'),
      updatedConditionName,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('condition-editor-notes'),
      'UI 상태 수정 메모',
    );
    await _tapKey(tester, const ValueKey('condition-editor-save'));
    await _pumpUntilFound(tester, find.text(updatedConditionName));

    if (find
        .byKey(ValueKey('condition-delete-$conditionId'))
        .evaluate()
        .isEmpty) {
      await _expandTile(tester, updatedConditionName);
    }
    await _tapKey(tester, ValueKey('condition-delete-$conditionId'));
    await _tapKey(tester, const ValueKey('confirm-delete-button'));
    await _pumpUntilGone(tester, find.text(updatedConditionName));

    await _tapKey(tester, const ValueKey('medication-create-open'));
    await _enterTextByKey(
      tester,
      const ValueKey('medication-editor-name'),
      medicationName,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medication-editor-dosage'),
      '1정',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medication-editor-frequency'),
      '하루 1회',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medication-editor-started-on'),
      _dateInDays(-3),
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medication-editor-prescribed-by'),
      'UI 동물병원',
    );
    await _tapKey(tester, const ValueKey('medication-editor-save'));
    await _pumpUntilFound(tester, find.text(medicationName));

    final medicationId = await _waitForRecordId(
      () => api.medications(dogId),
      (item) => item['medicationName'] == medicationName,
    );
    await _expandTile(tester, medicationName);
    await _tapKey(tester, ValueKey('medication-edit-$medicationId'));
    await _enterTextByKey(
      tester,
      const ValueKey('medication-editor-name'),
      updatedMedicationName,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medication-editor-dosage'),
      '2정',
    );
    await _tapKey(tester, const ValueKey('medication-editor-save'));
    await _pumpUntilFound(tester, find.text(updatedMedicationName));

    if (find
        .byKey(ValueKey('medication-delete-$medicationId'))
        .evaluate()
        .isEmpty) {
      await _expandTile(tester, updatedMedicationName);
    }
    await _tapKey(tester, ValueKey('medication-delete-$medicationId'));
    await _tapKey(tester, const ValueKey('confirm-delete-button'));
    await _pumpUntilGone(tester, find.text(updatedMedicationName));
  });
}

Future<void> _pumpLoggedInApp(WidgetTester tester) async {
  await tester.pumpWidget(
    PawPlanApp(
      apiClient: ApiClient(baseUrl: _apiBaseUrl),
      notifications: LocalNotificationService(enabled: false),
      sessionStore: SessionStore(enabled: false),
    ),
  );

  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey('auth-submit-button')),
  );
  await _enterTextByKey(
    tester,
    const ValueKey('auth-email-field'),
    'demo@pawplan.kr',
  );
  await _enterTextByKey(
    tester,
    const ValueKey('auth-password-field'),
    'password123',
  );
  await _tapKey(tester, const ValueKey('auth-submit-button'));
  await _pumpUntilFound(tester, find.text('초코'));
}

Future<int> _loginDemoAndDogId(ApiClient api) async {
  await api.login(email: 'demo@pawplan.kr', password: 'password123');
  final dogs = await api.dogs();
  return _asInt(dogs.first['id'])!;
}

Future<void> _createHealthLogFromUi(WidgetTester tester, String title) async {
  await _enterTextByKey(tester, const ValueKey('quick-health-title'), title);
  await _enterTextByKey(tester, const ValueKey('quick-health-value'), '2');
  await _enterTextByKey(
    tester,
    const ValueKey('quick-health-memo'),
    'UI 테스트 메모',
  );
  await _tapKey(tester, const ValueKey('quick-health-submit'));
  await _pumpUntilFound(tester, find.text(title));
}

Future<void> _createExpenseFromUi(WidgetTester tester, String vendor) async {
  await _enterTextByKey(
    tester,
    const ValueKey('quick-expense-amount'),
    '39000',
  );
  await _enterTextByKey(tester, const ValueKey('quick-expense-vendor'), vendor);
  await _enterTextByKey(
    tester,
    const ValueKey('quick-expense-memo'),
    'UI 지출 메모',
  );
  await _tapKey(tester, const ValueKey('quick-expense-submit'));
}

Future<void> _createMedicalVisitFromUi(
  WidgetTester tester,
  String hospital,
) async {
  await _enterTextByKey(
    tester,
    const ValueKey('quick-medical-visit-hospital'),
    hospital,
  );
  await _enterTextByKey(
    tester,
    const ValueKey('quick-medical-visit-reason'),
    'UI 정기 진료',
  );
  await _enterTextByKey(
    tester,
    const ValueKey('quick-medical-visit-symptoms'),
    'UI 증상',
  );
  await _enterTextByKey(
    tester,
    const ValueKey('quick-medical-visit-diagnosis'),
    'UI 소견',
  );
  await _enterTextByKey(
    tester,
    const ValueKey('quick-medical-visit-treatment'),
    'UI 처치',
  );
  await _enterTextByKey(
    tester,
    const ValueKey('quick-medical-visit-prescribed'),
    'UI 처방',
  );
  await _enterTextByKey(
    tester,
    const ValueKey('quick-medical-visit-expense-amount'),
    '53000',
  );
  await _tapKey(tester, const ValueKey('quick-medical-visit-submit'));
}

Future<void> _expandMedicalVisit(WidgetTester tester, String hospital) async {
  final finder = find.text(hospital);
  await _pumpUntilFound(tester, finder);
  await _ensureFinderInViewport(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _expandTile(WidgetTester tester, String title) async {
  final finder = find.text(title);
  await _pumpUntilFound(tester, finder);
  await _ensureFinderInViewport(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<int> _waitForRecordId(
  Future<List<JsonMap>> Function() load,
  bool Function(JsonMap item) matches, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final items = await load();
    final found = items.where(matches);
    if (found.isNotEmpty) {
      return _asInt(found.first['id'])!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TestFailure('Timed out waiting for record id');
}

Future<void> _cleanupHealthLogs(
  ApiClient api,
  int dogId,
  List<String> titles,
) async {
  final logs = await api.healthLogs(dogId);
  for (final log in logs.where((item) => titles.contains(item['title']))) {
    final id = _asInt(log['id']);
    if (id != null) await api.deleteHealthLog(id);
  }
}

Future<void> _cleanupExpenses(
  ApiClient api,
  int dogId,
  List<String> vendors,
) async {
  final expenses = await api.expenses(dogId);
  for (final expense in expenses.where(
    (item) => vendors.contains(item['vendorName']),
  )) {
    final id = _asInt(expense['id']);
    if (id != null) await api.deleteExpense(id);
  }
}

Future<void> _cleanupMedicalVisits(
  ApiClient api,
  int dogId,
  List<String> hospitals,
) async {
  final visits = await api.medicalVisits(dogId);
  for (final visit in visits.where(
    (item) => hospitals.contains(item['hospitalName']),
  )) {
    final id = _asInt(visit['id']);
    if (id != null) await api.deleteMedicalVisit(id);
  }
}

Future<void> _cleanupConditions(
  ApiClient api,
  int dogId,
  List<String> names,
) async {
  final conditions = await api.conditions(dogId);
  for (final condition in conditions.where(
    (item) => names.contains(item['conditionName']),
  )) {
    final id = _asInt(condition['id']);
    if (id != null) await api.deleteCondition(id);
  }
}

Future<void> _cleanupMedications(
  ApiClient api,
  int dogId,
  List<String> names,
) async {
  final medications = await api.medications(dogId);
  for (final medication in medications.where(
    (item) => names.contains(item['medicationName']),
  )) {
    final id = _asInt(medication['id']);
    if (id != null) await api.deleteMedication(id);
  }
}

Future<void> _skipSchedulesByTitle(
  ApiClient api,
  int dogId,
  List<String> titles,
) async {
  final schedules = await api.careSchedules(dogId);
  for (final schedule in schedules.where(
    (item) => titles.contains(item['title']),
  )) {
    final id = _asInt(schedule['id']);
    if (id != null) await api.skipSchedule(id);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder to disappear');
}

Future<void> _tapDashboardTab(WidgetTester tester, String text) async {
  await _scrollDashboardToTop(tester);
  final key = switch (text) {
    '오늘' => const ValueKey('dashboard-tab-today'),
    '기록' => const ValueKey('dashboard-tab-records'),
    '정보' => const ValueKey('dashboard-tab-health-info'),
    '리포트' => const ValueKey('dashboard-tab-reports'),
    _ => throw ArgumentError('Unknown dashboard tab: $text'),
  };
  await _tapKey(tester, key);
}

Future<void> _refreshDashboard(WidgetTester tester) async {
  await _scrollDashboardToTop(tester);
  await _tapKey(tester, const ValueKey('dashboard-refresh-button'));
}

Future<void> _scrollDashboardToTop(WidgetTester tester) async {
  final scrollView = find.byType(CustomScrollView);
  if (scrollView.evaluate().isEmpty) return;

  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollView.first, const Offset(0, 700));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _pumpUntilFound(tester, finder);
  await _waitUntilIdle(tester);
  await _ensureFinderInViewport(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterTextByKey(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  await _pumpUntilFound(tester, finder);
  await _waitUntilIdle(tester);
  await _ensureFinderInViewport(tester, finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<void> _ensureFinderInViewport(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  if (_isFinderInViewport(tester, finder)) return;

  final scrollView = find.byType(CustomScrollView);
  if (scrollView.evaluate().isEmpty) return;

  for (var i = 0; i < 12; i++) {
    final center = tester.getCenter(finder);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final offset = center.dy > size.height
        ? const Offset(0, -260)
        : const Offset(0, 260);
    await tester.drag(scrollView.first, offset);
    await tester.pumpAndSettle();
    if (_isFinderInViewport(tester, finder)) return;
  }
}

bool _isFinderInViewport(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final center = tester.getCenter(finder);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return center.dx >= 0 &&
      center.dx <= size.width &&
      center.dy >= 0 &&
      center.dy <= size.height;
}

Future<void> _waitUntilIdle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final loading = find.byType(LinearProgressIndicator);
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (loading.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for app to become idle');
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _dateInDays(int days) {
  final date = DateTime.now().add(Duration(days: days));
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
