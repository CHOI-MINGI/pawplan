import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api/api_client.dart';
import 'services/local_notification_service.dart';
import 'services/session_store.dart';

const _bg = Color(0xFFFFF8F4);
const _surface = Color(0xFFFFFFFF);
const _surfaceSoft = Color(0xFFFFEFE7);
const _surfaceBorder = Color(0xFFE7CEC3);
const _text = Color(0xFF1F1B17);
const _textMuted = Color(0xFF6D5D57);
const _primary = Color(0xFF9B4428);
const _primarySoft = Color(0xFFE68967);
const _secondary = Color(0xFF4A654A);
const _health = Color(0xFF7BA7CC);
const _hospital = Color(0xFF9B89B3);
const _expense = Color(0xFFE3B65C);
const _danger = Color(0xFFD9534F);

const _expenseCategoryLabels = {
  'food': '사료',
  'snack': '간식',
  'grooming': '미용',
  'insurance': '보험',
  'supplies': '용품',
  'hospital': '병원',
  'medication': '복약',
  'checkup': '검진',
  'vaccine': '예방접종',
  'prevention': '예방약',
  'dental_care': '치과관리',
  'emergency': '응급',
  'surgery': '수술',
  'dental_treatment': '치과치료',
  'skin_treatment': '피부·귀 치료',
  'eye_treatment': '안과치료',
  'joint_treatment': '관절치료',
  'digestive_treatment': '소화기치료',
  'other': '기타',
};

const _scheduleTypeLabels = {
  'medication': '복약',
  'heartworm': '심장사상충',
  'deworming': '구충',
  'vaccine': '예방접종',
  'checkup': '건강검진',
  'grooming': '미용·위생',
  'custom': '기타',
};

enum _RootPhase { booting, auth, onboarding, shell }

enum _DashboardTab { today, records, health, reports }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = LocalNotificationService();
  await notifications.initialize();
  runApp(
    PawPlanApp(
      apiClient: ApiClient(),
      notifications: notifications,
      sessionStore: SessionStore(),
    ),
  );
}

class PawPlanApp extends StatelessWidget {
  const PawPlanApp({
    super.key,
    ApiClient? apiClient,
    LocalNotificationService? notifications,
    SessionStore? sessionStore,
  }) : _apiClient = apiClient,
       _notifications = notifications,
       _sessionStore = sessionStore;

  final ApiClient? _apiClient;
  final LocalNotificationService? _notifications;
  final SessionStore? _sessionStore;

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: _primary,
          secondary: _secondary,
          surface: _surface,
          onSurface: _text,
        );

    return MaterialApp(
      title: 'PawPlan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _bg,
        fontFamily: 'Quicksand',
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _text,
          displayColor: _text,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
      ),
      home: _PawPlanRoot(
        apiClient: _apiClient ?? ApiClient(),
        notifications: _notifications ?? LocalNotificationService(),
        sessionStore: _sessionStore ?? SessionStore(),
      ),
    );
  }
}

class _PawPlanRoot extends StatefulWidget {
  const _PawPlanRoot({
    required this.apiClient,
    required this.notifications,
    required this.sessionStore,
  });

  final ApiClient apiClient;
  final LocalNotificationService notifications;
  final SessionStore sessionStore;

  @override
  State<_PawPlanRoot> createState() => _PawPlanRootState();
}

class _PawPlanRootState extends State<_PawPlanRoot> {
  _RootPhase _phase = _RootPhase.booting;
  _DashboardTab _tab = _DashboardTab.today;
  bool _busy = false;
  String? _error;

  JsonMap? _dashboard;
  JsonMap? _forecast;
  JsonMap? _latestReport;

  final List<JsonMap> _dogs = [];
  final List<JsonMap> _schedules = [];
  final List<JsonMap> _healthLogs = [];
  final List<JsonMap> _expenses = [];
  final List<JsonMap> _medicalVisits = [];
  final List<JsonMap> _conditions = [];
  final List<JsonMap> _medications = [];
  final List<JsonMap> _visitReports = [];
  final List<JsonMap> _members = [];
  final List<JsonMap> _activity = [];

  int? _selectedDogId;

