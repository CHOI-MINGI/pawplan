import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawplan_mobile/api/api_client.dart';
import 'package:pawplan_mobile/main.dart';
import 'package:pawplan_mobile/services/local_notification_service.dart';
import 'package:pawplan_mobile/services/session_store.dart';

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
final _apiBaseUrl = _configuredApiBaseUrl.isNotEmpty
    ? _configuredApiBaseUrl
    : resolveDefaultApiBaseUrl();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo account can manage records from the new UI', (
    tester,
  ) async {
    final api = ApiClient(baseUrl: _apiBaseUrl);
    final dogId = await _loginDemoAndDogId(api);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();

    final healthTitle = 'UI 건강 $suffix';
    final updatedHealthTitle = 'UI 건강 수정 $suffix';
    final expenseVendor = 'UI 지출 $suffix';
    final updatedExpenseVendor = 'UI 지출 수정 $suffix';
    final visitHospital = 'UI 병원 $suffix';
    final updatedVisitHospital = 'UI 병원 수정 $suffix';
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

    await _tapKey(tester, const ValueKey('today-create-health'));
    await _enterTextByKey(
      tester,
      const ValueKey('health-editor-title'),
      healthTitle,
    );
    await _enterTextByKey(tester, const ValueKey('health-editor-value'), '2');
    await _enterTextByKey(
      tester,
      const ValueKey('health-editor-memo'),
      '통합 테스트 건강 메모',
    );
    await _tapKey(tester, const ValueKey('health-editor-save'));
    await _tapKey(tester, const ValueKey('record-success-secondary'));

    final healthLogId = await _waitForRecordId(
      () => api.healthLogs(dogId),
      (item) => item['title'] == healthTitle,
    );

    await _tapKey(tester, const ValueKey('dashboard-tab-records'));
    await _pumpUntilFound(tester, find.text(healthTitle));
    await _openPopupAction(
      tester,
      ValueKey('health-log-menu-$healthLogId'),
      '수정',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('health-editor-title'),
      updatedHealthTitle,
    );
    await _tapKey(tester, const ValueKey('health-editor-save'));
    await _pumpUntilFound(tester, find.text(updatedHealthTitle));

    await _openPopupAction(
      tester,
      ValueKey('health-log-menu-$healthLogId'),
      '삭제',
    );
    await _pumpUntilGone(tester, find.text(updatedHealthTitle));

    await _tapKey(tester, const ValueKey('dashboard-tab-today'));
    await _tapKey(tester, const ValueKey('today-create-expense'));
    await _selectDropdownByKey(
      tester,
      const ValueKey('expense-editor-category'),
      '사료',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('expense-editor-amount'),
      '39000',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('expense-editor-vendor'),
      expenseVendor,
    );
    await _tapKey(tester, const ValueKey('expense-editor-save'));
    await _tapKey(tester, const ValueKey('record-success-secondary'));

    final expenseId = await _waitForRecordId(
      () => api.expenses(dogId),
      (item) =>
          item['vendorName'] == expenseVendor &&
          item['expenseCategory'] == 'food',
    );

    await _tapKey(tester, const ValueKey('dashboard-tab-records'));
    await _pumpUntilFound(tester, find.textContaining(expenseVendor));
    await _openPopupAction(tester, ValueKey('expense-menu-$expenseId'), '수정');
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

    await _openPopupAction(tester, ValueKey('expense-menu-$expenseId'), '삭제');
    await _pumpUntilGone(tester, find.textContaining(updatedExpenseVendor));

    await _tapKey(tester, const ValueKey('dashboard-tab-today'));
    await _tapKey(tester, const ValueKey('today-create-visit'));
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-hospital'),
      visitHospital,
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-symptoms'),
      '통합 테스트 증상',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-diagnosis'),
      '통합 테스트 진단',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-treatment'),
      '통합 테스트 처치',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-expense'),
      '53000',
    );
    await _tapKey(tester, const ValueKey('medical-visit-editor-save'));
    await _tapKey(tester, const ValueKey('record-success-secondary'));

    final visitId = await _waitForRecordId(
      () => api.medicalVisits(dogId),
      (item) => item['hospitalName'] == visitHospital,
    );

    await _tapKey(tester, const ValueKey('dashboard-tab-records'));
    await _scrollUntilFound(
      tester,
      find.byKey(ValueKey('medical-visit-menu-$visitId')),
    );

    await _openPopupAction(
      tester,
      ValueKey('medical-visit-menu-$visitId'),
      '수정',
    );
    await _enterTextByKey(
      tester,
      const ValueKey('medical-visit-editor-hospital'),
      updatedVisitHospital,
    );
    await _tapKey(tester, const ValueKey('medical-visit-editor-save'));
    await _pumpUntilFound(tester, find.text(updatedVisitHospital));

    await _openPopupAction(
      tester,
      ValueKey('medical-visit-menu-$visitId'),
      '삭제',
    );
    await _pumpUntilGone(tester, find.text(updatedVisitHospital));

    await _tapKey(tester, const ValueKey('dashboard-tab-reports'));
    await _tapKey(tester, const ValueKey('forecast-recalculate-button'));
    await _waitUntilIdle(tester);
    await _tapKey(tester, const ValueKey('report-generate-button'));
    await _waitUntilIdle(tester);
  });

  testWidgets(
    'demo account can update profile and manage schedules health status and medication',
    (tester) async {
      final api = ApiClient(baseUrl: _apiBaseUrl);
      final dogId = await _loginDemoAndDogId(api);
      final suffix = DateTime.now().millisecondsSinceEpoch.toString();

      final editedDogName = '초코 UI $suffix';
      final scheduleTitle = 'UI 일정 $suffix';
      final updatedScheduleTitle = 'UI 일정 수정 $suffix';
      final conditionName = 'UI 만성질환 $suffix';
      final updatedConditionName = 'UI 만성질환 수정 $suffix';
      final medicationName = 'UI 복약 $suffix';
      final updatedMedicationName = 'UI 복약 수정 $suffix';

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
            'notes': '특이사항 없는 기본 프로필입니다.',
          },
        );
        await _skipSchedulesByTitle(api, dogId, [
          scheduleTitle,
          updatedScheduleTitle,
        ]);
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
      await _waitForDogName(api, dogId, editedDogName);
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('schedule-create-open')),
      );

      await _tapKey(tester, const ValueKey('schedule-create-open'));
      await _enterTextByKey(
        tester,
        const ValueKey('schedule-editor-title'),
        scheduleTitle,
      );
      await _enterTextByKey(
        tester,
        const ValueKey('schedule-editor-description'),
        '통합 테스트 일정 메모',
      );
      await _tapKey(tester, const ValueKey('schedule-editor-save'));

      final scheduleId = await _waitForRecordId(
        () => api.careSchedules(dogId),
        (item) => item['title'] == scheduleTitle,
      );
      await _refreshActiveScreen(tester);
      await _scrollUntilFound(
        tester,
        find.byKey(ValueKey('schedule-edit-$scheduleId')),
      );
      await _tapKey(tester, ValueKey('schedule-edit-$scheduleId'));
      await _enterTextByKey(
        tester,
        const ValueKey('schedule-editor-title'),
        updatedScheduleTitle,
      );
      await _enterTextByKey(
        tester,
        const ValueKey('schedule-editor-description'),
        '통합 테스트 일정 수정 메모',
      );
      await _tapKey(tester, const ValueKey('schedule-editor-save'));
      await _waitForScheduleTitle(api, dogId, updatedScheduleTitle);
      await _refreshActiveScreen(tester);
      await _scrollUntilFound(
        tester,
        find.byKey(ValueKey('schedule-skip-$scheduleId')),
      );

      await _tapKey(tester, ValueKey('schedule-skip-$scheduleId'));
      await _pumpUntilGone(tester, find.text(updatedScheduleTitle));

      await _tapKey(tester, const ValueKey('dashboard-tab-health-info'));
      await _tapKey(tester, const ValueKey('condition-create-open'));
      await _enterTextByKey(
        tester,
        const ValueKey('condition-editor-name'),
        conditionName,
      );
      await _enterTextByKey(
        tester,
        const ValueKey('condition-editor-notes'),
        '통합 테스트 건강 상태 메모',
      );
      await _tapKey(tester, const ValueKey('condition-editor-save'));
      await _pumpUntilFound(tester, find.text(conditionName));

      final conditionId = await _waitForRecordId(
        () => api.conditions(dogId),
        (item) => item['conditionName'] == conditionName,
      );
      await _openPopupAction(
        tester,
        ValueKey('condition-menu-$conditionId'),
        '수정',
      );
      await _enterTextByKey(
        tester,
        const ValueKey('condition-editor-name'),
        updatedConditionName,
      );
      await _enterTextByKey(
        tester,
        const ValueKey('condition-editor-notes'),
        '통합 테스트 건강 상태 수정 메모',
      );
      await _tapKey(tester, const ValueKey('condition-editor-save'));
      await _pumpUntilFound(tester, find.text(updatedConditionName));

      await _openPopupAction(
        tester,
        ValueKey('condition-menu-$conditionId'),
        '삭제',
      );
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
        const ValueKey('medication-editor-prescribed-by'),
        'UI 동물병원',
      );
      await _tapKey(tester, const ValueKey('medication-editor-save'));
      await _pumpUntilFound(tester, find.text(medicationName));

      final medicationId = await _waitForRecordId(
        () => api.medications(dogId),
        (item) => item['medicationName'] == medicationName,
      );
      await _openPopupAction(
        tester,
        ValueKey('medication-menu-$medicationId'),
        '수정',
      );
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

      await _openPopupAction(
        tester,
        ValueKey('medication-menu-$medicationId'),
        '삭제',
      );
      await _pumpUntilGone(tester, find.text(updatedMedicationName));
    },
  );
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
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey('dashboard-tab-today')),
  );
  await _pumpUntilFound(tester, find.text('초코'));
}