  JsonMap? get _selectedDog {
    for (final dog in _dogs) {
      if (_asInt(dog['id']) == _selectedDogId) {
        return dog;
      }
    }
    return _dogs.isEmpty ? null : _dogs.first;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await widget.sessionStore.readToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _phase = _RootPhase.auth);
      return;
    }

    widget.apiClient.setSessionToken(token);
    try {
      await widget.apiClient.me();
      await _loadDogs(refreshDashboard: true);
    } catch (_) {
      widget.apiClient.clearSession();
      await widget.sessionStore.clear();
      if (!mounted) return;
      setState(() => _phase = _RootPhase.auth);
    }
  }

  Future<T> _runBusy<T>(Future<T> Function() action) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      return await action();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
      rethrow;
    } catch (_) {
      if (mounted) {
        setState(() => _error = '알 수 없는 오류가 발생했습니다.');
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<T?> _safeLoad<T>(Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadDogs({bool refreshDashboard = false}) async {
    final dogs = await widget.apiClient.dogs();
    final previousDogId = _selectedDogId;
    final nextDogId = dogs.any((dog) => _asInt(dog['id']) == previousDogId)
        ? previousDogId
        : (dogs.isEmpty ? null : _asInt(dogs.first['id']));

    if (!mounted) return;
    setState(() {
      _dogs
        ..clear()
        ..addAll(dogs);
      _selectedDogId = nextDogId;
    });

    if (dogs.isEmpty) {
      if (!mounted) return;
      setState(() {
        _phase = _RootPhase.onboarding;
        _clearDashboardData();
      });
      return;
    }

    if (refreshDashboard) {
      await _loadDashboard();
    }

    if (!mounted) return;
    setState(() => _phase = _RootPhase.shell);
  }

  void _clearDashboardData() {
    _dashboard = null;
    _forecast = null;
    _latestReport = null;
    _schedules.clear();
    _healthLogs.clear();
    _expenses.clear();
    _medicalVisits.clear();
    _conditions.clear();
    _medications.clear();
    _visitReports.clear();
    _members.clear();
    _activity.clear();
  }

  Future<void> _loadDashboard() async {
    final dogId = _selectedDogId;
    if (dogId == null) return;

    final results = await Future.wait<dynamic>([
      widget.apiClient.dashboard(dogId),
      widget.apiClient.careSchedules(dogId),
      widget.apiClient.healthLogs(dogId),
      widget.apiClient.expenses(dogId),
      widget.apiClient.medicalVisits(dogId),
      widget.apiClient.conditions(dogId),
      widget.apiClient.medications(dogId),
      _safeLoad(() => widget.apiClient.latestForecast(dogId)),
      _safeLoad(() => widget.apiClient.latestVisitReport(dogId)),
      widget.apiClient.visitReports(dogId),
    ]);

    if (!mounted) return;
    setState(() {
      _dashboard = results[0] as JsonMap;
      _schedules
        ..clear()
        ..addAll((results[1] as List<JsonMap>)..sort(_compareScheduleDate));
      _healthLogs
        ..clear()
        ..addAll((results[2] as List<JsonMap>)..sort(_compareByEventDateDesc));
      _expenses
        ..clear()
        ..addAll((results[3] as List<JsonMap>)..sort(_compareByEventDateDesc));
      _medicalVisits
        ..clear()
        ..addAll((results[4] as List<JsonMap>)..sort(_compareByEventDateDesc));
      _conditions
        ..clear()
        ..addAll((results[5] as List<JsonMap>)..sort(_compareByUpdatedAtDesc));
      _medications
        ..clear()
        ..addAll((results[6] as List<JsonMap>)..sort(_compareByUpdatedAtDesc));
      _forecast = results[7] as JsonMap?;
      _latestReport = results[8] as JsonMap?;
      _visitReports
        ..clear()
        ..addAll((results[9] as List<JsonMap>)..sort(_compareByUpdatedAtDesc));
      final collaboration = _dashboard?['collaboration'] as JsonMap?;
      _members
        ..clear()
        ..addAll(
          ((collaboration?['members'] as List<dynamic>?) ?? const [])
              .cast<JsonMap>(),
        );
      _activity
        ..clear()
        ..addAll(
          ((collaboration?['recentActivity'] as List<dynamic>?) ?? const [])
              .cast<JsonMap>(),
        );
    });

    await widget.notifications.syncCareReminders(_schedules);
  }

  Future<void> _refreshShell() async {
    await _runBusy(_loadDashboard);
  }

  Future<void> _login(String email, String password) async {
    await _runBusy(() async {
      await widget.apiClient.login(email: email, password: password);
      final token = widget.apiClient.accessToken;
      if (token != null) {
        await widget.sessionStore.saveToken(token);
      }
      await _loadDogs(refreshDashboard: true);
    });
  }

  Future<void> _register(String email, String password, String name) async {
    await _runBusy(() async {
      await widget.apiClient.register(
        email: email,
        password: password,
        name: name,
      );
      await widget.apiClient.login(email: email, password: password);
      final token = widget.apiClient.accessToken;
      if (token != null) {
        await widget.sessionStore.saveToken(token);
      }
      await _loadDogs(refreshDashboard: true);
    });
  }

  Future<void> _submitOnboarding({
    required JsonMap dog,
    required List<JsonMap> conditions,
  }) async {
    await _runBusy(() async {
      await widget.apiClient.onboardDog({
        'dog': dog,
        'conditions': conditions,
        'baseDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      await _loadDogs(refreshDashboard: true);
    });
  }

  Future<void> _updateDog(JsonMap payload, {Uint8List? avatarBytes}) async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.updateDog(dogId: dogId, payload: payload);
      await _loadDogs(refreshDashboard: true);
    });
  }

  Future<void> _createSchedule({
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    int? repeatCycleDays,
    int? assignedToUserId,
  }) async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.createCareSchedule(
        dogId: dogId,
        scheduleType: scheduleType,
        title: title,
        dueDate: dueDate,
        description: description,
        priority: priority,
        repeatCycleDays: repeatCycleDays,
        assignedToUserId: assignedToUserId,
      );
      await _loadDashboard();
    });
  }

  Future<void> _updateSchedule({
    required int scheduleId,
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    required bool reminderEnabled,
    int? repeatCycleDays,
    int? assignedToUserId,
  }) async {
    await _runBusy(() async {
      await widget.apiClient.updateCareSchedule(
        scheduleId: scheduleId,
        scheduleType: scheduleType,
        title: title,
        dueDate: dueDate,
        description: description,
        priority: priority,
        reminderEnabled: reminderEnabled,
        repeatCycleDays: repeatCycleDays,
        assignedToUserId: assignedToUserId,
      );
      await _loadDashboard();
    });
  }

  Future<void> _skipSchedule(int scheduleId) async {
    await _runBusy(() async {
      await widget.apiClient.skipSchedule(scheduleId);
      await _loadDashboard();
    });
  }

  Future<void> _completeSchedule(int scheduleId) async {
    await _runBusy(() async {
      await widget.apiClient.completeSchedule(scheduleId);
      await _loadDashboard();
    });
  }

  Future<void> _createHealthLog({
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
    bool isSensitive = false,
  }) async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.createHealthLog(
        dogId: dogId,
        logType: logType,
        title: title,
        memo: memo,
        recordedAt: DateTime.now().toIso8601String(),
        valueNumeric: valueNumeric,
        valueUnit: valueUnit,
        isSensitive: isSensitive,
      );
      await _loadDashboard();
    });
  }

  Future<void> _updateHealthLog({
    required int logId,
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
    bool isSensitive = false,
  }) async {
    await _runBusy(() async {
      await widget.apiClient.updateHealthLog(
        logId: logId,
        logType: logType,
        title: title,
        memo: memo,
        recordedAt: DateTime.now().toIso8601String(),
        valueNumeric: valueNumeric,
        valueUnit: valueUnit,
        isSensitive: isSensitive,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteHealthLog(int logId) async {
    await _runBusy(() async {
      await widget.apiClient.deleteHealthLog(logId);
      await _loadDashboard();
    });
  }

  Future<void> _createExpense({
    required String category,
    required num amount,
    required String expenseDate,
    required String vendorName,
    required String memo,
    bool isSensitive = false,
  }) async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.createExpense(
        dogId: dogId,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        vendorName: vendorName,
        memo: memo,
        isSensitive: isSensitive,
      );
      await _loadDashboard();
    });
  }

  Future<void> _updateExpense({
    required int expenseId,
    required String category,
    required num amount,
    required String expenseDate,
    required String vendorName,
    required String memo,
    bool isSensitive = false,
  }) async {
    await _runBusy(() async {
      await widget.apiClient.updateExpense(
        expenseId: expenseId,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        vendorName: vendorName,
        memo: memo,
        isSensitive: isSensitive,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteExpense(int expenseId) async {
    await _runBusy(() async {
      await widget.apiClient.deleteExpense(expenseId);
      await _loadDashboard();
    });
  }

  Future<void> _createMedicalVisit({
    required String hospitalName,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required num? expenseAmount,
    bool isSensitive = false,
  }) async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _runBusy(() async {
      await widget.apiClient.createMedicalVisit(
        dogId: dogId,
        hospitalName: hospitalName,
        visitDate: today,
        visitReason: symptoms.trim().isEmpty ? diagnosis : symptoms,
        symptoms: symptoms,
        diagnosis: diagnosis,
        treatment: treatment,
        prescribedItems: '',
        followUpDate: '',
        notes: '',
        expenseAmount: expenseAmount,
        expenseDate: today,
        expenseMemo: '병원 방문 지출',
        isSensitive: isSensitive,
      );
      await _loadDashboard();
    });
  }

  Future<void> _updateMedicalVisit({
    required int visitId,
    required String hospitalName,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required String notes,
    bool isSensitive = false,
  }) async {
    await _runBusy(() async {
      await widget.apiClient.updateMedicalVisit(
        visitId: visitId,
        hospitalName: hospitalName,
        visitReason: visitReason,
        symptoms: symptoms,
        diagnosis: diagnosis,
        treatment: treatment,
        prescribedItems: prescribedItems,
        followUpDate: followUpDate,
        notes: notes,
        isSensitive: isSensitive,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteMedicalVisit(int visitId) async {
    await _runBusy(() async {
      await widget.apiClient.deleteMedicalVisit(visitId);
      await _loadDashboard();
    });
  }

  Future<void> _createCondition({
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
  }) async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.createCondition(
        dogId: dogId,
        conditionType: conditionType,
        conditionName: conditionName,
        severity: severity,
        diagnosedOn: diagnosedOn,
        status: status,
        notes: notes,
      );
      await _loadDashboard();
    });
  }

  Future<void> _updateCondition({
    required int conditionId,
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
  }) async {
    await _runBusy(() async {
      await widget.apiClient.updateCondition(
        conditionId: conditionId,
        conditionType: conditionType,
        conditionName: conditionName,
        severity: severity,
        diagnosedOn: diagnosedOn,
        status: status,
        notes: notes,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteCondition(int conditionId) async {
    await _runBusy(() async {
      await widget.apiClient.deleteCondition(conditionId);
      await _loadDashboard();
    });
  }

  Future<void> _createMedication({
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
  }) async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.createMedication(
        dogId: dogId,
        medicationName: medicationName,
        dosage: dosage,
        frequencyText: frequencyText,
        startedOn: startedOn,
        endedOn: endedOn,
        prescribedBy: prescribedBy,
        isActive: isActive,
        notes: notes,
      );
      await _loadDashboard();
    });
  }

  Future<void> _updateMedication({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
  }) async {
    await _runBusy(() async {
      await widget.apiClient.updateMedication(
        medicationId: medicationId,
        medicationName: medicationName,
        dosage: dosage,
        frequencyText: frequencyText,
        startedOn: startedOn,
        endedOn: endedOn,
        prescribedBy: prescribedBy,
        isActive: isActive,
        notes: notes,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteMedication(int medicationId) async {
    await _runBusy(() async {
      await widget.apiClient.deleteMedication(medicationId);
      await _loadDashboard();
    });
  }

  Future<void> _recalculateForecast() async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.recalculateForecast(dogId);
      await _loadDashboard();
    });
  }

  Future<void> _generateReport() async {
    final dogId = _selectedDogId;
    if (dogId == null) return;
    await _runBusy(() async {
      await widget.apiClient.generateVisitReport(dogId);
      await _loadDashboard();
      final dogName = _selectedDog?['name'] as String? ?? '반려견';
      await widget.notifications.showReportReady(dogName);
    });
  }

  Future<void> _openDogEditor() async {
    final dog = _selectedDog;
    if (dog == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DogEditorScreen(dog: dog, onSave: _updateDog),
      ),
    );
  }

  Future<void> _openScheduleEditor({JsonMap? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ScheduleEditorScreen(
          existing: existing,
          members: _members,
          onCreate: _createSchedule,
          onUpdate: _updateSchedule,
        ),
      ),
    );
  }

  Future<void> _openHealthLogEditor({JsonMap? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HealthLogEditorScreen(
          existing: existing,
          onCreate: _createHealthLog,
          onUpdate: _updateHealthLog,
        ),
      ),
    );
  }

  Future<void> _openExpenseEditor({JsonMap? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ExpenseEditorScreen(
          existing: existing,
          onCreate: _createExpense,
          onUpdate: _updateExpense,
        ),
      ),
    );
  }

  Future<void> _openMedicalVisitEditor({JsonMap? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MedicalVisitEditorScreen(
          existing: existing,
          onCreate: _createMedicalVisit,
          onUpdate: _updateMedicalVisit,
        ),
      ),
    );
  }

  Future<void> _openConditionEditor({JsonMap? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConditionEditorSheet(
        existing: existing,
        onCreate: _createCondition,
        onUpdate: _updateCondition,
      ),
    );
  }

  Future<void> _openMedicationEditor({JsonMap? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedicationEditorSheet(
        existing: existing,
        onCreate: _createMedication,
        onUpdate: _updateMedication,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _RootPhase.booting => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _RootPhase.auth => _AuthScreen(
        busy: _busy,
        error: _error,
        onLogin: _login,
        onRegister: _register,
      ),
      _RootPhase.onboarding => _OnboardingScreen(
        busy: _busy,
        error: _error,
        onSubmit: _submitOnboarding,
      ),
      _RootPhase.shell => _buildShell(),
    };
  }

  Widget _buildShell() {
    final dog = _selectedDog;
    final access = (_dashboard?['access'] as JsonMap?) ?? const {};
    final canEditRecords =
        access['canEditRecords'] == true ||
        access['role'] == 'owner' ||
        access['role'] == 'editor';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dog?['name'] as String? ?? 'PawPlan',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _tabTitle(_tab),
              style: const TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('dashboard-refresh-button'),
            onPressed: _busy ? null : _refreshShell,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (_dogs.length > 1)
            PopupMenuButton<int>(
              key: const ValueKey('page-header-dog-switcher'),
              onSelected: (dogId) => _runBusy(() async {
                setState(() => _selectedDogId = dogId);
                await _loadDashboard();
              }),
              itemBuilder: (context) => _dogs
                  .map(
                    (item) => PopupMenuItem<int>(
                      value: _asInt(item['id']),
                      child: Text(item['name'] as String? ?? '반려견'),
                    ),
                  )
                  .toList(),
              child: const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.expand_more_rounded),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFE5DE),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: _danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: switch (_tab) {
              _DashboardTab.today => _TodayTab(
                dog: dog,
                dashboard: _dashboard,
                access: access,
                members: _members,
                activity: _activity,
                schedules: _schedules,
                canEditRecords: canEditRecords,
                onRefresh: _refreshShell,
                onOpenProfile: _openDogEditor,
                onCreateSchedule: () => _openScheduleEditor(),
                onEditSchedule: (item) => _openScheduleEditor(existing: item),
                onSkipSchedule: _skipSchedule,
                onCompleteSchedule: _completeSchedule,
                onCreateHealthLog: () => _openHealthLogEditor(),
                onCreateExpense: () => _openExpenseEditor(),
                onCreateMedicalVisit: () => _openMedicalVisitEditor(),
              ),
              _DashboardTab.records => _RecordsTab(
                healthLogs: _healthLogs,
                expenses: _expenses,
                visits: _medicalVisits,
                canEditRecords: canEditRecords,
                onRefresh: _refreshShell,
                onEditHealth: (item) => _openHealthLogEditor(existing: item),
                onDeleteHealth: _deleteHealthLog,
                onEditExpense: (item) => _openExpenseEditor(existing: item),
                onDeleteExpense: _deleteExpense,
                onEditVisit: (item) => _openMedicalVisitEditor(existing: item),
                onDeleteVisit: _deleteMedicalVisit,
              ),
              _DashboardTab.health => _HealthTab(
                conditions: _conditions,
                medications: _medications,
                canEditRecords: canEditRecords,
                onRefresh: _refreshShell,
                onCreateCondition: () => _openConditionEditor(),
                onEditCondition: (item) => _openConditionEditor(existing: item),
                onDeleteCondition: _deleteCondition,
                onCreateMedication: () => _openMedicationEditor(),
                onEditMedication: (item) =>
                    _openMedicationEditor(existing: item),
                onDeleteMedication: _deleteMedication,
              ),
              _DashboardTab.reports => _ReportsTab(
                forecast: _forecast,
                latestReport: _latestReport,
                visitReports: _visitReports,
                onRefresh: _refreshShell,
                onRecalculate: _recalculateForecast,
                onGenerate: _generateReport,
              ),
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) {
          setState(() => _tab = _DashboardTab.values[index]);
        },
        destinations: const [
          NavigationDestination(
            key: ValueKey('dashboard-tab-today'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '오늘',
          ),
          NavigationDestination(
            key: ValueKey('dashboard-tab-records'),
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: '기록',
          ),
          NavigationDestination(
            key: ValueKey('dashboard-tab-health-info'),
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '건강',
          ),
          NavigationDestination(
            key: ValueKey('dashboard-tab-reports'),
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: '리포트',
          ),
        ],
      ),
    );
  }
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen({
    required this.busy,
    required this.error,
    required this.onLogin,
    required this.onRegister,
  });

  final bool busy;
  final String? error;
  final Future<void> Function(String email, String password) onLogin;
  final Future<void> Function(String email, String password, String name)
  onRegister;

  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final _email = TextEditingController(text: 'demo@pawplan.kr');
  final _password = TextEditingController(text: 'password123');
  final _name = TextEditingController();
  bool _registerMode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      if (_registerMode) {
        await widget.onRegister(
          _email.text.trim(),
          _password.text.trim(),
          _name.text.trim().isEmpty ? '보호자' : _name.text.trim(),
        );
      } else {
        await widget.onLogin(_email.text.trim(), _password.text.trim());
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.error ?? '로그인에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bg, Color(0xFFFFFBF8)],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE7DB),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(
                              Icons.pets_rounded,
                              size: 56,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'PawPlan',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _registerMode
                                ? '가족과 함께 반려견 기록을 시작하세요.'
                                : '매일의 건강 기록과 지출, 병원 기록을 한 곳에서 관리하세요.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: _textMuted,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _SectionCard(
                            child: Column(
                              children: [
                                if (_registerMode) ...[
                                  TextField(
                                    key: const ValueKey('auth-name-field'),
                                    controller: _name,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: '이름',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                TextField(
                                  key: const ValueKey('auth-email-field'),
                                  controller: _email,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '이메일',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  key: const ValueKey('auth-password-field'),
                                  controller: _password,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: '비밀번호',
                                  ),
                                ),
                                if (widget.error != null) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    widget.error!,
                                    style: const TextStyle(
                                      color: _danger,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    key: const ValueKey('auth-submit-button'),
                                    onPressed: widget.busy ? null : _submit,
                                    style: _primaryButtonStyle(),
                                    child: Text(_registerMode ? '회원가입' : '로그인'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: widget.busy
                                      ? null
                                      : () {
                                          setState(
                                            () =>
                                                _registerMode = !_registerMode,
                                          );
                                        },
                                  child: Text(
                                    _registerMode
                                        ? '이미 계정이 있나요? 로그인'
                                        : '계정이 없나요? 회원가입',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final bool busy;
  final String? error;
  final Future<void> Function({
    required JsonMap dog,
    required List<JsonMap> conditions,
  })
  onSubmit;

  @override
  State<_OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<_OnboardingScreen> {
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _birthDate = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime(2021, 4, 18)),
  );
  final _currentWeight = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _birthDate.dispose();
    _currentWeight.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_birthDate.text) ?? DateTime(2021, 4, 18),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _birthDate.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  Future<void> _submit() async {
    try {
      await widget.onSubmit(
        dog: {
          'name': _name.text.trim(),
          'breed': _breed.text.trim(),
          'birthDate': _birthDate.text.trim(),
          'sex': 'female',
          'neutered': true,
          'currentWeightKg': num.tryParse(_currentWeight.text.trim()),
          'targetWeightKg': num.tryParse(_currentWeight.text.trim()),
          'activityLevel': 'medium',
          'insuranceStatus': 'none',
          'notes': '',
        },
        conditions: const [],
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.error ?? '온보딩에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '첫 반려견을 등록해볼까요?',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '기본 프로필만 입력하면 바로 대시보드로 이동합니다.',
                          style: TextStyle(fontSize: 15, color: _textMuted),
                        ),
                        const SizedBox(height: 24),
                        _SectionCard(
                          child: Column(
                            children: [
                              TextField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: '이름',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _breed,
                                decoration: const InputDecoration(
                                  labelText: '견종',
                                ),
                              ),
                              const SizedBox(height: 14),
                              _DateTile(
                                label: '생일',
                                value: _birthDate.text,
                                onTap: _pickBirthDate,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _currentWeight,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '현재 체중 (kg)',
                                ),
                              ),
                              if (widget.error != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  widget.error!,
                                  style: const TextStyle(
                                    color: _danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: widget.busy ? null : _submit,
                                  style: _primaryButtonStyle(),
                                  child: const Text('시작하기'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.dog,
    required this.dashboard,
    required this.access,
    required this.members,
    required this.activity,
    required this.schedules,
    required this.canEditRecords,
    required this.onRefresh,
    required this.onOpenProfile,
    required this.onCreateSchedule,
    required this.onEditSchedule,
    required this.onSkipSchedule,
    required this.onCompleteSchedule,
    required this.onCreateHealthLog,
    required this.onCreateExpense,
    required this.onCreateMedicalVisit,
  });

  final JsonMap? dog;
  final JsonMap? dashboard;
  final JsonMap access;
  final List<JsonMap> members;
  final List<JsonMap> activity;
  final List<JsonMap> schedules;
  final bool canEditRecords;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onCreateSchedule;
  final Future<void> Function(JsonMap item) onEditSchedule;
  final Future<void> Function(int scheduleId) onSkipSchedule;
  final Future<void> Function(int scheduleId) onCompleteSchedule;
  final Future<void> Function() onCreateHealthLog;
  final Future<void> Function() onCreateExpense;
  final Future<void> Function() onCreateMedicalVisit;

  @override
  Widget build(BuildContext context) {
    final todaySchedules =
        (dashboard?['todaySchedules'] as List<dynamic>?)?.cast<JsonMap>() ??
        schedules;

    return _ScrollableTab(
      onRefresh: onRefresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _HeroCard(dog: dog, onOpenProfile: onOpenProfile),
              const SizedBox(height: 16),
              _FamilyCollaborationPanel(
                access: access,
                members: members,
                schedules: todaySchedules,
                activity: activity,
                hiddenSensitiveCounts:
                    (dashboard?['collaboration']
                            as JsonMap?)?['hiddenSensitiveCounts']
                        as JsonMap?,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '빠른 기록',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!canEditRecords)
                      const _EmptyLine(
                        '보기 권한으로 참여 중입니다. 기록 수정은 owner/editor만 가능합니다.',
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ActionPill(
                            key: const ValueKey('today-create-health'),
                            label: '건강 기록',
                            icon: Icons.favorite_rounded,
                            color: _health,
                            onTap: onCreateHealthLog,
                          ),
                          _ActionPill(
                            key: const ValueKey('today-create-expense'),
                            label: '지출 기록',
                            icon: Icons.payments_outlined,
                            color: _expense,
                            onTap: onCreateExpense,
                          ),
                          _ActionPill(
                            key: const ValueKey('today-create-visit'),
                            label: '병원 기록',
                            icon: Icons.local_hospital_outlined,
                            color: _hospital,
                            onTap: onCreateMedicalVisit,
                          ),
                          _ActionPill(
                            key: const ValueKey('schedule-create-open'),
                            label: '일정 추가',
                            icon: Icons.add_task_rounded,
                            color: _primarySoft,
                            onTap: onCreateSchedule,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '케어 플랜',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CarePlanOverview(schedules: todaySchedules),
                    const SizedBox(height: 14),
                    if (todaySchedules.isEmpty)
                      const Text(
                        '예정된 일정이 없어요.',
                        style: TextStyle(color: _textMuted),
                      )
                    else
                      ...todaySchedules.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ScheduleCard(
                            item: item,
                            canEdit: canEditRecords,
                            onEdit: () => onEditSchedule(item),
                            onSkip: () {
                              final id = _asInt(item['id']);
                              if (id != null) return onSkipSchedule(id);
                              return Future<void>.value();
                            },
                            onComplete: () {
                              final id = _asInt(item['id']);
                              if (id != null) return onCompleteSchedule(id);
                              return Future<void>.value();
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _RecordsTab extends StatelessWidget {
  const _RecordsTab({
    required this.healthLogs,
    required this.expenses,
    required this.visits,
    required this.canEditRecords,
    required this.onRefresh,
    required this.onEditHealth,
    required this.onDeleteHealth,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.onEditVisit,
    required this.onDeleteVisit,
  });

  final List<JsonMap> healthLogs;
  final List<JsonMap> expenses;
  final List<JsonMap> visits;
  final bool canEditRecords;
  final Future<void> Function() onRefresh;
  final Future<void> Function(JsonMap item) onEditHealth;
  final Future<void> Function(int id) onDeleteHealth;
  final Future<void> Function(JsonMap item) onEditExpense;
  final Future<void> Function(int id) onDeleteExpense;
  final Future<void> Function(JsonMap item) onEditVisit;
  final Future<void> Function(int id) onDeleteVisit;

  @override
  Widget build(BuildContext context) {
    return _ScrollableTab(
      onRefresh: onRefresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _RecordsSection(
                title: '건강 로그',
                children: healthLogs.isEmpty
                    ? const [_EmptyLine('건강 로그가 아직 없습니다.')]
                    : healthLogs
                          .map(
                            (item) => _MenuRecordCard(
                              title: item['title'] as String? ?? '건강 기록',
                              subtitle: [
                                if ((item['memo'] as String?)?.isNotEmpty ??
                                    false)
                                  item['memo'] as String,
                                _formatDate(item['recordedAt'] as String?),
                              ].where((value) => value.isNotEmpty).join(' · '),
                              icon: Icons.favorite_rounded,
                              color: _health,
                              collaboration: item['collaboration'] as JsonMap?,
                              canEdit: canEditRecords,
                              menuKey: ValueKey(
                                'health-log-menu-${item['id']}',
                              ),
                              onEdit: () => onEditHealth(item),
                              onDelete: () {
                                final id = _asInt(item['id']);
                                if (id != null) return onDeleteHealth(id);
                                return Future<void>.value();
                              },
                            ),
                          )
                          .toList(),
              ),
              const SizedBox(height: 16),
              _RecordsSection(
                title: '지출',
                children: expenses.isEmpty
                    ? const [_EmptyLine('지출 기록이 아직 없습니다.')]
                    : expenses
                          .map(
                            (item) => _MenuRecordCard(
                              title: item['vendorName'] as String? ?? '지출',
                              subtitle:
                                  '${_won(item['amount'])} · ${_formatDate(item['expenseDate'] as String?)}',
                              icon: Icons.payments_outlined,
                              color: _expense,
                              collaboration: item['collaboration'] as JsonMap?,
                              canEdit: canEditRecords,
                              menuKey: ValueKey('expense-menu-${item['id']}'),
                              onEdit: () => onEditExpense(item),
                              onDelete: () {
                                final id = _asInt(item['id']);
                                if (id != null) return onDeleteExpense(id);
                                return Future<void>.value();
                              },
                            ),
                          )
                          .toList(),
              ),
              const SizedBox(height: 16),
              _RecordsSection(
                title: '병원 방문',
                children: visits.isEmpty
                    ? const [_EmptyLine('병원 방문 기록이 아직 없습니다.')]
                    : visits
                          .map(
                            (item) => _MenuRecordCard(
                              title: item['hospitalName'] as String? ?? '병원 기록',
                              subtitle: [
                                item['symptoms'] as String? ?? '',
                                _formatDate(item['visitDate'] as String?),
                              ].where((value) => value.isNotEmpty).join(' · '),
                              icon: Icons.local_hospital_outlined,
                              color: _hospital,
                              collaboration: item['collaboration'] as JsonMap?,
                              canEdit: canEditRecords,
                              menuKey: ValueKey(
                                'medical-visit-menu-${item['id']}',
                              ),
                              onEdit: () => onEditVisit(item),
                              onDelete: () {
                                final id = _asInt(item['id']);
                                if (id != null) return onDeleteVisit(id);
                                return Future<void>.value();
                              },
                            ),
                          )
                          .toList(),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HealthTab extends StatelessWidget {
  const _HealthTab({
    required this.conditions,
    required this.medications,
    required this.canEditRecords,
    required this.onRefresh,
    required this.onCreateCondition,
    required this.onEditCondition,
    required this.onDeleteCondition,
    required this.onCreateMedication,
    required this.onEditMedication,
    required this.onDeleteMedication,
  });

  final List<JsonMap> conditions;
  final List<JsonMap> medications;
  final bool canEditRecords;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreateCondition;
  final Future<void> Function(JsonMap item) onEditCondition;
  final Future<void> Function(int id) onDeleteCondition;
  final Future<void> Function() onCreateMedication;
  final Future<void> Function(JsonMap item) onEditMedication;
  final Future<void> Function(int id) onDeleteMedication;

  @override
  Widget build(BuildContext context) {
    return _ScrollableTab(
      onRefresh: onRefresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SectionCard(
                child: canEditRecords
                    ? Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ActionPill(
                            key: const ValueKey('condition-create-open'),
                            label: '질환 추가',
                            icon: Icons.add_chart_rounded,
                            color: _primarySoft,
                            onTap: onCreateCondition,
                          ),
                          _ActionPill(
                            key: const ValueKey('medication-create-open'),
                            label: '복약 추가',
                            icon: Icons.medication_outlined,
                            color: _health,
                            onTap: onCreateMedication,
                          ),
                        ],
                      )
                    : const _EmptyLine(
                        '보기 권한으로 참여 중입니다. 건강 정보 수정은 owner/editor만 가능합니다.',
                      ),
              ),
              const SizedBox(height: 16),
              _RecordsSection(
                title: '질환 관리',
                children: conditions.isEmpty
                    ? const [_EmptyLine('등록된 질환 정보가 없습니다.')]
                    : conditions
                          .map(
                            (item) => _MenuRecordCard(
                              title: item['conditionName'] as String? ?? '질환',
                              subtitle: [
                                _conditionTypeLabel(
                                  item['conditionType'] as String?,
                                ),
                                item['notes'] as String? ?? '',
                              ].where((value) => value.isNotEmpty).join(' · '),
                              icon: Icons.favorite_outline_rounded,
                              color: _primarySoft,
                              collaboration: item['collaboration'] as JsonMap?,
                              canEdit: canEditRecords,
                              menuKey: ValueKey('condition-menu-${item['id']}'),
                              onEdit: () => onEditCondition(item),
                              onDelete: () {
                                final id = _asInt(item['id']);
                                if (id != null) return onDeleteCondition(id);
                                return Future<void>.value();
                              },
                            ),
                          )
                          .toList(),
              ),
              const SizedBox(height: 16),
              _RecordsSection(
                title: '복약 관리',
                children: medications.isEmpty
                    ? const [_EmptyLine('등록된 복약 정보가 없습니다.')]
                    : medications
                          .map(
                            (item) => _MenuRecordCard(
                              title: item['medicationName'] as String? ?? '복약',
                              subtitle: [
                                item['dosage'] as String? ?? '',
                                item['frequencyText'] as String? ?? '',
                              ].where((value) => value.isNotEmpty).join(' · '),
                              icon: Icons.medication_outlined,
                              color: _secondary,
                              collaboration: item['collaboration'] as JsonMap?,
                              canEdit: canEditRecords,
                              menuKey: ValueKey(
                                'medication-menu-${item['id']}',
                              ),
                              onEdit: () => onEditMedication(item),
                              onDelete: () {
                                final id = _asInt(item['id']);
                                if (id != null) return onDeleteMedication(id);
                                return Future<void>.value();
                              },
                            ),
                          )
                          .toList(),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.forecast,
    required this.latestReport,
    required this.visitReports,
    required this.onRefresh,
    required this.onRecalculate,
    required this.onGenerate,
  });

  final JsonMap? forecast;
  final JsonMap? latestReport;
  final List<JsonMap> visitReports;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRecalculate;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    final basic = forecast?['basic'] as JsonMap?;
    final explanation = basic?['explanation'] as JsonMap?;
    final insights = _jsonMapList(explanation?['insights']);
    final reportSummary = latestReport?['summary'] as JsonMap?;
    final reportShare = latestReport?['share'] as JsonMap?;
    return _ScrollableTab(
      onRefresh: onRefresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '비용 예측',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('forecast-recalculate-button'),
                          onPressed: onRecalculate,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('재계산'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatChip(
                          label: '월 예측',
                          value: _won(basic?['monthlyEstimate']),
                        ),
                        _StatChip(
                          label: '6개월',
                          value: _won(basic?['sixMonthEstimate']),
                        ),
                        _StatChip(
                          label: '1년 예측',
                          value: _won(basic?['yearlyEstimate']),
                        ),
                      ],
                    ),
                    if (basic != null) ...[
                      const SizedBox(height: 16),
                      _ForecastBreakdownList(
                        entries: [
                          _ForecastBreakdownEntry(
                            label: '고정비',
                            value: _won(
                              (basic['breakdown'] as JsonMap?)?['fixedCost'],
                            ),
                          ),
                          _ForecastBreakdownEntry(
                            label: '예방관리비',
                            value: _won(
                              (basic['breakdown']
                                  as JsonMap?)?['plannedCareCost'],
                            ),
                          ),
                          _ForecastBreakdownEntry(
                            label: '돌발진료 예비비',
                            value: _won(
                              (basic['breakdown']
                                  as JsonMap?)?['riskAdjustedCost'],
                            ),
                          ),
                        ],
                      ),
                      if (insights.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          '핵심 인사이트',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ForecastInsightList(insights: insights),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '방문 리포트',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        FilledButton.tonal(
                          key: const ValueKey('report-generate-button'),
                          onPressed: onGenerate,
                          child: const Text('새 리포트 생성'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (latestReport == null)
                      const Text(
                        '아직 생성된 리포트가 없습니다.',
                        style: TextStyle(color: _textMuted),
                      )
                    else ...[
                      Text(
                        latestReport?['title'] as String? ?? '최근 리포트',
                        key: const ValueKey('report-open-detail'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _VisitReportSummaryCard(
                        report: latestReport!,
                        summary: reportSummary,
                        share: reportShare,
                      ),
                    ],
                    if (visitReports.isNotEmpty) ...[
                      const Divider(height: 28),
                      const Text(
                        '이전 리포트',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...visitReports
                          .take(5)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                item['title'] as String? ?? '리포트',
                                style: const TextStyle(color: _textMuted),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              if (explanation != null) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  child: _ForecastExplanationCard(explanation: explanation),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _DogEditorScreen extends StatefulWidget {
  const _DogEditorScreen({required this.dog, required this.onSave});

  final JsonMap dog;
  final Future<void> Function(JsonMap payload, {Uint8List? avatarBytes}) onSave;

  @override
  State<_DogEditorScreen> createState() => _DogEditorScreenState();
}

class _DogEditorScreenState extends State<_DogEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _currentWeight;
  late final TextEditingController _breed;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.dog['name'] as String? ?? '');
    _currentWeight = TextEditingController(
      text: _asNum(widget.dog['currentWeightKg'])?.toString() ?? '',
    );
    _breed = TextEditingController(text: widget.dog['breed'] as String? ?? '');
    _notes = TextEditingController(text: widget.dog['notes'] as String? ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _currentWeight.dispose();
    _breed.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await widget.onSave({
        'name': _name.text.trim(),
        'breed': _breed.text.trim(),
        'birthDate': _dateInput(widget.dog['birthDate'] as String?) ?? '',
        'sex': widget.dog['sex'] as String? ?? 'female',
        'neutered': widget.dog['neutered'] ?? true,
        'currentWeightKg': num.tryParse(_currentWeight.text.trim()),
        'targetWeightKg':
            _asNum(widget.dog['targetWeightKg']) ??
            num.tryParse(_currentWeight.text.trim()),
        'activityLevel': widget.dog['activityLevel'] as String? ?? 'medium',
        'insuranceStatus': widget.dog['insuranceStatus'] as String? ?? 'none',
        'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: '프로필 수정',
      child: Column(
        children: [
          TextField(
            key: const ValueKey('dog-editor-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: '이름'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('dog-editor-current-weight'),
            controller: _currentWeight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '현재 체중 (kg)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _breed,
            decoration: const InputDecoration(labelText: '견종'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '메모'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('dog-editor-save'),
              onPressed: _save,
              style: _primaryButtonStyle(),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEditorScreen extends StatefulWidget {
  const _ScheduleEditorScreen({
    required this.existing,
    required this.members,
    required this.onCreate,
    required this.onUpdate,
  });

  final JsonMap? existing;
  final List<JsonMap> members;
  final Future<void> Function({
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    int? repeatCycleDays,
    int? assignedToUserId,
  })
  onCreate;
  final Future<void> Function({
    required int scheduleId,
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    required bool reminderEnabled,
    int? repeatCycleDays,
    int? assignedToUserId,
  })
  onUpdate;

  @override
  State<_ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<_ScheduleEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _dueDate;
  late final TextEditingController _repeatCycleDays;
  String _scheduleType = 'medication';
  String _priority = 'medium';
  int? _assignedToUserId;
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.existing?['title'] as String? ?? '',
    );
    _description = TextEditingController(
      text: widget.existing?['description'] as String? ?? '',
    );
    _dueDate = TextEditingController(
      text:
          _dateInput(widget.existing?['dueDate'] as String?) ??
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final existingType = widget.existing?['scheduleType'] as String?;
    _scheduleType =
        existingType != null && _scheduleTypeLabels.containsKey(existingType)
        ? existingType
        : 'medication';
    _repeatCycleDays = TextEditingController(
      text: _asInt(widget.existing?['repeatCycleDays'])?.toString() ?? '',
    );
    _priority = widget.existing?['priority'] as String? ?? 'medium';
    _assignedToUserId =
        _asInt(widget.existing?['assignedToUserId']) ??
        _asInt(
          (widget.existing?['carePlan'] as JsonMap?)?['responsibleUserId'],
        );
    _reminderEnabled = widget.existing?['reminderEnabled'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _dueDate.dispose();
    _repeatCycleDays.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dueDate.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _dueDate.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  Future<void> _save() async {
    try {
      final repeatCycleDays = int.tryParse(_repeatCycleDays.text.trim());
      if (widget.existing == null) {
        await widget.onCreate(
          scheduleType: _scheduleType,
          title: _title.text.trim(),
          dueDate: _dueDate.text.trim(),
          description: _description.text.trim(),
          priority: _priority,
          repeatCycleDays: repeatCycleDays,
          assignedToUserId: _assignedToUserId,
        );
      } else {
        final id = _asInt(widget.existing?['id']);
        if (id != null) {
          await widget.onUpdate(
            scheduleId: id,
            scheduleType: _scheduleType,
            title: _title.text.trim(),
            dueDate: _dueDate.text.trim(),
            description: _description.text.trim(),
            priority: _priority,
            reminderEnabled: _reminderEnabled,
            repeatCycleDays: repeatCycleDays,
            assignedToUserId: _assignedToUserId,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: widget.existing == null ? '일정 추가' : '일정 수정',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('schedule-editor-type'),
            initialValue: _scheduleTypeLabels.containsKey(_scheduleType)
                ? _scheduleType
                : 'custom',
            decoration: const InputDecoration(labelText: '일정 종류'),
            items: _scheduleTypeLabels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _scheduleType = value ?? _scheduleType),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('schedule-editor-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: '제목'),
          ),
          const SizedBox(height: 14),
          _DateTile(
            key: const ValueKey('schedule-editor-due-date'),
            label: '예정일',
            value: _dueDate.text,
            onTap: _pickDate,
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('schedule-editor-description'),
            controller: _description,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '설명'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('schedule-editor-repeat'),
            controller: _repeatCycleDays,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '반복 주기(일)',
              hintText: '반복하지 않으면 비워두세요',
            ),
          ),
          const SizedBox(height: 14),
          if (widget.members.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              key: const ValueKey('schedule-editor-assignee'),
              initialValue:
                  widget.members.any(
                    (member) => _asInt(member['userId']) == _assignedToUserId,
                  )
                  ? _assignedToUserId
                  : null,
              decoration: const InputDecoration(labelText: '담당 보호자'),
              hint: const Text('작성자에게 자동 배정'),
              items: widget.members
                  .map(
                    (member) => DropdownMenuItem<int>(
                      value: _asInt(member['userId']),
                      child: Text(_memberLabel(member)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _assignedToUserId = value),
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: '우선순위'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('낮음')),
              DropdownMenuItem(value: 'medium', child: Text('보통')),
              DropdownMenuItem(value: 'high', child: Text('높음')),
            ],
            onChanged: (value) =>
                setState(() => _priority = value ?? _priority),
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _reminderEnabled,
            onChanged: (value) => setState(() => _reminderEnabled = value),
            title: const Text('리마인더 사용'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('schedule-editor-save'),
              onPressed: _save,
              style: _primaryButtonStyle(),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthLogEditorScreen extends StatefulWidget {
  const _HealthLogEditorScreen({
    required this.existing,
    required this.onCreate,
    required this.onUpdate,
  });

  final JsonMap? existing;
  final Future<void> Function({
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
    bool isSensitive,
  })
  onCreate;
  final Future<void> Function({
    required int logId,
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
    bool isSensitive,
  })
  onUpdate;

  @override
  State<_HealthLogEditorScreen> createState() => _HealthLogEditorScreenState();
}

class _HealthLogEditorScreenState extends State<_HealthLogEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _value;
  late final TextEditingController _memo;
  bool _isSensitive = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.existing?['title'] as String? ?? '',
    );
    _value = TextEditingController(
      text: _asNum(widget.existing?['valueNumeric'])?.toString() ?? '',
    );
    _memo = TextEditingController(
      text: widget.existing?['memo'] as String? ?? '',
    );
    _isSensitive =
        widget.existing?['isSensitive'] == true ||
        (widget.existing?['collaboration'] as JsonMap?)?['isSensitive'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (widget.existing == null) {
        await widget.onCreate(
          logType: 'symptom',
          title: _title.text.trim(),
          memo: _memo.text.trim(),
          valueNumeric: num.tryParse(_value.text.trim()),
          valueUnit: '회',
          isSensitive: _isSensitive,
        );
        if (!mounted) return;
        await _showRecordSavedDialog(context);
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final id = _asInt(widget.existing?['id']);
      if (id != null) {
        await widget.onUpdate(
          logId: id,
          logType: widget.existing?['logType'] as String? ?? 'symptom',
          title: _title.text.trim(),
          memo: _memo.text.trim(),
          valueNumeric: num.tryParse(_value.text.trim()),
          valueUnit: widget.existing?['valueUnit'] as String? ?? '회',
          isSensitive: _isSensitive,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: widget.existing == null ? '건강 기록 추가' : '건강 기록 수정',
      child: Column(
        children: [
          TextField(
            key: const ValueKey('health-editor-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: '제목'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('health-editor-value'),
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '수치'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('health-editor-memo'),
            controller: _memo,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '메모'),
          ),
          const SizedBox(height: 14),
          _SensitiveSwitch(
            value: _isSensitive,
            onChanged: (value) => setState(() => _isSensitive = value),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('health-editor-save'),
              onPressed: _save,
              style: _primaryButtonStyle(),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseEditorScreen extends StatefulWidget {
  const _ExpenseEditorScreen({
    required this.existing,
    required this.onCreate,
    required this.onUpdate,
  });

  final JsonMap? existing;
  final Future<void> Function({
    required String category,
    required num amount,
    required String expenseDate,
    required String vendorName,
    required String memo,
    bool isSensitive,
  })
  onCreate;
  final Future<void> Function({
    required int expenseId,
    required String category,
    required num amount,
    required String expenseDate,
    required String vendorName,
    required String memo,
    bool isSensitive,
  })
  onUpdate;

  @override
  State<_ExpenseEditorScreen> createState() => _ExpenseEditorScreenState();
}

class _ExpenseEditorScreenState extends State<_ExpenseEditorScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _vendor;
  late final TextEditingController _memo;
  late String _category;
  bool _isSensitive = false;

  @override
  void initState() {
    super.initState();
    final existingCategory = widget.existing?['expenseCategory'] as String?;
    _category =
        existingCategory != null &&
            _expenseCategoryLabels.containsKey(existingCategory)
        ? existingCategory
        : _expenseCategoryLabels.keys.first;
    _amount = TextEditingController(
      text: _asNum(widget.existing?['amount'])?.round().toString() ?? '',
    );
    _vendor = TextEditingController(
      text: widget.existing?['vendorName'] as String? ?? '',
    );
    _memo = TextEditingController(
      text: widget.existing?['memo'] as String? ?? '',
    );
    _isSensitive =
        widget.existing?['isSensitive'] == true ||
        (widget.existing?['collaboration'] as JsonMap?)?['isSensitive'] == true;
  }

  @override
  void dispose() {
    _amount.dispose();
    _vendor.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = num.tryParse(_amount.text.trim());
    if (amount == null) return;

    try {
      if (widget.existing == null) {
        await widget.onCreate(
          category: _category,
          amount: amount,
          expenseDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          vendorName: _vendor.text.trim(),
          memo: _memo.text.trim(),
          isSensitive: _isSensitive,
        );
        if (!mounted) return;
        await _showRecordSavedDialog(context);
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final id = _asInt(widget.existing?['id']);
      if (id != null) {
        await widget.onUpdate(
          expenseId: id,
          category: _category,
          amount: amount,
          expenseDate:
              _dateInput(widget.existing?['expenseDate'] as String?) ??
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
          vendorName: _vendor.text.trim(),
          memo: _memo.text.trim(),
          isSensitive: _isSensitive,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: widget.existing == null ? '지출 기록 추가' : '지출 기록 수정',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('expense-editor-category'),
            initialValue: _expenseCategoryLabels.containsKey(_category)
                ? _category
                : 'other',
            decoration: const InputDecoration(labelText: '분류'),
            items: _expenseCategoryLabels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _category = value);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('expense-editor-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '금액'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('expense-editor-vendor'),
            controller: _vendor,
            decoration: const InputDecoration(labelText: '사용처'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _memo,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '메모'),
          ),
          const SizedBox(height: 14),
          _SensitiveSwitch(
            value: _isSensitive,
            onChanged: (value) => setState(() => _isSensitive = value),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('expense-editor-save'),
              onPressed: _save,
              style: _primaryButtonStyle(),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalVisitEditorScreen extends StatefulWidget {
  const _MedicalVisitEditorScreen({
    required this.existing,
    required this.onCreate,
    required this.onUpdate,
  });

  final JsonMap? existing;
  final Future<void> Function({
    required String hospitalName,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required num? expenseAmount,
    bool isSensitive,
  })
  onCreate;
  final Future<void> Function({
    required int visitId,
    required String hospitalName,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required String notes,
    bool isSensitive,
  })
  onUpdate;

  @override
  State<_MedicalVisitEditorScreen> createState() =>
      _MedicalVisitEditorScreenState();
}

class _MedicalVisitEditorScreenState extends State<_MedicalVisitEditorScreen> {
  late final TextEditingController _hospital;
  late final TextEditingController _symptoms;
  late final TextEditingController _diagnosis;
  late final TextEditingController _treatment;
  late final TextEditingController _expense;
  bool _isSensitive = false;

  @override
  void initState() {
    super.initState();
    _hospital = TextEditingController(
      text: widget.existing?['hospitalName'] as String? ?? '',
    );
    _symptoms = TextEditingController(
      text: widget.existing?['symptoms'] as String? ?? '',
    );
    _diagnosis = TextEditingController(
      text: widget.existing?['diagnosis'] as String? ?? '',
    );
    _treatment = TextEditingController(
      text: widget.existing?['treatment'] as String? ?? '',
    );
    _expense = TextEditingController(
      text: _asNum(widget.existing?['expenseAmount'])?.round().toString() ?? '',
    );
    _isSensitive =
        widget.existing?['isSensitive'] == true ||
        (widget.existing?['collaboration'] as JsonMap?)?['isSensitive'] == true;
  }

  @override
  void dispose() {
    _hospital.dispose();
    _symptoms.dispose();
    _diagnosis.dispose();
    _treatment.dispose();
    _expense.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (widget.existing == null) {
        await widget.onCreate(
          hospitalName: _hospital.text.trim(),
          symptoms: _symptoms.text.trim(),
          diagnosis: _diagnosis.text.trim(),
          treatment: _treatment.text.trim(),
          expenseAmount: num.tryParse(_expense.text.trim()),
          isSensitive: _isSensitive,
        );
        if (!mounted) return;
        await _showRecordSavedDialog(context);
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final id = _asInt(widget.existing?['id']);
      if (id != null) {
        await widget.onUpdate(
          visitId: id,
          hospitalName: _hospital.text.trim(),
          visitReason:
              widget.existing?['visitReason'] as String? ??
              _symptoms.text.trim(),
          symptoms: _symptoms.text.trim(),
          diagnosis: _diagnosis.text.trim(),
          treatment: _treatment.text.trim(),
          prescribedItems: widget.existing?['prescribedItems'] as String? ?? '',
          followUpDate:
              _dateInput(widget.existing?['followUpDate'] as String?) ?? '',
          notes: widget.existing?['notes'] as String? ?? '',
          isSensitive: _isSensitive,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: widget.existing == null ? '병원 기록 추가' : '병원 기록 수정',
      child: Column(
        children: [
          TextField(
            key: const ValueKey('medical-visit-editor-hospital'),
            controller: _hospital,
            decoration: const InputDecoration(labelText: '병원명'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('medical-visit-editor-symptoms'),
            controller: _symptoms,
            decoration: const InputDecoration(labelText: '증상'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('medical-visit-editor-diagnosis'),
            controller: _diagnosis,
            decoration: const InputDecoration(labelText: '진단'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('medical-visit-editor-treatment'),
            controller: _treatment,
            decoration: const InputDecoration(labelText: '치료'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('medical-visit-editor-expense'),
            controller: _expense,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '관련 비용'),
          ),
          const SizedBox(height: 14),
          _SensitiveSwitch(
            value: _isSensitive,
            onChanged: (value) => setState(() => _isSensitive = value),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('medical-visit-editor-save'),
              onPressed: _save,
              style: _primaryButtonStyle(),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionEditorSheet extends StatefulWidget {
  const _ConditionEditorSheet({
    required this.existing,
    required this.onCreate,
    required this.onUpdate,
  });

  final JsonMap? existing;
  final Future<void> Function({
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
  })
  onCreate;
  final Future<void> Function({
    required int conditionId,
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
  })
  onUpdate;

  @override
  State<_ConditionEditorSheet> createState() => _ConditionEditorSheetState();
}

class _ConditionEditorSheetState extends State<_ConditionEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  String _type = 'chronic';
  String _severity = 'medium';
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.existing?['conditionName'] as String? ?? '',
    );
    _notes = TextEditingController(
      text: widget.existing?['notes'] as String? ?? '',
    );
    _type = widget.existing?['conditionType'] as String? ?? 'chronic';
    _severity = widget.existing?['severity'] as String? ?? 'medium';
    _status = widget.existing?['status'] as String? ?? 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final diagnosedOn =
        _dateInput(widget.existing?['diagnosedOn'] as String?) ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      if (widget.existing == null) {
        await widget.onCreate(
          conditionType: _type,
          conditionName: _name.text.trim(),
          severity: _severity,
          diagnosedOn: diagnosedOn,
          status: _status,
          notes: _notes.text.trim(),
        );
      } else {
        final id = _asInt(widget.existing?['id']);
        if (id != null) {
          await widget.onUpdate(
            conditionId: id,
            conditionType: _type,
            conditionName: _name.text.trim(),
            severity: _severity,
            diagnosedOn: diagnosedOn,
            status: _status,
            notes: _notes.text.trim(),
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheet(
      title: widget.existing == null ? '질환 추가' : '질환 수정',
      child: Column(
        children: [
          TextField(
            key: const ValueKey('condition-editor-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: '질환명'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '분류'),
            items: const [
              DropdownMenuItem(value: 'allergy', child: Text('알레르기')),
              DropdownMenuItem(value: 'chronic', child: Text('만성 질환')),
              DropdownMenuItem(value: 'injury', child: Text('부상')),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _severity,
            decoration: const InputDecoration(labelText: '심각도'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('주의')),
              DropdownMenuItem(value: 'medium', child: Text('관리')),
              DropdownMenuItem(value: 'high', child: Text('심각')),
            ],
            onChanged: (value) =>
                setState(() => _severity = value ?? _severity),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: '상태'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('활성')),
              DropdownMenuItem(value: 'monitoring', child: Text('관찰')),
              DropdownMenuItem(value: 'resolved', child: Text('완료')),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('condition-editor-notes'),
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '메모'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('condition-editor-save'),
              onPressed: _save,
              style: _primaryButtonStyle(),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationEditorSheet extends StatefulWidget {
  const _MedicationEditorSheet({
    required this.existing,
    required this.onCreate,
    required this.onUpdate,
  });

  final JsonMap? existing;
  final Future<void> Function({
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
  })
  onCreate;
  final Future<void> Function({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
  })
  onUpdate;

  @override
  State<_MedicationEditorSheet> createState() => _MedicationEditorSheetState();
}

class _MedicationEditorSheetState extends State<_MedicationEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _frequency;
  late final TextEditingController _prescribedBy;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.existing?['medicationName'] as String? ?? '',
    );
    _dosage = TextEditingController(
      text: widget.existing?['dosage'] as String? ?? '',
    );
    _frequency = TextEditingController(
      text: widget.existing?['frequencyText'] as String? ?? '',
    );
    _prescribedBy = TextEditingController(
      text: widget.existing?['prescribedBy'] as String? ?? '',
    );
    _active = widget.existing?['isActive'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _prescribedBy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final startedOn =
        _dateInput(widget.existing?['startedOn'] as String?) ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      if (widget.existing == null) {
        await widget.onCreate(
          medicationName: _name.text.trim(),
          dosage: _dosage.text.trim(),
          frequencyText: _frequency.text.trim(),
          startedOn: startedOn,
          endedOn: '',
          prescribedBy: _prescribedBy.text.trim(),
          isActive: _active,
          notes: '',
        );
      } else {
        final id = _asInt(widget.existing?['id']);
        if (id != null) {
          await widget.onUpdate(
            medicationId: id,
            medicationName: _name.text.trim(),
            dosage: _dosage.text.trim(),
            frequencyText: _frequency.text.trim(),
            startedOn: startedOn,
            endedOn: _dateInput(widget.existing?['endedOn'] as String?) ?? '',
            prescribedBy: _prescribedBy.text.trim(),
            isActive: _active,
            notes: widget.existing?['notes'] as String? ?? '',
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheet(
      title: widget.existing == null ? '복약 추가' : '복약 수정',
      child: Column(
        children: [
          TextField(
            key: const ValueKey('medication-editor-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: '약 이름'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('medication-editor-dosage'),
            controller: _dosage,
            decoration: const InputDecoration(labelText: '복용량'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('medication-editor-frequency'),
            controller: _frequency,
            decoration: const InputDecoration(labelText: '복용 주기'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('medication-editor-prescribed-by'),
            controller: _prescribedBy,
            decoration: const InputDecoration(labelText: '처방 병원'),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _active,
            onChanged: (value) => setState(() => _active = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('복용 중'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('medication-editor-save'),
              onPressed: _save,
              style: _primaryButtonStyle(),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableTab extends StatelessWidget {
  const _ScrollableTab({required this.onRefresh, required this.slivers});

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.dog, required this.onOpenProfile});

  final JsonMap? dog;
  final Future<void> Function() onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final breed = dog?['breed'] as String? ?? '';
    final weight = _asNum(dog?['currentWeightKg']);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE9DD), Color(0xFFFFF3EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: _primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog?['name'] as String? ?? '반려견',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (breed.isNotEmpty) breed,
                        if (weight != null) '${weight.toStringAsFixed(1)}kg',
                      ].join(' · '),
                      style: const TextStyle(color: _textMuted),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                key: const ValueKey('dog-profile-edit-open'),
                onPressed: onOpenProfile,
                child: const Text('프로필'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '오늘 필요한 기록과 할 일을 빠르게 정리해두었어요.',
            style: TextStyle(height: 1.5, color: _textMuted),
          ),
        ],
      ),
    );
  }
}

class _FamilyCollaborationPanel extends StatelessWidget {
  const _FamilyCollaborationPanel({
    required this.access,
    required this.members,
    required this.schedules,
    required this.activity,
    required this.hiddenSensitiveCounts,
  });

  final JsonMap access;
  final List<JsonMap> members;
  final List<JsonMap> schedules;
  final List<JsonMap> activity;
  final JsonMap? hiddenSensitiveCounts;

  @override
  Widget build(BuildContext context) {
    final role = access['role'] as String? ?? 'viewer';
    final userId = _asInt(access['userId']);
    final assignedToMe = userId == null
        ? 0
        : schedules.where((item) {
            final carePlan = item['carePlan'] as JsonMap?;
            return _asInt(carePlan?['responsibleUserId']) == userId;
          }).length;
    final hiddenCount = _asInt(hiddenSensitiveCounts?['total']) ?? 0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가족 협업',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(label: '내 권한', value: _roleLabel(role)),
              _StatChip(label: '보호자', value: '${members.length}명'),
              _StatChip(label: '내 담당', value: '$assignedToMe개'),
              _StatChip(label: '숨김 기록', value: '$hiddenCount개'),
            ],
          ),
          if (activity.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...activity
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${item['actorLabel'] ?? '가족'} · ${_activityActionLabel(item['action'] as String?)} · ${item['summary'] ?? ''}',
                      style: const TextStyle(color: _textMuted, height: 1.4),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    required this.canEdit,
    required this.onEdit,
    required this.onSkip,
    required this.onComplete,
  });

  final JsonMap item;
  final bool canEdit;
  final Future<void> Function() onEdit;
  final Future<void> Function() onSkip;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final id = _asInt(item['id']);
    final carePlan = item['carePlan'] as JsonMap?;
    final failureStatus = carePlan?['failureStatus'] as String?;
    final typeLabel =
        carePlan?['typeLabel'] as String? ??
        _scheduleTypeLabels[item['scheduleType']] ??
        '돌봄';
    final responsibleLabel =
        carePlan?['responsibleLabel'] as String? ?? '담당자 미지정';
    final failureLabel = _careFailureLabel(failureStatus);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['title'] as String? ?? '일정',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            [
              typeLabel,
              _formatDate(item['dueDate'] as String?),
              responsibleLabel,
              item['description'] as String? ?? '',
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(color: _textMuted, height: 1.5),
          ),
          if (failureLabel != null) ...[
            const SizedBox(height: 8),
            _InlineStatusBadge(
              label: failureLabel,
              color: _careFailureColor(failureStatus),
            ),
          ],
          const SizedBox(height: 12),
          if (canEdit)
            Row(
              children: [
                OutlinedButton(
                  key: ValueKey('schedule-edit-$id'),
                  onPressed: onEdit,
                  child: const Text('수정'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: ValueKey('schedule-skip-$id'),
                  onPressed: onSkip,
                  child: const Text('건너뛰기'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('schedule-complete-$id'),
                    onPressed: onComplete,
                    style: FilledButton.styleFrom(backgroundColor: _secondary),
                    child: const Text('완료'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CarePlanOverview extends StatelessWidget {
  const _CarePlanOverview({required this.schedules});

  final List<JsonMap> schedules;

  @override
  Widget build(BuildContext context) {
    final overdueCount = schedules.where((item) {
      final carePlan = item['carePlan'] as JsonMap?;
      final status = carePlan?['failureStatus'] as String?;
      return status == 'overdue' || status == 'missed_repeated';
    }).length;
    final pushCandidateCount = schedules
        .where(
          (item) =>
              (item['carePlan'] as JsonMap?)?['delivery'] == 'push_candidate',
        )
        .length;
    final missingAssigneeCount = schedules.where((item) {
      final carePlan = item['carePlan'] as JsonMap?;
      return carePlan?['responsibilitySource'] == 'none';
    }).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatChip(label: '대기 일정', value: '${schedules.length}개'),
        _StatChip(label: '지연', value: '$overdueCount개'),
        _StatChip(label: '중요 알림', value: '$pushCandidateCount개'),
        _StatChip(label: '담당 미정', value: '$missingAssigneeCount개'),
      ],
    );
  }
}

class _InlineStatusBadge extends StatelessWidget {
  const _InlineStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SensitiveSwitch extends StatelessWidget {
  const _SensitiveSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: const ValueKey('record-sensitive-switch'),
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: const Text('민감 기록'),
      subtitle: const Text('viewer 권한 가족에게는 숨깁니다.'),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _MenuRecordCard extends StatelessWidget {
  const _MenuRecordCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.canEdit,
    required this.menuKey,
    required this.onEdit,
    required this.onDelete,
    this.collaboration,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool canEdit;
  final Key menuKey;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final JsonMap? collaboration;

  @override
  Widget build(BuildContext context) {
    final isSensitive = collaboration?['isSensitive'] == true;
    final authorLabel = collaboration?['authorLabel'] as String?;
    final historyLabel = collaboration?['historyLabel'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _textMuted, height: 1.4),
                  ),
                ],
                if (collaboration != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (authorLabel != null)
                        _InlineStatusBadge(
                          label: authorLabel,
                          color: _secondary,
                        ),
                      if (historyLabel != null)
                        _InlineStatusBadge(
                          label: historyLabel,
                          color: _textMuted,
                        ),
                      if (isSensitive)
                        const _InlineStatusBadge(label: '민감', color: _danger),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              key: menuKey,
              onSelected: (value) async {
                if (value == 'edit') {
                  await onEdit();
                  return;
                }
                await onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.more_vert_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _surfaceBorder),
      ),
      child: child,
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: _textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ForecastBreakdownEntry {
  const _ForecastBreakdownEntry({required this.label, required this.value});

  final String label;
  final String value;
}

class _ForecastBreakdownList extends StatelessWidget {
  const _ForecastBreakdownList({required this.entries});

  final List<_ForecastBreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    entries[index].label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  entries[index].value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (index != entries.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ForecastInsightList extends StatelessWidget {
  const _ForecastInsightList({required this.insights});

  final List<JsonMap> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < insights.length; index++) ...[
          _ForecastInsightTile(insight: insights[index]),
          if (index != insights.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ForecastInsightTile extends StatelessWidget {
  const _ForecastInsightTile({required this.insight});

  final JsonMap insight;

  @override
  Widget build(BuildContext context) {
    final kind = insight['kind'] as String?;
    final color = _forecastInsightColor(kind);
    final monthlyImpact = _asNum(insight['monthlyImpact']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(_forecastInsightIcon(kind), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        insight['title'] as String? ?? '예측 인사이트',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (monthlyImpact != null && monthlyImpact > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        _won(monthlyImpact),
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  insight['body'] as String? ?? '',
                  style: const TextStyle(
                    color: _textMuted,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitReportSummaryCard extends StatelessWidget {
  const _VisitReportSummaryCard({
    required this.report,
    required this.summary,
    required this.share,
  });

  final JsonMap report;
  final JsonMap? summary;
  final JsonMap? share;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null) {
      return Text(
        report['renderedText'] as String? ?? '',
        style: const TextStyle(height: 1.6),
      );
    }

    final recent30 = summary['recent30Days'] as JsonMap?;
    final weightTrend = recent30?['weightTrend'] as JsonMap?;
    final changes = _jsonMapList(recent30?['changes']);
    final questions = _jsonMapList(summary['questionList']);
    final missingRecords = _jsonMapList(summary['missingRecords']);
    final medications = _jsonMapList(summary['activeMedications']);
    final conditions = _jsonMapList(summary['conditions']);
    final visits = _jsonMapList(summary['recentVisits']);
    final share = this.share ?? (summary['share'] as JsonMap?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(
              label: '30일 증상',
              value: '${_asInt(recent30?['symptomCount']) ?? 0}건',
            ),
            _StatChip(
              label: '30일 방문',
              value: '${_asInt(recent30?['visitCount']) ?? 0}회',
            ),
            _StatChip(label: '체중 변화', value: _weightTrendLabel(weightTrend)),
            _StatChip(
              label: '공유 준비',
              value: share?['pdfStatus'] == 'ready' ? 'PDF 가능' : '텍스트',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ReportListSection(
          title: '최근 30일 변화',
          items: changes,
          titleKey: 'title',
          bodyKey: 'detail',
          emptyText: '최근 30일 변화 기록이 없습니다.',
        ),
        const SizedBox(height: 16),
        _ReportListSection(
          title: '수의사에게 물어볼 질문',
          items: questions,
          titleKey: 'question',
          bodyKey: 'reason',
          trailingKey: 'priority',
          emptyText: '제안 질문이 없습니다.',
        ),
        const SizedBox(height: 16),
        _ReportListSection(
          title: '주의해야 할 누락 기록',
          items: missingRecords,
          titleKey: 'title',
          bodyKey: 'reason',
          trailingKey: 'severity',
          emptyText: '큰 누락 기록이 없습니다.',
        ),
        if (medications.isNotEmpty || conditions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ReportCompactSection(
            title: '복약·질환',
            lines: [
              ...medications
                  .take(4)
                  .map((item) => item['label'] as String? ?? '복약 기록'),
              ...conditions
                  .take(4)
                  .map((item) => item['name'] as String? ?? '질환 기록'),
            ],
          ),
        ],
        if (visits.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ReportCompactSection(
            title: '최근 방문',
            lines: visits
                .take(4)
                .map((item) => item['label'] as String? ?? '방문 기록')
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          report['notice'] as String? ??
              summary['notice'] as String? ??
              '진료 판단은 수의사와 상담해 주세요.',
          style: const TextStyle(color: _textMuted, height: 1.45, fontSize: 12),
        ),
      ],
    );
  }
}

class _ReportListSection extends StatelessWidget {
  const _ReportListSection({
    required this.title,
    required this.items,
    required this.titleKey,
    required this.bodyKey,
    required this.emptyText,
    this.trailingKey,
  });

  final String title;
  final List<JsonMap> items;
  final String titleKey;
  final String bodyKey;
  final String emptyText;
  final String? trailingKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(emptyText, style: const TextStyle(color: _textMuted))
        else
          for (var index = 0; index < items.length; index++) ...[
            _ReportListTile(
              title: items[index][titleKey] as String? ?? title,
              body: items[index][bodyKey] as String? ?? '',
              trailing: trailingKey == null
                  ? null
                  : items[index][trailingKey] as String?,
            ),
            if (index != items.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ReportListTile extends StatelessWidget {
  const _ReportListTile({
    required this.title,
    required this.body,
    this.trailing,
  });

  final String title;
  final String body;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final color = _reportSeverityColor(trailing);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _reportSeverityLabel(trailing),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: _textMuted,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCompactSection extends StatelessWidget {
  const _ReportCompactSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• $line', style: const TextStyle(height: 1.45)),
          ),
        ),
      ],
    );
  }
}

class _ForecastExplanationCard extends StatelessWidget {
  const _ForecastExplanationCard({required this.explanation});

  final JsonMap explanation;

  @override
  Widget build(BuildContext context) {
    final summary = _stringList(explanation['summary']);
    final breedProfile = _jsonMapOrNull(explanation['breedProfile']);
    final notes = breedProfile == null
        ? const <String>[]
        : _stringList(breedProfile['notes']);
    final drivers = _jsonMapList(explanation['drivers']);
    final sources = _jsonMapList(explanation['sources']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '왜 이렇게 계산됐나요',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          explanation['title'] as String? ?? '비용 추정 설명',
          style: const TextStyle(fontSize: 15, color: _textMuted, height: 1.5),
        ),
        if (breedProfile != null) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                label:
                    '${breedProfile['displayName'] as String? ?? '견종'} · ${breedProfile['sizeLabel'] as String? ?? ''}',
              ),
              _InfoPill(
                label:
                    '기대수명 ${_lifespanLabel(breedProfile['expectedLifespanYears'])}',
              ),
              if (_asNum(breedProfile['obesityRatePct']) != null)
                _InfoPill(
                  label:
                      '국내 비만율 ${_asNum(breedProfile['obesityRatePct'])!.toStringAsFixed(1)}%',
                ),
              _InfoPill(
                label: _forecastMatchTypeLabel(
                  breedProfile['matchType'] as String?,
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...notes.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $item',
                  style: const TextStyle(color: _textMuted, height: 1.5),
                ),
              ),
            ),
          ],
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '추정 근거',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...summary.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• $item',
                style: const TextStyle(height: 1.55, color: _textMuted),
              ),
            ),
          ),
        ],
        if (drivers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '주요 비용 요인',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...drivers.map((driver) => _ForecastDriverTile(driver: driver)),
        ],
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '기준 자료',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sources
                .map(
                  (source) =>
                      _InfoPill(label: source['label'] as String? ?? '자료'),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ForecastDriverTile extends StatelessWidget {
  const _ForecastDriverTile({required this.driver});

  final JsonMap driver;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  driver['label'] as String? ?? '비용 요인',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _won(driver['monthlyImpact']),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            driver['reason'] as String? ?? '',
            style: const TextStyle(color: _textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: _textMuted)),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(child: Text(value.isEmpty ? '날짜 선택' : value)),
            const Icon(Icons.calendar_month_outlined, color: _textMuted),
          ],
        ),
      ),
    );
  }
}

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              sliver: SliverToBoxAdapter(child: _SectionCard(child: child)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSheet extends StatelessWidget {
  const _EditorSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> _showRecordSavedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('기록이 저장되었어요'),
        content: const Text('대시보드로 돌아가서 새 기록을 확인할까요?'),
        actions: [
          TextButton(
            key: const ValueKey('record-success-primary'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('계속 입력'),
          ),
          FilledButton(
            key: const ValueKey('record-success-secondary'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('대시보드로'),
          ),
        ],
      );
    },
  );
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _primary,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(54),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}

String _tabTitle(_DashboardTab tab) {
  return switch (tab) {
    _DashboardTab.today => '오늘 해야 할 일',
    _DashboardTab.records => '기록 아카이브',
    _DashboardTab.health => '건강 관리',
    _DashboardTab.reports => '리포트와 예측',
  };
}

String _conditionTypeLabel(String? value) {
  return switch (value) {
    'allergy' => '알레르기',
    'injury' => '부상',
    _ => '만성 질환',
  };
}

String _roleLabel(String? value) {
  return switch (value) {
    'owner' => 'Owner',
    'editor' => 'Editor',
    'viewer' => 'Viewer',
    _ => '-',
  };
}

String _activityActionLabel(String? value) {
  return switch (value) {
    'create' => '작성',
    'update' => '수정',
    'delete' => '삭제',
    'complete' => '완료',
    'skip' => '건너뜀',
    'upsert' => '초대',
    'remove' => '제거',
    _ => value ?? '',
  };
}

String _memberLabel(JsonMap member) {
  final user = member['user'] as JsonMap?;
  final name = user?['name'] as String?;
  final email = user?['email'] as String?;
  final role = member['role'] as String?;
  final parts = <String>[];
  if (name != null && name.isNotEmpty) {
    parts.add(name);
  } else if (email != null && email.isNotEmpty) {
    parts.add(email);
  }
  if (role != null) {
    parts.add(_roleLabel(role));
  }
  return parts.join(' · ');
}

String _formatDate(String? value) {
  final date = value == null ? null : DateTime.tryParse(value);
  if (date == null) return '';
  return DateFormat('yyyy.MM.dd').format(date);
}

String? _dateInput(String? value) {
  final date = value == null ? null : DateTime.tryParse(value);
  if (date == null) return null;
  return DateFormat('yyyy-MM-dd').format(date);
}

String _won(Object? value) {
  final amount = _asNum(value) ?? 0;
  return '${NumberFormat.decimalPattern('ko_KR').format(amount.round())}원';
}

String _weightTrendLabel(JsonMap? trend) {
  if (trend == null) return '기록 부족';
  final deltaKg = _asNum(trend['deltaKg']) ?? 0;
  if (deltaKg == 0) return '변화 없음';
  final direction = deltaKg > 0 ? '증가' : '감소';
  return '$direction ${deltaKg.abs().toStringAsFixed(1)}kg';
}

Color _reportSeverityColor(String? value) {
  return switch (value) {
    'high' => _danger,
    'medium' => _expense,
    'low' => _health,
    _ => _primary,
  };
}

String _reportSeverityLabel(String? value) {
  return switch (value) {
    'high' => '중요',
    'medium' => '확인',
    'low' => '참고',
    _ => value ?? '',
  };
}

String? _careFailureLabel(String? value) {
  return switch (value) {
    'missed_repeated' => '반복 지연: 담당자 확인 필요',
    'overdue' => '예정일 지남',
    'due_today' => '오늘까지',
    'due_soon' => '이번 주 예정',
    _ => null,
  };
}

Color _careFailureColor(String? value) {
  return switch (value) {
    'missed_repeated' => _danger,
    'overdue' => _expense,
    'due_today' => _primary,
    _ => _health,
  };
}

int _compareScheduleDate(JsonMap a, JsonMap b) {
  final left = DateTime.tryParse(a['dueDate'] as String? ?? '');
  final right = DateTime.tryParse(b['dueDate'] as String? ?? '');
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

int _compareByEventDateDesc(JsonMap a, JsonMap b) {
  final left = _bestDate(a);
  final right = _bestDate(b);
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return right.compareTo(left);
}

int _compareByUpdatedAtDesc(JsonMap a, JsonMap b) {
  final left = DateTime.tryParse(
    a['updatedAt'] as String? ?? a['createdAt'] as String? ?? '',
  );
  final right = DateTime.tryParse(
    b['updatedAt'] as String? ?? b['createdAt'] as String? ?? '',
  );
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return right.compareTo(left);
}

DateTime? _bestDate(JsonMap item) {
  const candidates = [
    'recordedAt',
    'expenseDate',
    'visitDate',
    'eventAt',
    'updatedAt',
    'createdAt',
  ];
  for (final key in candidates) {
    final value = item[key] as String?;
    final date = value == null ? null : DateTime.tryParse(value);
    if (date != null) return date;
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

JsonMap? _jsonMapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }
  return null;
}

List<JsonMap> _jsonMapList(Object? value) {
  if (value is! List) return const [];
  return value.map(_jsonMapOrNull).whereType<JsonMap>().toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

num? _asNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

String _lifespanLabel(Object? value) {
  if (value is List && value.length >= 2) {
    final min = _asNum(value[0]);
    final max = _asNum(value[1]);
    if (min != null && max != null) {
      return '${min.toInt()}~${max.toInt()}세';
    }
  }
  return '-';
}

String _forecastMatchTypeLabel(String? value) {
  return switch (value) {
    'exact' => '견종 직접 매칭',
    'mixed' => '믹스/혼합견 규칙',
    'size_fallback' => '체중 기반 대체',
    _ => '기본 프로필',
  };
}

Color _forecastInsightColor(String? value) {
  return switch (value) {
    'attention' => _primary,
    'confidence' => _secondary,
    'action' => _hospital,
    _ => _textMuted,
  };
}

IconData _forecastInsightIcon(String? value) {
  return switch (value) {
    'attention' => Icons.priority_high_rounded,
    'confidence' => Icons.insights_rounded,
    'action' => Icons.task_alt_rounded,
    _ => Icons.info_outline_rounded,
  };
}