Future<int> _loginDemoAndDogId(ApiClient api) async {
  await api.login(email: 'demo@pawplan.kr', password: 'password123');
  final dogs = await api.dogs();
  return _asInt(dogs.first['id'])!;
}

Future<void> _openPopupAction(
  WidgetTester tester,
  Key menuKey,
  String actionText,
) async {
  await _tapKey(tester, menuKey);
  final actionFinder = find.text(actionText);
  await _pumpUntilFound(tester, actionFinder);
  await tester.tap(actionFinder.last);
  await tester.pumpAndSettle();
}

Future<int> _waitForRecordId(
  Future<List<JsonMap>> Function() load,
  bool Function(JsonMap item) matches, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      final items = await load();
      final found = items.where(matches);
      if (found.isNotEmpty) {
        return _asInt(found.first['id'])!;
      }
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      continue;
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

Future<void> _waitForDogName(
  ApiClient api,
  int dogId,
  String expectedName, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      final dogs = await api.dogs();
      final dog = dogs.firstWhere(
        (item) => _asInt(item['id']) == dogId,
        orElse: () => <String, dynamic>{},
      );
      if (dog['name'] == expectedName) return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      continue;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TestFailure('Timed out waiting for dog name $expectedName');
}

Future<void> _waitForScheduleTitle(
  ApiClient api,
  int dogId,
  String expectedTitle, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      final schedules = await api.careSchedules(dogId);
      if (schedules.any((item) => item['title'] == expectedTitle)) return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      continue;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TestFailure('Timed out waiting for schedule title $expectedTitle');
}

Future<void> _refreshActiveScreen(WidgetTester tester) async {
  final scrollView = find.byType(CustomScrollView);
  if (scrollView.evaluate().isEmpty) return;
  await tester.drag(scrollView.first, const Offset(0, 420));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  final scrollView = find.byType(CustomScrollView);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    if (scrollView.evaluate().isEmpty) continue;
    await tester.drag(scrollView.first, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
  throw TestFailure('Timed out scrolling to $finder');
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

Future<void> _selectDropdownByKey(
  WidgetTester tester,
  Key key,
  String optionText,
) async {
  await _tapKey(tester, key);
  final option = find.text(optionText).last;
  await _pumpUntilFound(tester, option);
  await tester.tap(option);
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
