import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'api/api_client.dart';
import 'services/local_notification_service.dart';
import 'services/session_store.dart';

const _appBackground = Color(0xFFF5F2EA);
const _surface = Color(0xFFFFFCF7);
const _ink = Color(0xFF1E2A28);
const _mutedInk = Color(0xFF66706C);
const _teal = Color(0xFF276A66);
const _deepTeal = Color(0xFF173D3B);
const _coral = Color(0xFFE75F45);
const _gold = Color(0xFFE7C86D);
const _violet = Color(0xFF5A4CA8);
const _border = Color(0xFFE4DDD2);

typedef HealthLogUpdater =
    Future<void> Function({
      required int logId,
      required String logType,
      required String title,
      required String memo,
      num? valueNumeric,
      String? valueUnit,
    });

typedef ExpenseUpdater =
    Future<void> Function({
      required int expenseId,
      required String category,
      required num amount,
      required String expenseDate,
      required String vendorName,
      required String memo,
    });

typedef MedicalVisitUpdater =
    Future<void> Function({
      required int visitId,
      required String hospitalName,
      required String visitReason,
      required String symptoms,
      required String diagnosis,
      required String treatment,
      required String prescribedItems,
      required String followUpDate,
      required String notes,
    });

typedef AttachmentUploader =
    Future<void> Function({
      required int visitId,
      required String fileType,
      required String filename,
      required Uint8List bytes,
    });

typedef DogUpdater = Future<void> Function(JsonMap payload);
typedef DogDeletePreviewLoader = Future<JsonMap> Function(int dogId);
typedef DogDeleter = Future<void> Function(int dogId);
typedef DogMembersLoader = Future<List<JsonMap>> Function(int dogId);
typedef DogMemberAdder =
    Future<JsonMap> Function({
      required int dogId,
      required String email,
      required String role,
    });
typedef DogMembershipUpdater =
    Future<JsonMap> Function({required int membershipId, required String role});
typedef DogMembershipRemover = Future<void> Function(int membershipId);

typedef ScheduleCreator =
    Future<void> Function({
      required String scheduleType,
      required String title,
      required String dueDate,
      required String description,
      required String priority,
      int? repeatCycleDays,
    });

typedef ScheduleUpdater =
    Future<void> Function({
      required int scheduleId,
      required String title,
      required String dueDate,
      required String description,
      required String priority,
      required bool reminderEnabled,
    });

typedef ConditionCreator =
    Future<void> Function({
      required String conditionType,
      required String conditionName,
      required String severity,
      required String diagnosedOn,
      required String status,
      required String notes,
    });

typedef ConditionUpdater =
    Future<void> Function({
      required int conditionId,
      required String conditionType,
      required String conditionName,
      required String severity,
      required String diagnosedOn,
      required String status,
      required String notes,
    });

typedef MedicationCreator =
    Future<void> Function({
      required String medicationName,
      required String dosage,
      required String frequencyText,
      required String startedOn,
      required String endedOn,
      required String prescribedBy,
      required bool isActive,
      required String notes,
    });

typedef MedicationUpdater =
    Future<void> Function({
      required int medicationId,
      required String medicationName,
      required String dosage,
      required String frequencyText,
      required String startedOn,
      required String endedOn,
      required String prescribedBy,
      required bool isActive,
      required String notes,
    });

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = LocalNotificationService();
  await notifications.initialize();
  runApp(PawPlanApp(notifications: notifications));
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
    return MaterialApp(
      title: 'PawPlan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _teal,
          brightness: Brightness.light,
          surface: _surface,
          primary: _teal,
        ),
        scaffoldBackgroundColor: _appBackground,
        fontFamilyFallback: const ['Apple SD Gothic Neo', 'Noto Sans KR'],
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
        dividerTheme: const DividerThemeData(color: _border, space: 1),
        iconTheme: const IconThemeData(color: _teal),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 28,
          dense: true,
          iconColor: _teal,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(44, 44),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.selected) ? _teal : _border,
              ),
            ),
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        expansionTileTheme: const ExpansionTileThemeData(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.only(left: 40, right: 4, bottom: 12),
          iconColor: _teal,
          collapsedIconColor: _mutedInk,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _teal, width: 1.4),
          ),
          filled: true,
          fillColor: _surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
      home: _AppHome(
        apiClient: _apiClient ?? ApiClient(),
        notifications: _notifications ?? LocalNotificationService(),
        sessionStore: _sessionStore ?? SessionStore(),
      ),
    );
  }
}

class _AppHome extends StatefulWidget {
  const _AppHome({
    required this.apiClient,
    required this.notifications,
    required this.sessionStore,
  });

  final ApiClient apiClient;
  final LocalNotificationService notifications;
  final SessionStore sessionStore;

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  final List<JsonMap> _dogs = [];
  final List<JsonMap> _schedules = [];
  final List<JsonMap> _healthLogs = [];
  final List<JsonMap> _medicalVisits = [];
  final List<JsonMap> _expenses = [];
  final List<JsonMap> _timelineItems = [];
  final List<JsonMap> _visitReports = [];
  final List<JsonMap> _conditions = [];
  final List<JsonMap> _medications = [];
  final List<JsonMap> _forecastHistory = [];
  JsonMap? _dashboard;
  JsonMap? _forecast;
  JsonMap? _report;
  int? _selectedDogId;
  bool _initializing = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await widget.sessionStore.readToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    widget.apiClient.setSessionToken(token);
    try {
      await widget.apiClient.me();
      await _loadDogs();
    } catch (_) {
      widget.apiClient.clearSession();
      await widget.sessionStore.clear();
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _login(String email, String password) {
    return _run(() async {
      await widget.apiClient.login(email: email, password: password);
      final token = widget.apiClient.accessToken;
      if (token != null) await widget.sessionStore.saveToken(token);
      await _loadDogs();
    });
  }

  Future<void> _register(String email, String password, String name) {
    return _run(() async {
      await widget.apiClient.register(
        email: email,
        password: password,
        name: name,
      );
      await widget.apiClient.login(email: email, password: password);
      final token = widget.apiClient.accessToken;
      if (token != null) await widget.sessionStore.saveToken(token);
      await _loadDogs();
    });
  }

  Future<void> _loadDogs() async {
    final dogs = await widget.apiClient.dogs();
    if (!mounted) return;
    setState(() {
      _dogs
        ..clear()
        ..addAll(dogs);
      _selectedDogId = dogs.isEmpty ? null : _asInt(dogs.first['id']);
      _dashboard = null;
      _forecast = null;
      _report = null;
      _schedules.clear();
      _healthLogs.clear();
      _medicalVisits.clear();
      _expenses.clear();
      _timelineItems.clear();
      _visitReports.clear();
      _conditions.clear();
      _medications.clear();
      _forecastHistory.clear();
    });

    if (_selectedDogId != null) {
      await _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    final dogId = _selectedDogId;
    if (dogId == null) return;

    final results = await Future.wait<dynamic>([
      widget.apiClient.dashboard(dogId),
      widget.apiClient.careSchedules(dogId),
      widget.apiClient.latestForecast(dogId),
      widget.apiClient.latestVisitReport(dogId),
      widget.apiClient.healthLogs(dogId),
      widget.apiClient.medicalVisits(dogId),
      widget.apiClient.expenses(dogId),
      widget.apiClient.timeline(dogId),
      widget.apiClient.visitReports(dogId),
      widget.apiClient.conditions(dogId),
      widget.apiClient.medications(dogId),
      widget.apiClient.forecastHistory(dogId),
    ]);

    if (!mounted) return;
    setState(() {
      _dashboard = results[0] as JsonMap;
      _schedules
        ..clear()
        ..addAll((results[1] as List<JsonMap>));
      _forecast = results[2] as JsonMap;
      _report = results[3] as JsonMap?;
      _healthLogs
        ..clear()
        ..addAll(results[4] as List<JsonMap>);
      _medicalVisits
        ..clear()
        ..addAll(results[5] as List<JsonMap>);
      _expenses
        ..clear()
        ..addAll(results[6] as List<JsonMap>);
      _timelineItems
        ..clear()
        ..addAll(results[7] as List<JsonMap>);
      _visitReports
        ..clear()
        ..addAll(results[8] as List<JsonMap>);
      _conditions
        ..clear()
        ..addAll(results[9] as List<JsonMap>);
      _medications
        ..clear()
        ..addAll(results[10] as List<JsonMap>);
      _forecastHistory
        ..clear()
        ..addAll(results[11] as List<JsonMap>);
    });

    await widget.notifications.syncCareReminders(_schedules);
  }

  Future<void> _selectDog(int dogId) {
    return _run(() async {
      setState(() {
        _selectedDogId = dogId;
        _dashboard = null;
        _forecast = null;
        _report = null;
        _schedules.clear();
        _healthLogs.clear();
        _medicalVisits.clear();
        _expenses.clear();
        _timelineItems.clear();
        _visitReports.clear();
        _conditions.clear();
        _medications.clear();
        _forecastHistory.clear();
      });
      await _loadDashboard();
    });
  }

  Future<void> _createDog(JsonMap payload) {
    return _run(() async {
      await widget.apiClient.onboardDog(payload);
      await _loadDogs();
    });
  }

  Future<void> _updateDog(JsonMap payload) {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
      await widget.apiClient.updateDog(dogId: dogId, payload: payload);
      await _loadDashboard();
      final dogs = await widget.apiClient.dogs();
      if (!mounted) return;
      setState(() {
        _dogs
          ..clear()
          ..addAll(dogs);
      });
    });
  }

  Future<void> _deleteDog(int dogId) {
    return _run(() async {
      await widget.apiClient.deleteDog(dogId);
      await _loadDogs();
    });
  }

  Future<JsonMap> _loadDogDeletePreview(int dogId) {
    return widget.apiClient.dogDeletePreview(dogId);
  }

  Future<JsonMap> _loadMe() {
    return widget.apiClient.me();
  }

  Future<List<JsonMap>> _loadDogMembers(int dogId) {
    return widget.apiClient.dogMembers(dogId);
  }

  Future<JsonMap> _addDogMember({
    required int dogId,
    required String email,
    required String role,
  }) {
    return widget.apiClient.addDogMember(
      dogId: dogId,
      email: email,
      role: role,
    );
  }

  Future<JsonMap> _updateDogMembership({
    required int membershipId,
    required String role,
  }) {
    return widget.apiClient.updateDogMembership(
      membershipId: membershipId,
      role: role,
    );
  }

  Future<void> _removeDogMembership(int membershipId) async {
    await widget.apiClient.removeDogMembership(membershipId);
  }

  Future<void> _completeSchedule(int scheduleId) {
    return _run(() async {
      await widget.apiClient.completeSchedule(scheduleId);
      await _loadDashboard();
    });
  }

  Future<void> _createSchedule({
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    int? repeatCycleDays,
  }) {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
      await widget.apiClient.createCareSchedule(
        dogId: dogId,
        scheduleType: scheduleType,
        title: title,
        dueDate: dueDate,
        description: description,
        priority: priority,
        repeatCycleDays: repeatCycleDays,
      );
      await _loadDashboard();
    });
  }

  Future<void> _updateSchedule({
    required int scheduleId,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    required bool reminderEnabled,
  }) {
    return _run(() async {
      await widget.apiClient.updateCareSchedule(
        scheduleId: scheduleId,
        title: title,
        dueDate: dueDate,
        description: description,
        priority: priority,
        reminderEnabled: reminderEnabled,
      );
      await _loadDashboard();
    });
  }

  Future<void> _skipSchedule(int scheduleId) {
    return _run(() async {
      await widget.apiClient.skipSchedule(scheduleId);
      await _loadDashboard();
    });
  }

  Future<void> _createHealthLog({
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
  }) {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
      await widget.apiClient.createHealthLog(
        dogId: dogId,
        logType: logType,
        title: title,
        memo: memo,
        valueNumeric: valueNumeric,
        valueUnit: valueUnit,
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
  }) {
    return _run(() async {
      await widget.apiClient.updateHealthLog(
        logId: logId,
        logType: logType,
        title: title,
        memo: memo,
        valueNumeric: valueNumeric,
        valueUnit: valueUnit,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteHealthLog(int logId) {
    return _run(() async {
      await widget.apiClient.deleteHealthLog(logId);
      await _loadDashboard();
    });
  }

  Future<void> _createExpense({
    required String category,
    required num amount,
    required String vendorName,
    required String memo,
  }) {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
      await widget.apiClient.createExpense(
        dogId: dogId,
        category: category,
        amount: amount,
        vendorName: vendorName,
        memo: memo,
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
  }) {
    return _run(() async {
      await widget.apiClient.updateExpense(
        expenseId: expenseId,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        vendorName: vendorName,
        memo: memo,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteExpense(int expenseId) {
    return _run(() async {
      await widget.apiClient.deleteExpense(expenseId);
      await _loadDashboard();
    });
  }

  Future<void> _createMedicalVisit({
    required String hospitalName,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required num? expenseAmount,
  }) {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
      await widget.apiClient.createMedicalVisit(
        dogId: dogId,
        hospitalName: hospitalName,
        visitReason: visitReason,
        symptoms: symptoms,
        diagnosis: diagnosis,
        treatment: treatment,
        prescribedItems: prescribedItems,
        followUpDate: followUpDate,
        expenseAmount: expenseAmount,
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
  }) {
    return _run(() async {
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
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteMedicalVisit(int visitId) {
    return _run(() async {
      await widget.apiClient.deleteMedicalVisit(visitId);
      await _loadDashboard();
    });
  }

  Future<void> _uploadVisitAttachment({
    required int visitId,
    required String fileType,
    required String filename,
    required Uint8List bytes,
  }) {
    return _run(() async {
      await widget.apiClient.uploadVisitAttachment(
        visitId: visitId,
        fileType: fileType,
        filename: filename,
        bytes: bytes,
      );
      await _loadDashboard();
    });
  }

  Future<void> _deleteAttachment(int attachmentId) {
    return _run(() async {
      await widget.apiClient.deleteAttachment(attachmentId);
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
  }) {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
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
  }) {
    return _run(() async {
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

  Future<void> _deleteCondition(int conditionId) {
    return _run(() async {
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
  }) {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
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
  }) {
    return _run(() async {
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

  Future<void> _deleteMedication(int medicationId) {
    return _run(() async {
      await widget.apiClient.deleteMedication(medicationId);
      await _loadDashboard();
    });
  }

  Future<void> _createVisitReport() {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
      await widget.apiClient.generateVisitReport(dogId);
      await _loadDashboard();
      final dogName =
          (_dashboard?['dog'] as JsonMap?)?['name'] as String? ?? '반려견';
      await widget.notifications.showReportReady(dogName);
    });
  }

  Future<void> _recalculateForecast() {
    return _run(() async {
      final dogId = _selectedDogId;
      if (dogId == null) return;
      await widget.apiClient.recalculateForecast(dogId);
      await _loadDashboard();
    });
  }

  void _logout() {
    widget.apiClient.clearSession();
    widget.sessionStore.clear();
    setState(() {
      _dogs.clear();
      _schedules.clear();
      _dashboard = null;
      _forecast = null;
      _report = null;
      _selectedDogId = null;
      _healthLogs.clear();
      _medicalVisits.clear();
      _expenses.clear();
      _timelineItems.clear();
      _visitReports.clear();
      _conditions.clear();
      _medications.clear();
      _forecastHistory.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_initializing) {
      content = const _StartupScreen();
    } else if (!widget.apiClient.isAuthenticated) {
      content = AuthScreen(busy: _busy, onLogin: _login, onRegister: _register);
    } else if (_dogs.isEmpty) {
      content = OnboardingScreen(
        busy: _busy,
        onSubmit: _createDog,
        onLogout: _logout,
      );
    } else {
      content = DashboardScreen(
        busy: _busy,
        dogs: _dogs,
        selectedDogId: _selectedDogId,
        dashboard: _dashboard,
        forecast: _forecast,
        schedules: _schedules,
        healthLogs: _healthLogs,
        medicalVisits: _medicalVisits,
        expenses: _expenses,
        timelineItems: _timelineItems,
        report: _report,
        visitReports: _visitReports,
        conditions: _conditions,
        medications: _medications,
        forecastHistory: _forecastHistory,
        onSelectDog: _selectDog,
        onRefresh: () => _run(_loadDashboard),
        onUpdateDog: _updateDog,
        onLoadDogDeletePreview: _loadDogDeletePreview,
        onDeleteDog: _deleteDog,
        onLoadMe: _loadMe,
        onLoadDogMembers: _loadDogMembers,
        onAddDogMember: _addDogMember,
        onUpdateDogMembership: _updateDogMembership,
        onRemoveDogMembership: _removeDogMembership,
        onCompleteSchedule: _completeSchedule,
        onCreateSchedule: _createSchedule,
        onUpdateSchedule: _updateSchedule,
        onSkipSchedule: _skipSchedule,
        onCreateHealthLog: _createHealthLog,
        onCreateExpense: _createExpense,
        onCreateMedicalVisit: _createMedicalVisit,
        onUpdateHealthLog: _updateHealthLog,
        onDeleteHealthLog: _deleteHealthLog,
        onUpdateExpense: _updateExpense,
        onDeleteExpense: _deleteExpense,
        onUpdateMedicalVisit: _updateMedicalVisit,
        onDeleteMedicalVisit: _deleteMedicalVisit,
        onUploadAttachment: _uploadVisitAttachment,
        onDeleteAttachment: _deleteAttachment,
        onCreateCondition: _createCondition,
        onUpdateCondition: _updateCondition,
        onDeleteCondition: _deleteCondition,
        onCreateMedication: _createMedication,
        onUpdateMedication: _updateMedication,
        onDeleteMedication: _deleteMedication,
        onCreateVisitReport: _createVisitReport,
        onRecalculateForecast: _recalculateForecast,
        onLogout: _logout,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          content,
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF3D1F22),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 18),
            Text('PawPlan 세션 확인 중'),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.busy,
    required this.onLogin,
    required this.onRegister,
  });

  final bool busy;
  final Future<void> Function(String email, String password) onLogin;
  final Future<void> Function(String email, String password, String name)
  onRegister;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'demo@pawplan.kr');
  final _password = TextEditingController(text: 'password123');
  final _name = TextEditingController(text: '보호자');
  bool _registerMode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_registerMode) {
      await widget.onRegister(
        _email.text.trim(),
        _password.text,
        _name.text.trim(),
      );
    } else {
      await widget.onLogin(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final form = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _AuthFormBody(
              formKey: _formKey,
              email: _email,
              password: _password,
              name: _name,
              registerMode: _registerMode,
              busy: widget.busy,
              onModeChanged: (value) => setState(() => _registerMode = value),
              onSubmit: _submit,
            ),
          );

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, wide ? 48 : 84, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: _AuthBrandPanel()),
                          const SizedBox(width: 64),
                          Expanded(child: form),
                        ],
                      )
                    : form,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthFormBody extends StatelessWidget {
  const _AuthFormBody({
    required this.formKey,
    required this.email,
    required this.password,
    required this.name,
    required this.registerMode,
    required this.busy,
    required this.onModeChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController name;
  final bool registerMode;
  final bool busy;
  final ValueChanged<bool> onModeChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PawPlan',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '건강 기록, 지출, 병원 방문 리포트를 한 흐름에서 관리합니다.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: _mutedInk, height: 1.35),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('로그인', softWrap: false),
                icon: Icon(Icons.login),
              ),
              ButtonSegment(
                value: true,
                label: Text('가입', softWrap: false),
                icon: Icon(Icons.person_add_alt),
              ),
            ],
            selected: {registerMode},
            onSelectionChanged: busy
                ? null
                : (value) => onModeChanged(value.first),
          ),
        ),
        const SizedBox(height: 18),
        Form(
          key: formKey,
          child: Column(
            children: [
              if (registerMode) ...[
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '이름'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const ValueKey('auth-email-field'),
                controller: email,
                decoration: const InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return '이메일을 입력하세요.';
                  if (!text.contains('@')) return '이메일 형식이 필요합니다.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('auth-password-field'),
                controller: password,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                validator: (value) {
                  if ((value ?? '').length < 8) {
                    return '8자 이상 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('auth-submit-button'),
                  onPressed: busy ? null : onSubmit,
                  icon: Icon(registerMode ? Icons.person_add_alt : Icons.login),
                  label: Text(registerMode ? '가입하고 시작' : '로그인'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '백엔드 기본 주소: ${resolveDefaultApiBaseUrl()}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: _mutedInk),
        ),
      ],
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 440,
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: _deepTeal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.pets, color: _gold),
          ),
          const Spacer(),
          const Text(
            '돌봄 기록을 한 화면에서',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '일정, 진료, 지출 데이터를 같은 흐름으로 묶어 보호자의 다음 행동을 빠르게 정리합니다.',
            style: TextStyle(color: Color(0xFFC8D7D3), height: 1.45),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _AuthSignal(icon: Icons.today, label: '오늘 일정'),
              _AuthSignal(icon: Icons.monitor_heart_outlined, label: '건강 기록'),
              _AuthSignal(icon: Icons.receipt_long, label: '비용 예측'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthSignal extends StatelessWidget {
  const _AuthSignal({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: _gold),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.busy,
    required this.onSubmit,
    required this.onLogout,
  });

  final bool busy;
  final Future<void> Function(JsonMap payload) onSubmit;
  final VoidCallback onLogout;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: '콩이');
  final _breed = TextEditingController(text: '말티푸');
  final _birthDate = TextEditingController(text: '2021-05-10');
  final _weight = TextEditingController(text: '5.4');
  String _sex = 'female';
  bool _neutered = true;

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _birthDate.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit({
      'dog': {
        'name': _name.text.trim(),
        'breed': _breed.text.trim(),
        'birthDate': _birthDate.text.trim(),
        'sex': _sex,
        'neutered': _neutered,
        'currentWeightKg': num.tryParse(_weight.text.trim()),
        'activityLevel': 'medium',
        'insuranceStatus': 'none',
      },
      'conditions': [],
      'medications': [],
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '반려견 등록',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '로그아웃',
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '첫 등록 시 기본 돌봄 일정과 초기 비용 예측이 생성됩니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5C615F),
                  ),
                ),
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: '이름'),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _breed,
                        decoration: const InputDecoration(labelText: '견종'),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _birthDate,
                        decoration: const InputDecoration(
                          labelText: '생일 yyyy-mm-dd',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          return DateTime.tryParse(text) == null
                              ? '날짜 형식이 필요합니다.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _weight,
                        decoration: const InputDecoration(
                          labelText: '현재 체중 kg',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          return num.tryParse(value!.trim()) == null
                              ? '숫자로 입력하세요.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _sex,
                        decoration: const InputDecoration(labelText: '성별'),
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('암컷')),
                          DropdownMenuItem(value: 'male', child: Text('수컷')),
                          DropdownMenuItem(value: 'unknown', child: Text('모름')),
                        ],
                        onChanged: widget.busy
                            ? null
                            : (value) => setState(() => _sex = value ?? _sex),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('중성화 완료'),
                        value: _neutered,
                        onChanged: widget.busy
                            ? null
                            : (value) => setState(() => _neutered = value),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.busy ? null : _submit,
                          icon: const Icon(Icons.pets),
                          label: const Text('등록하고 대시보드 열기'),
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
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.busy,
    required this.dogs,
    required this.selectedDogId,
    required this.dashboard,
    required this.forecast,
    required this.schedules,
    required this.healthLogs,
    required this.medicalVisits,
    required this.expenses,
    required this.timelineItems,
    required this.report,
    required this.visitReports,
    required this.conditions,
    required this.medications,
    required this.forecastHistory,
    required this.onSelectDog,
    required this.onRefresh,
    required this.onUpdateDog,
    required this.onLoadDogDeletePreview,
    required this.onDeleteDog,
    required this.onLoadMe,
    required this.onLoadDogMembers,
    required this.onAddDogMember,
    required this.onUpdateDogMembership,
    required this.onRemoveDogMembership,
    required this.onCompleteSchedule,
    required this.onCreateSchedule,
    required this.onUpdateSchedule,
    required this.onSkipSchedule,
    required this.onCreateHealthLog,
    required this.onCreateExpense,
    required this.onCreateMedicalVisit,
    required this.onUpdateHealthLog,
    required this.onDeleteHealthLog,
    required this.onUpdateExpense,
    required this.onDeleteExpense,
    required this.onUpdateMedicalVisit,
    required this.onDeleteMedicalVisit,
    required this.onUploadAttachment,
    required this.onDeleteAttachment,
    required this.onCreateCondition,
    required this.onUpdateCondition,
    required this.onDeleteCondition,
    required this.onCreateMedication,
    required this.onUpdateMedication,
    required this.onDeleteMedication,
    required this.onCreateVisitReport,
    required this.onRecalculateForecast,
    required this.onLogout,
  });

  final bool busy;
  final List<JsonMap> dogs;
  final int? selectedDogId;
  final JsonMap? dashboard;
  final JsonMap? forecast;
  final List<JsonMap> schedules;
  final List<JsonMap> healthLogs;
  final List<JsonMap> medicalVisits;
  final List<JsonMap> expenses;
  final List<JsonMap> timelineItems;
  final JsonMap? report;
  final List<JsonMap> visitReports;
  final List<JsonMap> conditions;
  final List<JsonMap> medications;
  final List<JsonMap> forecastHistory;
  final Future<void> Function(int dogId) onSelectDog;
  final Future<void> Function() onRefresh;
  final DogUpdater onUpdateDog;
  final DogDeletePreviewLoader onLoadDogDeletePreview;
  final DogDeleter onDeleteDog;
  final Future<JsonMap> Function() onLoadMe;
  final DogMembersLoader onLoadDogMembers;
  final DogMemberAdder onAddDogMember;
  final DogMembershipUpdater onUpdateDogMembership;
  final DogMembershipRemover onRemoveDogMembership;
  final Future<void> Function(int scheduleId) onCompleteSchedule;
  final ScheduleCreator onCreateSchedule;
  final ScheduleUpdater onUpdateSchedule;
  final Future<void> Function(int scheduleId) onSkipSchedule;
  final Future<void> Function({
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
  })
  onCreateHealthLog;
  final Future<void> Function({
    required String category,
    required num amount,
    required String vendorName,
    required String memo,
  })
  onCreateExpense;
  final Future<void> Function({
    required String hospitalName,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required num? expenseAmount,
  })
  onCreateMedicalVisit;
  final HealthLogUpdater onUpdateHealthLog;
  final Future<void> Function(int logId) onDeleteHealthLog;
  final ExpenseUpdater onUpdateExpense;
  final Future<void> Function(int expenseId) onDeleteExpense;
  final MedicalVisitUpdater onUpdateMedicalVisit;
  final Future<void> Function(int visitId) onDeleteMedicalVisit;
  final AttachmentUploader onUploadAttachment;
  final Future<void> Function(int attachmentId) onDeleteAttachment;
  final ConditionCreator onCreateCondition;
  final ConditionUpdater onUpdateCondition;
  final Future<void> Function(int conditionId) onDeleteCondition;
  final MedicationCreator onCreateMedication;
  final MedicationUpdater onUpdateMedication;
  final Future<void> Function(int medicationId) onDeleteMedication;
  final Future<void> Function() onCreateVisitReport;
  final Future<void> Function() onRecalculateForecast;
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _sectionIndex = 0;

  bool get busy => widget.busy;
  List<JsonMap> get dogs => widget.dogs;
  int? get selectedDogId => widget.selectedDogId;
  JsonMap? get dashboard => widget.dashboard;
  JsonMap? get forecast => widget.forecast;
  List<JsonMap> get schedules => widget.schedules;
  List<JsonMap> get healthLogs => widget.healthLogs;
  List<JsonMap> get medicalVisits => widget.medicalVisits;
  List<JsonMap> get expenses => widget.expenses;
  List<JsonMap> get timelineItems => widget.timelineItems;
  JsonMap? get report => widget.report;
  List<JsonMap> get visitReports => widget.visitReports;
  List<JsonMap> get conditions => widget.conditions;
  List<JsonMap> get medications => widget.medications;
  List<JsonMap> get forecastHistory => widget.forecastHistory;
  Future<void> Function(int dogId) get onSelectDog => widget.onSelectDog;
  Future<void> Function() get onRefresh => widget.onRefresh;
  DogUpdater get onUpdateDog => widget.onUpdateDog;
  DogDeletePreviewLoader get onLoadDogDeletePreview =>
      widget.onLoadDogDeletePreview;
  DogDeleter get onDeleteDog => widget.onDeleteDog;
  Future<JsonMap> Function() get onLoadMe => widget.onLoadMe;
  DogMembersLoader get onLoadDogMembers => widget.onLoadDogMembers;
  DogMemberAdder get onAddDogMember => widget.onAddDogMember;
  DogMembershipUpdater get onUpdateDogMembership =>
      widget.onUpdateDogMembership;
  DogMembershipRemover get onRemoveDogMembership =>
      widget.onRemoveDogMembership;
  Future<void> Function(int scheduleId) get onCompleteSchedule =>
      widget.onCompleteSchedule;
  ScheduleCreator get onCreateSchedule => widget.onCreateSchedule;
  ScheduleUpdater get onUpdateSchedule => widget.onUpdateSchedule;
  Future<void> Function(int scheduleId) get onSkipSchedule =>
      widget.onSkipSchedule;
  Future<void> Function({
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
  })
  get onCreateHealthLog => widget.onCreateHealthLog;
  Future<void> Function({
    required String category,
    required num amount,
    required String vendorName,
    required String memo,
  })
  get onCreateExpense => widget.onCreateExpense;
  Future<void> Function({
    required String hospitalName,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required num? expenseAmount,
  })
  get onCreateMedicalVisit => widget.onCreateMedicalVisit;
  HealthLogUpdater get onUpdateHealthLog => widget.onUpdateHealthLog;
  Future<void> Function(int logId) get onDeleteHealthLog =>
      widget.onDeleteHealthLog;
  ExpenseUpdater get onUpdateExpense => widget.onUpdateExpense;
  Future<void> Function(int expenseId) get onDeleteExpense =>
      widget.onDeleteExpense;
  MedicalVisitUpdater get onUpdateMedicalVisit => widget.onUpdateMedicalVisit;
  Future<void> Function(int visitId) get onDeleteMedicalVisit =>
      widget.onDeleteMedicalVisit;
  AttachmentUploader get onUploadAttachment => widget.onUploadAttachment;
  Future<void> Function(int attachmentId) get onDeleteAttachment =>
      widget.onDeleteAttachment;
  ConditionCreator get onCreateCondition => widget.onCreateCondition;
  ConditionUpdater get onUpdateCondition => widget.onUpdateCondition;
  Future<void> Function(int conditionId) get onDeleteCondition =>
      widget.onDeleteCondition;
  MedicationCreator get onCreateMedication => widget.onCreateMedication;
  MedicationUpdater get onUpdateMedication => widget.onUpdateMedication;
  Future<void> Function(int medicationId) get onDeleteMedication =>
      widget.onDeleteMedication;
  Future<void> Function() get onCreateVisitReport => widget.onCreateVisitReport;
  Future<void> Function() get onRecalculateForecast =>
      widget.onRecalculateForecast;
  VoidCallback get onLogout => widget.onLogout;

  @override
  Widget build(BuildContext context) {
    final dog = dashboard?['dog'] as JsonMap?;
    final dogName = dog?['name'] as String? ?? '반려견';
    final breed = dog?['breed'] as String? ?? '';
    final monthlySummary = dashboard?['monthlyExpenseSummary'] as JsonMap?;
    final totalAmount = _asNum(monthlySummary?['totalAmount']) ?? 0;
    final basicForecast = forecast?['basic'] as JsonMap?;
    final latestForecast = dashboard?['latestForecast'] as JsonMap?;
    final access = dashboard?['access'] as JsonMap?;
    final canManageDog = access?['canManage'] == true;
    final role = access?['role'] as String?;
    final canEditRecords = role == 'owner' || role == 'editor';
    final recentHealthLogs =
        (dashboard?['recentHealthLogs'] as List<dynamic>? ?? [])
            .cast<JsonMap>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Row(
                      children: [
                        const Text(
                          'PawPlan',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DogSelector(
                            dogs: dogs,
                            selectedDogId: selectedDogId,
                            enabled: !busy,
                            onChanged: onSelectDog,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('dashboard-refresh-button'),
                          tooltip: '새로고침',
                          onPressed: busy ? null : onRefresh,
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: '로그아웃',
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    child: Column(
                      children: [
                        _HeroBand(
                          dog: dog,
                          dogName: dogName,
                          breed: breed,
                          busy: busy,
                          canManageDog: canManageDog,
                          onEditDog: onUpdateDog,
                          onLoadDeletePreview: onLoadDogDeletePreview,
                          onDeleteDog: onDeleteDog,
                          onLoadMe: onLoadMe,
                          onLoadMembers: onLoadDogMembers,
                          onAddMember: onAddDogMember,
                          onUpdateMembership: onUpdateDogMembership,
                          onRemoveMembership: onRemoveDogMembership,
                          onCreateReport: busy ? null : onCreateVisitReport,
                        ),
                        const SizedBox(height: 18),
                        _DashboardSegment(
                          value: _sectionIndex,
                          onChanged: (value) =>
                              setState(() => _sectionIndex = value),
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0, 0.018),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: switch (_sectionIndex) {
                            0 => _OverviewPane(
                              key: const ValueKey('overview'),
                              totalAmount: totalAmount,
                              scheduleCount: schedules.length,
                              sixMonthEstimate: _asNum(
                                basicForecast?['sixMonthEstimate'],
                              ),
                              schedules: schedules,
                              recentHealthLogs: recentHealthLogs,
                              busy: busy,
                              canEditRecords: canEditRecords,
                              onCompleteSchedule: onCompleteSchedule,
                              onCreateSchedule: onCreateSchedule,
                              onUpdateSchedule: onUpdateSchedule,
                              onSkipSchedule: onSkipSchedule,
                              onCreateHealthLog: onCreateHealthLog,
                              onCreateExpense: onCreateExpense,
                              onCreateMedicalVisit: onCreateMedicalVisit,
                              onCreateVisitReport: onCreateVisitReport,
                            ),
                            1 => _RecordsPane(
                              key: const ValueKey('records'),
                              busy: busy,
                              healthLogs: healthLogs,
                              medicalVisits: medicalVisits,
                              expenses: expenses,
                              timelineItems: timelineItems,
                              canEditRecords: canEditRecords,
                              onUpdateHealthLog: onUpdateHealthLog,
                              onDeleteHealthLog: onDeleteHealthLog,
                              onUpdateExpense: onUpdateExpense,
                              onDeleteExpense: onDeleteExpense,
                              onUpdateMedicalVisit: onUpdateMedicalVisit,
                              onDeleteMedicalVisit: onDeleteMedicalVisit,
                              onUploadAttachment: onUploadAttachment,
                              onDeleteAttachment: onDeleteAttachment,
                            ),
                            2 => _HealthInfoPane(
                              key: const ValueKey('health-info'),
                              busy: busy,
                              canEditRecords: canEditRecords,
                              conditions: conditions,
                              medications: medications,
                              onCreateCondition: onCreateCondition,
                              onUpdateCondition: onUpdateCondition,
                              onDeleteCondition: onDeleteCondition,
                              onCreateMedication: onCreateMedication,
                              onUpdateMedication: onUpdateMedication,
                              onDeleteMedication: onDeleteMedication,
                            ),
                            _ => _ReportsPane(
                              key: const ValueKey('reports'),
                              report: report,
                              visitReports: visitReports,
                              busy: busy,
                              canEditRecords: canEditRecords,
                              forecast: basicForecast,
                              fallbackForecast: latestForecast,
                              forecastHistory: forecastHistory,
                              onCreateVisitReport: onCreateVisitReport,
                              onRecalculateForecast: onRecalculateForecast,
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSegment extends StatelessWidget {
  const _DashboardSegment({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final control = SegmentedButton<int>(
          key: const ValueKey('dashboard-segment'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.today),
              label: Text(
                '오늘',
                key: ValueKey('dashboard-tab-today'),
                softWrap: false,
              ),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.list_alt),
              label: Text(
                '기록',
                key: ValueKey('dashboard-tab-records'),
                softWrap: false,
              ),
            ),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.health_and_safety_outlined),
              label: Text(
                '정보',
                key: ValueKey('dashboard-tab-health-info'),
                softWrap: false,
              ),
            ),
            ButtonSegment(
              value: 3,
              icon: Icon(Icons.summarize_outlined),
              label: Text(
                '리포트',
                key: ValueKey('dashboard-tab-reports'),
                softWrap: false,
              ),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        );

        if (!compact) {
          return SizedBox(width: double.infinity, child: control);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 438, child: control),
        );
      },
    );
  }
}

class _OverviewPane extends StatelessWidget {
  const _OverviewPane({
    super.key,
    required this.totalAmount,
    required this.scheduleCount,
    required this.sixMonthEstimate,
    required this.schedules,
    required this.recentHealthLogs,
    required this.busy,
    required this.canEditRecords,
    required this.onCompleteSchedule,
    required this.onCreateSchedule,
    required this.onUpdateSchedule,
    required this.onSkipSchedule,
    required this.onCreateHealthLog,
    required this.onCreateExpense,
    required this.onCreateMedicalVisit,
    required this.onCreateVisitReport,
  });

  final num totalAmount;
  final int scheduleCount;
  final num? sixMonthEstimate;
  final List<JsonMap> schedules;
  final List<JsonMap> recentHealthLogs;
  final bool busy;
  final bool canEditRecords;
  final Future<void> Function(int scheduleId) onCompleteSchedule;
  final ScheduleCreator onCreateSchedule;
  final ScheduleUpdater onUpdateSchedule;
  final Future<void> Function(int scheduleId) onSkipSchedule;
  final Future<void> Function({
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
  })
  onCreateHealthLog;
  final Future<void> Function({
    required String category,
    required num amount,
    required String vendorName,
    required String memo,
  })
  onCreateExpense;
  final Future<void> Function({
    required String hospitalName,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required num? expenseAmount,
  })
  onCreateMedicalVisit;
  final Future<void> Function() onCreateVisitReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final metrics = [
              _MetricTile(
                icon: Icons.receipt_long,
                label: '이번 달 지출',
                value: _won(totalAmount),
                tone: _coral,
              ),
              _MetricTile(
                icon: Icons.calendar_month,
                label: '예정 일정',
                value: '$scheduleCount건',
                tone: _teal,
              ),
              _MetricTile(
                icon: Icons.savings,
                label: '6개월 예측',
                value: _won(sixMonthEstimate),
                tone: _violet,
              ),
            ];

            if (compact) {
              return Column(
                children: metrics
                    .map(
                      (metric) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: metric,
                      ),
                    )
                    .toList(),
              );
            }

            return Row(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  Expanded(child: metrics[index]),
                  if (index != metrics.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _Section(
          title: '돌봄 일정',
          trailing: TextButton.icon(
            key: const ValueKey('schedule-create-open'),
            onPressed: busy || !canEditRecords
                ? null
                : () => _showScheduleEditor(context, null, onCreateSchedule),
            icon: const Icon(Icons.add),
            label: const Text('추가'),
          ),
          child: schedules.isEmpty
              ? const _EmptyState(text: '대기 중인 일정이 없습니다.')
              : Column(
                  children: schedules
                      .take(5)
                      .map(
                        (schedule) => _ScheduleRow(
                          schedule: schedule,
                          onComplete: busy
                              || !canEditRecords
                              ? null
                              : () {
                                  final id = _asInt(schedule['id']);
                                  if (id != null) onCompleteSchedule(id);
                                },
                          onEdit: busy
                              || !canEditRecords
                              ? null
                              : () => _showScheduleEditor(
                                  context,
                                  schedule,
                                  onCreateSchedule,
                                  onUpdate: onUpdateSchedule,
                                ),
                          onSkip: busy
                              || !canEditRecords
                              ? null
                              : () {
                                  final id = _asInt(schedule['id']);
                                  if (id != null) onSkipSchedule(id);
                                },
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: '최근 건강 기록',
          child: recentHealthLogs.isEmpty
              ? const _EmptyState(text: '아직 건강 기록이 없습니다.')
              : Column(
                  children: recentHealthLogs
                      .map((log) => _HealthLogTile(log: log, compact: true))
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        QuickHealthLogPanel(
          busy: busy || !canEditRecords,
          onSubmit: onCreateHealthLog,
        ),
        const SizedBox(height: 18),
        QuickExpensePanel(
          busy: busy || !canEditRecords,
          onSubmit: onCreateExpense,
        ),
        const SizedBox(height: 18),
        MedicalVisitPanel(
          busy: busy || !canEditRecords,
          onSubmit: onCreateMedicalVisit,
          onCreateReport: onCreateVisitReport,
        ),
      ],
    );
  }
}

class _RecordsPane extends StatefulWidget {
  const _RecordsPane({
    super.key,
    required this.busy,
    required this.canEditRecords,
    required this.healthLogs,
    required this.medicalVisits,
    required this.expenses,
    required this.timelineItems,
    required this.onUpdateHealthLog,
    required this.onDeleteHealthLog,
    required this.onUpdateExpense,
    required this.onDeleteExpense,
    required this.onUpdateMedicalVisit,
    required this.onDeleteMedicalVisit,
    required this.onUploadAttachment,
    required this.onDeleteAttachment,
  });

  final bool busy;
  final bool canEditRecords;
  final List<JsonMap> healthLogs;
  final List<JsonMap> medicalVisits;
  final List<JsonMap> expenses;
  final List<JsonMap> timelineItems;
  final HealthLogUpdater onUpdateHealthLog;
  final Future<void> Function(int logId) onDeleteHealthLog;
  final ExpenseUpdater onUpdateExpense;
  final Future<void> Function(int expenseId) onDeleteExpense;
  final MedicalVisitUpdater onUpdateMedicalVisit;
  final Future<void> Function(int visitId) onDeleteMedicalVisit;
  final AttachmentUploader onUploadAttachment;
  final Future<void> Function(int attachmentId) onDeleteAttachment;

  @override
  State<_RecordsPane> createState() => _RecordsPaneState();
}

class _RecordsPaneState extends State<_RecordsPane> {
  String _timelineFilter = 'all';

  List<JsonMap> get _visibleTimelineItems {
    if (_timelineFilter == 'all') return widget.timelineItems;
    return widget.timelineItems
        .where((item) => item['itemType'] == _timelineFilter)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final totalExpense = widget.expenses.fold<num>(
      0,
      (sum, item) => sum + (_asNum(item['amount']) ?? 0),
    );
    final timelineItems = _visibleTimelineItems;

    return Column(
      children: [
        _Section(
          title: '기록 요약',
          child: _InlineStats(
            items: [
              _InlineStat('건강', '${widget.healthLogs.length}건'),
              _InlineStat('방문', '${widget.medicalVisits.length}건'),
              _InlineStat('지출', _won(totalExpense)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: '통합 타임라인',
          trailing: Text(
            '${timelineItems.length}건',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D7471)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  key: const ValueKey('timeline-filter-control'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<String>(
                      value: 'all',
                      label: Text(
                        '전체',
                        key: ValueKey('timeline-filter-all'),
                        softWrap: false,
                      ),
                    ),
                    ButtonSegment<String>(
                      value: 'health_log',
                      label: Text(
                        '건강',
                        key: ValueKey('timeline-filter-health'),
                        softWrap: false,
                      ),
                    ),
                    ButtonSegment<String>(
                      value: 'medical_visit',
                      label: Text(
                        '병원',
                        key: ValueKey('timeline-filter-visit'),
                        softWrap: false,
                      ),
                    ),
                    ButtonSegment<String>(
                      value: 'expense',
                      label: Text(
                        '지출',
                        key: ValueKey('timeline-filter-expense'),
                        softWrap: false,
                      ),
                    ),
                  ],
                  selected: {_timelineFilter},
                  onSelectionChanged: (selection) =>
                      setState(() => _timelineFilter = selection.first),
                ),
              ),
              const SizedBox(height: 12),
              if (timelineItems.isEmpty)
                const _EmptyState(text: '표시할 타임라인 항목이 없습니다.')
              else
                Column(
                  children: timelineItems
                      .map((item) => _TimelineItemTile(item: item))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: '건강 기록',
          child: widget.healthLogs.isEmpty
              ? const _EmptyState(text: '저장된 건강 기록이 없습니다.')
              : Column(
                  children: widget.healthLogs
                      .map(
                        (log) => _HealthLogTile(
                          log: log,
                          onEdit: widget.busy || !widget.canEditRecords
                              ? null
                              : () => _showHealthLogEditor(
                                  context,
                                  log,
                                  widget.onUpdateHealthLog,
                                ),
                          onDelete: widget.busy || !widget.canEditRecords
                              ? null
                              : () => _confirmAndDelete(
                                  context: context,
                                  title: '건강 기록 삭제',
                                  message: '선택한 건강 기록을 삭제할까요?',
                                  id: _asInt(log['id']),
                                  onDelete: widget.onDeleteHealthLog,
                                ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: '병원 방문 기록',
          child: widget.medicalVisits.isEmpty
              ? const _EmptyState(text: '저장된 병원 방문 기록이 없습니다.')
              : Column(
                  children: widget.medicalVisits
                      .map(
                        (visit) => _MedicalVisitTile(
                          visit: visit,
                          busy: widget.busy || !widget.canEditRecords,
                          onUploadAttachment: widget.onUploadAttachment,
                          onDeleteAttachment: widget.onDeleteAttachment,
                          onEdit: widget.busy || !widget.canEditRecords
                              ? null
                              : () => _showMedicalVisitEditor(
                                  context,
                                  visit,
                                  widget.onUpdateMedicalVisit,
                                ),
                          onDelete: widget.busy || !widget.canEditRecords
                              ? null
                              : () => _confirmAndDelete(
                                  context: context,
                                  title: '병원 방문 삭제',
                                  message: '방문 기록만 삭제하고 연결된 지출은 보존합니다.',
                                  id: _asInt(visit['id']),
                                  onDelete: widget.onDeleteMedicalVisit,
                                ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: '지출 기록',
          child: widget.expenses.isEmpty
              ? const _EmptyState(text: '저장된 지출 기록이 없습니다.')
              : Column(
                  children: widget.expenses
                      .map(
                        (expense) => _ExpenseTile(
                          expense: expense,
                          onEdit: widget.busy || !widget.canEditRecords
                              ? null
                              : () => _showExpenseEditor(
                                  context,
                                  expense,
                                  widget.onUpdateExpense,
                                ),
                          onDelete: widget.busy || !widget.canEditRecords
                              ? null
                              : () => _confirmAndDelete(
                                  context: context,
                                  title: '지출 삭제',
                                  message: '선택한 지출 기록을 삭제할까요?',
                                  id: _asInt(expense['id']),
                                  onDelete: widget.onDeleteExpense,
                                ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _TimelineItemTile extends StatelessWidget {
  const _TimelineItemTile({required this.item});

  final JsonMap item;

  @override
  Widget build(BuildContext context) {
    final itemType = item['itemType'] as String? ?? 'record';
    final id = _asInt(item['id']);
    final title =
        item['title'] as String? ?? '${_timelineTypeLabel(itemType)} 기록';
    final summary = _timelineSummaryParts(item).join(' · ');
    final color = _timelineItemColor(itemType);

    return ListTile(
      key: ValueKey(
        id == null ? 'timeline-item-$itemType' : 'timeline-item-$itemType-$id',
      ),
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_timelineIcon(itemType), color: color),
      ),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

List<String> _timelineSummaryParts(JsonMap item) {
  final itemType = item['itemType'] as String? ?? 'record';
  final parts = <String>[
    _formatDate(_timelineEventAt(item)),
    _timelineTypeLabel(itemType),
  ];
  if (itemType == 'expense') {
    parts.add(_won(item['amount']));
  }

  final summary = item['summary'] as String?;
  if (summary != null && summary.trim().isNotEmpty) {
    parts.add(summary);
  }

  final attachmentCount = _asInt(item['attachmentCount']);
  if (itemType == 'medical_visit' &&
      attachmentCount != null &&
      attachmentCount > 0) {
    parts.add('첨부 $attachmentCount개');
  }
  return parts.where((value) => value.trim().isNotEmpty).toList();
}

String? _timelineEventAt(JsonMap item) {
  final value =
      item['eventAt'] ??
      item['recordedAt'] ??
      item['visitDate'] ??
      item['expenseDate'];
  return value is String ? value : null;
}

String _timelineTypeLabel(String itemType) {
  return switch (itemType) {
    'health_log' => '건강',
    'medical_visit' => '병원',
    'expense' => '지출',
    _ => '기록',
  };
}

IconData _timelineIcon(String itemType) {
  return switch (itemType) {
    'health_log' => Icons.monitor_heart_outlined,
    'medical_visit' => Icons.local_hospital_outlined,
    'expense' => Icons.payments_outlined,
    _ => Icons.timeline_outlined,
  };
}

Color _timelineItemColor(String itemType) {
  return switch (itemType) {
    'health_log' => const Color(0xFF276A66),
    'medical_visit' => const Color(0xFF4267B2),
    'expense' => const Color(0xFF8A5A2B),
    _ => const Color(0xFF6D7471),
  };
}

class _HealthInfoPane extends StatelessWidget {
  const _HealthInfoPane({
    super.key,
    required this.busy,
    required this.canEditRecords,
    required this.conditions,
    required this.medications,
    required this.onCreateCondition,
    required this.onUpdateCondition,
    required this.onDeleteCondition,
    required this.onCreateMedication,
    required this.onUpdateMedication,
    required this.onDeleteMedication,
  });

  final bool busy;
  final bool canEditRecords;
  final List<JsonMap> conditions;
  final List<JsonMap> medications;
  final ConditionCreator onCreateCondition;
  final ConditionUpdater onUpdateCondition;
  final Future<void> Function(int conditionId) onDeleteCondition;
  final MedicationCreator onCreateMedication;
  final MedicationUpdater onUpdateMedication;
  final Future<void> Function(int medicationId) onDeleteMedication;

  @override
  Widget build(BuildContext context) {
    final activeConditions = conditions
        .where(
          (item) =>
              item['status'] == 'active' || item['status'] == 'monitoring',
        )
        .length;
    final activeMedications = medications
        .where((item) => item['isActive'] == true)
        .length;

    return Column(
      key: key,
      children: [
        _Section(
          title: '건강정보 요약',
          child: _InlineStats(
            items: [
              _InlineStat('관리 상태', '$activeConditions건'),
              _InlineStat('복용 중', '$activeMedications건'),
              _InlineStat(
                '전체 기록',
                '${conditions.length + medications.length}건',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: '건강 상태',
          trailing: TextButton.icon(
            key: const ValueKey('condition-create-open'),
            onPressed: busy || !canEditRecords
                ? null
                : () => _showConditionEditor(context, null, onCreateCondition),
            icon: const Icon(Icons.add),
            label: const Text('추가'),
          ),
          child: conditions.isEmpty
              ? const _EmptyState(text: '등록된 건강 상태가 없습니다.')
              : Column(
                  children: conditions
                      .map(
                        (condition) => _ConditionTile(
                          condition: condition,
                          onEdit: busy || !canEditRecords
                              ? null
                              : () => _showConditionEditor(
                                  context,
                                  condition,
                                  onCreateCondition,
                                  onUpdate: onUpdateCondition,
                                ),
                          onDelete: busy || !canEditRecords
                              ? null
                              : () => _confirmAndDelete(
                                  context: context,
                                  title: '건강 상태 삭제',
                                  message: '선택한 건강 상태 기록을 삭제할까요?',
                                  id: _asInt(condition['id']),
                                  onDelete: onDeleteCondition,
                                ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: '복약',
          trailing: TextButton.icon(
            key: const ValueKey('medication-create-open'),
            onPressed: busy || !canEditRecords
                ? null
                : () =>
                      _showMedicationEditor(context, null, onCreateMedication),
            icon: const Icon(Icons.add),
            label: const Text('추가'),
          ),
          child: medications.isEmpty
              ? const _EmptyState(text: '등록된 복약 기록이 없습니다.')
              : Column(
                  children: medications
                      .map(
                        (medication) => _MedicationTile(
                          medication: medication,
                          onEdit: busy || !canEditRecords
                              ? null
                              : () => _showMedicationEditor(
                                  context,
                                  medication,
                                  onCreateMedication,
                                  onUpdate: onUpdateMedication,
                                ),
                          onDelete: busy || !canEditRecords
                              ? null
                              : () => _confirmAndDelete(
                                  context: context,
                                  title: '복약 기록 삭제',
                                  message: '선택한 복약 기록을 삭제할까요?',
                                  id: _asInt(medication['id']),
                                  onDelete: onDeleteMedication,
                                ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _ReportsPane extends StatelessWidget {
  const _ReportsPane({
    super.key,
    required this.report,
    required this.visitReports,
    required this.busy,
    required this.canEditRecords,
    required this.forecast,
    required this.fallbackForecast,
    required this.forecastHistory,
    required this.onCreateVisitReport,
    required this.onRecalculateForecast,
  });

  final JsonMap? report;
  final List<JsonMap> visitReports;
  final bool busy;
  final bool canEditRecords;
  final JsonMap? forecast;
  final JsonMap? fallbackForecast;
  final List<JsonMap> forecastHistory;
  final Future<void> Function() onCreateVisitReport;
  final Future<void> Function() onRecalculateForecast;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: [
        VisitReportPanel(
          report: report,
          busy: busy || !canEditRecords,
          onCreate: onCreateVisitReport,
        ),
        const SizedBox(height: 18),
        _Section(
          title: '리포트 이력',
          child: visitReports.isEmpty
              ? const _EmptyState(text: '생성된 리포트 이력이 없습니다.')
              : Column(
                  children: visitReports
                      .map((report) => _VisitReportHistoryTile(report: report))
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _ForecastDetail(
          forecast: forecast,
          fallback: fallbackForecast,
          history: forecastHistory,
          busy: busy || !canEditRecords,
          onRecalculate: onRecalculateForecast,
        ),
      ],
    );
  }
}

class _InlineStat {
  const _InlineStat(this.label, this.value);

  final String label;
  final String value;
}

class _InlineStats extends StatelessWidget {
  const _InlineStats({required this.items});

  final List<_InlineStat> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final statWidgets = items
            .map(
              (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _mutedInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
            .toList();

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < statWidgets.length; index++) ...[
                statWidgets[index],
                if (index != statWidgets.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < statWidgets.length; index++) ...[
              Expanded(child: statWidgets[index]),
              if (index != statWidgets.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _HealthLogTile extends StatelessWidget {
  const _HealthLogTile({
    required this.log,
    this.compact = false,
    this.onEdit,
    this.onDelete,
  });

  final JsonMap log;
  final bool compact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final title =
        log['title'] as String? ?? log['logType'] as String? ?? '건강 기록';
    final memo = log['memo'] as String?;
    final value = _asNum(log['valueNumeric']);
    final valueUnit = log['valueUnit'] as String?;
    final summary = value == null
        ? memo
        : '${value.toString()}${valueUnit ?? ''}';
    final id = _asInt(log['id']);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_heart_outlined),
      title: Text(title),
      subtitle: Text(
        [
          _formatDate(log['recordedAt'] as String?),
          if (!compact && summary != null && summary.isNotEmpty) summary,
        ].join(' · '),
      ),
      trailing: compact || (onEdit == null && onDelete == null)
          ? null
          : _RecordActions(
              editKey: id == null ? null : ValueKey('health-log-edit-$id'),
              deleteKey: id == null ? null : ValueKey('health-log-delete-$id'),
              onEdit: onEdit,
              onDelete: onDelete,
            ),
    );
  }
}

class _MedicalVisitTile extends StatelessWidget {
  const _MedicalVisitTile({
    required this.visit,
    required this.busy,
    required this.onUploadAttachment,
    required this.onDeleteAttachment,
    this.onEdit,
    this.onDelete,
  });

  final JsonMap visit;
  final bool busy;
  final AttachmentUploader onUploadAttachment;
  final Future<void> Function(int attachmentId) onDeleteAttachment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hospitalName = visit['hospitalName'] as String? ?? '병원';
    final diagnosis = visit['diagnosis'] as String?;
    final treatment = visit['treatment'] as String?;
    final prescribedItems = visit['prescribedItems'] as String?;
    final attachments = (visit['attachments'] as List<dynamic>? ?? [])
        .cast<JsonMap>();
    final visitId = _asInt(visit['id']);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 40, right: 4, bottom: 12),
      leading: const Icon(Icons.local_hospital_outlined),
      title: Text(hospitalName),
      subtitle: Text(
        [
          _formatDate(visit['visitDate'] as String?),
          if (visit['visitReason'] is String) visit['visitReason'] as String,
        ].join(' · '),
      ),
      children: [
        _DetailLine(label: '증상', value: visit['symptoms'] as String?),
        _DetailLine(label: '진단', value: diagnosis),
        _DetailLine(label: '처치', value: treatment),
        _DetailLine(label: '처방', value: prescribedItems),
        _DetailLine(
          label: '재방문',
          value: _nullableDate(visit['followUpDate'] as String?),
        ),
        const SizedBox(height: 8),
        _AttachmentList(
          visitId: visitId,
          attachments: attachments,
          busy: busy,
          onUpload: onUploadAttachment,
          onDelete: onDeleteAttachment,
        ),
        if (onEdit != null || onDelete != null)
          Align(
            alignment: Alignment.centerRight,
            child: _RecordActions(
              editKey: _asInt(visit['id']) == null
                  ? null
                  : ValueKey('medical-visit-edit-${_asInt(visit['id'])}'),
              deleteKey: _asInt(visit['id']) == null
                  ? null
                  : ValueKey('medical-visit-delete-${_asInt(visit['id'])}'),
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({
    required this.visitId,
    required this.attachments,
    required this.busy,
    required this.onUpload,
    required this.onDelete,
  });

  final int? visitId;
  final List<JsonMap> attachments;
  final bool busy;
  final AttachmentUploader onUpload;
  final Future<void> Function(int attachmentId) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '첨부파일',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              key: visitId == null
                  ? null
                  : ValueKey('attachment-upload-open-$visitId'),
              onPressed: busy || visitId == null
                  ? null
                  : () => _showAttachmentUploader(
                      context: context,
                      visitId: visitId!,
                      onUpload: onUpload,
                    ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('사진 추가'),
            ),
          ],
        ),
        if (attachments.isEmpty)
          Text(
            '저장된 첨부파일이 없습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D7471)),
          )
        else
          Column(
            children: attachments
                .map(
                  (attachment) => _AttachmentTile(
                    attachment: attachment,
                    busy: busy,
                    onDelete: onDelete,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.busy,
    required this.onDelete,
  });

  final JsonMap attachment;
  final bool busy;
  final Future<void> Function(int attachmentId) onDelete;

  @override
  Widget build(BuildContext context) {
    final id = _asInt(attachment['id']);
    final fileType = attachment['fileType'] as String? ?? 'other';
    final filename = attachment['originalFilename'] as String? ?? '첨부파일';
    final size = _asInt(attachment['fileSizeBytes']);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(_attachmentIcon(fileType)),
      title: Text(filename, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          _attachmentTypeLabel(fileType),
          if (size != null) _fileSizeLabel(size),
          _formatDate(attachment['createdAt'] as String?),
        ].join(' · '),
      ),
      trailing: IconButton(
        key: id == null ? null : ValueKey('attachment-delete-$id'),
        tooltip: '첨부 삭제',
        onPressed: busy || id == null
            ? null
            : () => _confirmAndDelete(
                context: context,
                title: '첨부파일 삭제',
                message: '선택한 첨부파일을 삭제할까요?',
                id: id,
                onDelete: onDelete,
              ),
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, this.onEdit, this.onDelete});

  final JsonMap expense;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final category = expense['expenseCategory'] as String? ?? '지출';
    final amount = _won(expense['amount']);
    final vendor = expense['vendorName'] as String?;
    final id = _asInt(expense['id']);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.payments_outlined),
      title: Text('$category · $amount'),
      subtitle: Text(
        [
          _formatDate(expense['expenseDate'] as String?),
          if (vendor != null && vendor.isNotEmpty) vendor,
        ].join(' · '),
      ),
      trailing: onEdit == null && onDelete == null
          ? null
          : _RecordActions(
              editKey: id == null ? null : ValueKey('expense-edit-$id'),
              deleteKey: id == null ? null : ValueKey('expense-delete-$id'),
              onEdit: onEdit,
              onDelete: onDelete,
            ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.condition, this.onEdit, this.onDelete});

  final JsonMap condition;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final id = _asInt(condition['id']);
    final conditionType = condition['conditionType'] as String? ?? 'other';
    final severity = condition['severity'] as String? ?? 'medium';
    final status = condition['status'] as String? ?? 'active';
    final notes = condition['notes'] as String?;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 40, right: 4, bottom: 12),
      leading: Icon(
        Icons.health_and_safety_outlined,
        color: _conditionSeverityColor(severity),
      ),
      title: Text(condition['conditionName'] as String? ?? '건강 상태'),
      subtitle: Text(
        [
          _conditionTypeLabel(conditionType),
          _conditionSeverityLabel(severity),
          _conditionStatusLabel(status),
          _nullableDate(condition['diagnosedOn'] as String?),
        ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
      ),
      children: [
        _DetailLine(label: '메모', value: notes),
        if (onEdit != null || onDelete != null)
          Align(
            alignment: Alignment.centerRight,
            child: _RecordActions(
              editKey: id == null ? null : ValueKey('condition-edit-$id'),
              deleteKey: id == null ? null : ValueKey('condition-delete-$id'),
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.medication, this.onEdit, this.onDelete});

  final JsonMap medication;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final id = _asInt(medication['id']);
    final isActive = medication['isActive'] == true;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 40, right: 4, bottom: 12),
      leading: Icon(
        Icons.medication_outlined,
        color: isActive ? const Color(0xFF276A66) : const Color(0xFF6D7471),
      ),
      title: Text(medication['medicationName'] as String? ?? '복약'),
      subtitle: Text(
        [
          if ((medication['dosage'] as String? ?? '').isNotEmpty)
            medication['dosage'] as String,
          if ((medication['frequencyText'] as String? ?? '').isNotEmpty)
            medication['frequencyText'] as String,
          isActive ? '복용 중' : '중단',
        ].join(' · '),
      ),
      children: [
        _DetailLine(
          label: '시작',
          value: _nullableDate(medication['startedOn'] as String?),
        ),
        _DetailLine(
          label: '종료',
          value: _nullableDate(medication['endedOn'] as String?),
        ),
        _DetailLine(label: '처방', value: medication['prescribedBy'] as String?),
        _DetailLine(label: '메모', value: medication['notes'] as String?),
        if (onEdit != null || onDelete != null)
          Align(
            alignment: Alignment.centerRight,
            child: _RecordActions(
              editKey: id == null ? null : ValueKey('medication-edit-$id'),
              deleteKey: id == null ? null : ValueKey('medication-delete-$id'),
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

class _RecordActions extends StatelessWidget {
  const _RecordActions({
    this.editKey,
    this.deleteKey,
    this.onEdit,
    this.onDelete,
  });

  final Key? editKey;
  final Key? deleteKey;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: editKey,
          tooltip: '수정',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: deleteKey,
          tooltip: '삭제',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

const _conditionTypeLabels = {
  'allergy': '알레르기',
  'chronic': '만성질환',
  'past_history': '과거병력',
  'risk_factor': '위험요인',
  'other': '기타',
};

const _conditionSeverityLabels = {'low': '낮음', 'medium': '보통', 'high': '높음'};

const _conditionStatusLabels = {
  'active': '관리 중',
  'monitoring': '관찰',
  'resolved': '해결',
};

const _attachmentTypeLabels = {
  'receipt': '영수증',
  'prescription': '처방전',
  'test_result': '검사 결과',
  'image': '사진',
  'other': '기타',
};

String _conditionTypeLabel(String value) =>
    _conditionTypeLabels[value] ?? value;

String _conditionSeverityLabel(String value) =>
    _conditionSeverityLabels[value] ?? value;

String _conditionStatusLabel(String value) =>
    _conditionStatusLabels[value] ?? value;

Color _conditionSeverityColor(String value) {
  return switch (value) {
    'high' => const Color(0xFFE75F45),
    'low' => const Color(0xFF6D7471),
    _ => const Color(0xFF276A66),
  };
}

String _attachmentTypeLabel(String value) =>
    _attachmentTypeLabels[value] ?? value;

IconData _attachmentIcon(String value) {
  return switch (value) {
    'receipt' => Icons.receipt_long_outlined,
    'prescription' => Icons.medication_liquid_outlined,
    'test_result' => Icons.science_outlined,
    'image' => Icons.image_outlined,
    _ => Icons.attach_file,
  };
}

String _fileSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }
  return '${bytes}B';
}

Future<void> _showAttachmentUploader({
  required BuildContext context,
  required int visitId,
  required AttachmentUploader onUpload,
}) async {
  var fileType = 'receipt';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('첨부파일 추가'),
        content: SizedBox(
          width: 420,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('attachment-editor-type'),
            initialValue: fileType,
            decoration: const InputDecoration(labelText: '파일 유형'),
            items: [
              for (final entry in _attachmentTypeLabels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => fileType = value ?? fileType),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            key: const ValueKey('attachment-pick-image'),
            onPressed: () async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              if (!dialogContext.mounted) return;
              final nextFileType = fileType;
              Navigator.of(dialogContext).pop();
              await onUpload(
                visitId: visitId,
                fileType: nextFileType,
                filename: picked.name,
                bytes: bytes,
              );
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('이미지 선택'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showConditionEditor(
  BuildContext context,
  JsonMap? condition,
  ConditionCreator onCreate, {
  ConditionUpdater? onUpdate,
}) async {
  final editing = condition != null;
  final id = _asInt(condition?['id']);
  if (editing && (id == null || onUpdate == null)) return;

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(
    text: _fieldText(condition?['conditionName']),
  );
  final diagnosedOn = TextEditingController(
    text: _dateInput(condition?['diagnosedOn'] as String?),
  );
  final notes = TextEditingController(text: _fieldText(condition?['notes']));
  var conditionType = condition?['conditionType'] as String? ?? 'chronic';
  var severity = condition?['severity'] as String? ?? 'medium';
  var status = condition?['status'] as String? ?? 'active';

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editing ? '건강 상태 수정' : '건강 상태 추가'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('condition-editor-type'),
                      initialValue: conditionType,
                      decoration: const InputDecoration(labelText: '유형'),
                      items: [
                        for (final entry in _conditionTypeLabels.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => conditionType = value ?? conditionType,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('condition-editor-name'),
                      controller: name,
                      decoration: const InputDecoration(labelText: '상태명'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('condition-editor-severity'),
                      initialValue: severity,
                      decoration: const InputDecoration(labelText: '중요도'),
                      items: [
                        for (final entry in _conditionSeverityLabels.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => severity = value ?? severity),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('condition-editor-diagnosed-on'),
                      controller: diagnosedOn,
                      decoration: const InputDecoration(
                        labelText: '진단일 yyyy-mm-dd',
                      ),
                      validator: _optionalDateValidator,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('condition-editor-status'),
                      initialValue: status,
                      decoration: const InputDecoration(labelText: '상태'),
                      items: [
                        for (final entry in _conditionStatusLabels.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('condition-editor-notes'),
                      controller: notes,
                      decoration: const InputDecoration(labelText: '메모'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              key: const ValueKey('condition-editor-save'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final nextConditionType = conditionType;
                final nextConditionName = name.text.trim();
                final nextSeverity = severity;
                final nextDiagnosedOn = diagnosedOn.text.trim();
                final nextStatus = status;
                final nextNotes = notes.text.trim();
                Navigator.of(dialogContext).pop();
                if (editing) {
                  await onUpdate!(
                    conditionId: id!,
                    conditionType: nextConditionType,
                    conditionName: nextConditionName,
                    severity: nextSeverity,
                    diagnosedOn: nextDiagnosedOn,
                    status: nextStatus,
                    notes: nextNotes,
                  );
                } else {
                  await onCreate(
                    conditionType: nextConditionType,
                    conditionName: nextConditionName,
                    severity: nextSeverity,
                    diagnosedOn: nextDiagnosedOn,
                    status: nextStatus,
                    notes: nextNotes,
                  );
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  } finally {
    await _disposeDialogControllers([name, diagnosedOn, notes]);
  }
}

Future<void> _showMedicationEditor(
  BuildContext context,
  JsonMap? medication,
  MedicationCreator onCreate, {
  MedicationUpdater? onUpdate,
}) async {
  final editing = medication != null;
  final id = _asInt(medication?['id']);
  if (editing && (id == null || onUpdate == null)) return;

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(
    text: _fieldText(medication?['medicationName']),
  );
  final dosage = TextEditingController(text: _fieldText(medication?['dosage']));
  final frequency = TextEditingController(
    text: _fieldText(medication?['frequencyText']),
  );
  final startedOn = TextEditingController(
    text: _dateInput(medication?['startedOn'] as String?),
  );
  final endedOn = TextEditingController(
    text: _dateInput(medication?['endedOn'] as String?),
  );
  final prescribedBy = TextEditingController(
    text: _fieldText(medication?['prescribedBy']),
  );
  final notes = TextEditingController(text: _fieldText(medication?['notes']));
  var isActive = medication?['isActive'] as bool? ?? true;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editing ? '복약 수정' : '복약 추가'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey('medication-editor-name'),
                      controller: name,
                      decoration: const InputDecoration(labelText: '약 이름'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('medication-editor-dosage'),
                      controller: dosage,
                      decoration: const InputDecoration(labelText: '용량'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('medication-editor-frequency'),
                      controller: frequency,
                      decoration: const InputDecoration(labelText: '복용 주기'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('medication-editor-started-on'),
                            controller: startedOn,
                            decoration: const InputDecoration(
                              labelText: '시작일 yyyy-mm-dd',
                            ),
                            validator: _optionalDateValidator,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('medication-editor-ended-on'),
                            controller: endedOn,
                            decoration: const InputDecoration(
                              labelText: '종료일 yyyy-mm-dd',
                            ),
                            validator: _optionalDateValidator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('medication-editor-prescribed-by'),
                      controller: prescribedBy,
                      decoration: const InputDecoration(labelText: '처방 병원'),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      key: const ValueKey('medication-editor-active'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('복용 중'),
                      value: isActive,
                      onChanged: (value) => setState(() => isActive = value),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const ValueKey('medication-editor-notes'),
                      controller: notes,
                      decoration: const InputDecoration(labelText: '메모'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              key: const ValueKey('medication-editor-save'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final nextMedicationName = name.text.trim();
                final nextDosage = dosage.text.trim();
                final nextFrequency = frequency.text.trim();
                final nextStartedOn = startedOn.text.trim();
                final nextEndedOn = endedOn.text.trim();
                final nextPrescribedBy = prescribedBy.text.trim();
                final nextIsActive = isActive;
                final nextNotes = notes.text.trim();
                Navigator.of(dialogContext).pop();
                if (editing) {
                  await onUpdate!(
                    medicationId: id!,
                    medicationName: nextMedicationName,
                    dosage: nextDosage,
                    frequencyText: nextFrequency,
                    startedOn: nextStartedOn,
                    endedOn: nextEndedOn,
                    prescribedBy: nextPrescribedBy,
                    isActive: nextIsActive,
                    notes: nextNotes,
                  );
                } else {
                  await onCreate(
                    medicationName: nextMedicationName,
                    dosage: nextDosage,
                    frequencyText: nextFrequency,
                    startedOn: nextStartedOn,
                    endedOn: nextEndedOn,
                    prescribedBy: nextPrescribedBy,
                    isActive: nextIsActive,
                    notes: nextNotes,
                  );
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  } finally {
    await _disposeDialogControllers([
      name,
      dosage,
      frequency,
      startedOn,
      endedOn,
      prescribedBy,
      notes,
    ]);
  }
}

Future<void> _showHealthLogEditor(
  BuildContext context,
  JsonMap log,
  HealthLogUpdater onSubmit,
) async {
  final id = _asInt(log['id']);
  if (id == null) return;
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(text: _fieldText(log['title']));
  final value = TextEditingController(text: _fieldText(log['valueNumeric']));
  final unit = TextEditingController(text: _fieldText(log['valueUnit']));
  final memo = TextEditingController(text: _fieldText(log['memo']));
  final logTypeLabels = const {
    'appetite': '식욕',
    'stool': '배변',
    'weight': '체중',
    'symptom': '증상',
  };
  var type = log['logType'] as String? ?? 'appetite';

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('건강 기록 수정'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: '기록 유형'),
                      items: [
                        for (final entry in logTypeLabels.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        if (!logTypeLabels.containsKey(type))
                          DropdownMenuItem(value: type, child: Text(type)),
                      ],
                      onChanged: (value) =>
                          setState(() => type = value ?? type),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('health-editor-title'),
                      controller: title,
                      decoration: const InputDecoration(labelText: '제목'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('health-editor-value'),
                            controller: value,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '수치'),
                            validator: (input) {
                              final text = input?.trim() ?? '';
                              if (text.isEmpty) return null;
                              return num.tryParse(text) == null
                                  ? '숫자로 입력하세요.'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('health-editor-unit'),
                            controller: unit,
                            decoration: const InputDecoration(labelText: '단위'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('health-editor-memo'),
                      controller: memo,
                      decoration: const InputDecoration(labelText: '메모'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              key: const ValueKey('health-editor-save'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final nextLogType = type;
                final nextTitle = title.text.trim();
                final nextMemo = memo.text.trim();
                final nextValue = num.tryParse(value.text.trim());
                final nextUnit = unit.text.trim();
                Navigator.of(dialogContext).pop();
                await onSubmit(
                  logId: id,
                  logType: nextLogType,
                  title: nextTitle,
                  memo: nextMemo,
                  valueNumeric: nextValue,
                  valueUnit: nextUnit,
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  } finally {
    await _disposeDialogControllers([title, value, unit, memo]);
  }
}

Future<void> _showExpenseEditor(
  BuildContext context,
  JsonMap expense,
  ExpenseUpdater onSubmit,
) async {
  final id = _asInt(expense['id']);
  if (id == null) return;
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(text: _fieldText(expense['amount']));
  final date = TextEditingController(
    text: _dateInput(expense['expenseDate'] as String?),
  );
  final vendor = TextEditingController(text: _fieldText(expense['vendorName']));
  final memo = TextEditingController(text: _fieldText(expense['memo']));
  final categoryLabels = const {
    'hospital': '병원',
    'food': '사료',
    'snack': '간식',
    'grooming': '미용',
    'supplies': '용품',
    'insurance': '보험',
  };
  var category = expense['expenseCategory'] as String? ?? 'hospital';

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('지출 수정'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: '분류'),
                      items: [
                        for (final entry in categoryLabels.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        if (!categoryLabels.containsKey(category))
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('expense-editor-amount'),
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '금액'),
                      validator: (input) =>
                          num.tryParse(input?.trim() ?? '') == null
                          ? '숫자로 입력하세요.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('expense-editor-date'),
                      controller: date,
                      decoration: const InputDecoration(
                        labelText: '지출일 yyyy-mm-dd',
                      ),
                      validator: (input) {
                        final text = input?.trim() ?? '';
                        if (text.isEmpty) return null;
                        return DateTime.tryParse(text) == null
                            ? '날짜 형식이 필요합니다.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('expense-editor-vendor'),
                      controller: vendor,
                      decoration: const InputDecoration(labelText: '사용처'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('expense-editor-memo'),
                      controller: memo,
                      decoration: const InputDecoration(labelText: '메모'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              key: const ValueKey('expense-editor-save'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final nextCategory = category;
                final nextAmount = num.parse(amount.text.trim());
                final nextDate = date.text.trim();
                final nextVendor = vendor.text.trim();
                final nextMemo = memo.text.trim();
                Navigator.of(dialogContext).pop();
                await onSubmit(
                  expenseId: id,
                  category: nextCategory,
                  amount: nextAmount,
                  expenseDate: nextDate,
                  vendorName: nextVendor,
                  memo: nextMemo,
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  } finally {
    await _disposeDialogControllers([amount, date, vendor, memo]);
  }
}

Future<void> _showMedicalVisitEditor(
  BuildContext context,
  JsonMap visit,
  MedicalVisitUpdater onSubmit,
) async {
  final id = _asInt(visit['id']);
  if (id == null) return;
  final formKey = GlobalKey<FormState>();
  final hospital = TextEditingController(
    text: _fieldText(visit['hospitalName']),
  );
  final reason = TextEditingController(text: _fieldText(visit['visitReason']));
  final symptoms = TextEditingController(text: _fieldText(visit['symptoms']));
  final diagnosis = TextEditingController(text: _fieldText(visit['diagnosis']));
  final treatment = TextEditingController(text: _fieldText(visit['treatment']));
  final prescribedItems = TextEditingController(
    text: _fieldText(visit['prescribedItems']),
  );
  final followUpDate = TextEditingController(
    text: _dateInput(visit['followUpDate'] as String?),
  );
  final notes = TextEditingController(text: _fieldText(visit['notes']));

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('병원 방문 수정'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-hospital'),
                    controller: hospital,
                    decoration: const InputDecoration(labelText: '병원명'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-reason'),
                    controller: reason,
                    decoration: const InputDecoration(labelText: '방문 사유'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-symptoms'),
                    controller: symptoms,
                    decoration: const InputDecoration(labelText: '증상'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-diagnosis'),
                    controller: diagnosis,
                    decoration: const InputDecoration(labelText: '진단/소견'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-treatment'),
                    controller: treatment,
                    decoration: const InputDecoration(labelText: '처치/치료'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-prescribed'),
                    controller: prescribedItems,
                    decoration: const InputDecoration(labelText: '처방/복약'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-follow-up-date'),
                    controller: followUpDate,
                    decoration: const InputDecoration(
                      labelText: '재방문일 yyyy-mm-dd',
                    ),
                    validator: (input) {
                      final text = input?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return DateTime.tryParse(text) == null
                          ? '날짜 형식이 필요합니다.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('medical-visit-editor-notes'),
                    controller: notes,
                    decoration: const InputDecoration(labelText: '메모'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            key: const ValueKey('medical-visit-editor-save'),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nextHospital = hospital.text.trim();
              final nextReason = reason.text.trim();
              final nextSymptoms = symptoms.text.trim();
              final nextDiagnosis = diagnosis.text.trim();
              final nextTreatment = treatment.text.trim();
              final nextPrescribedItems = prescribedItems.text.trim();
              final nextFollowUpDate = followUpDate.text.trim();
              final nextNotes = notes.text.trim();
              Navigator.of(dialogContext).pop();
              await onSubmit(
                visitId: id,
                hospitalName: nextHospital,
                visitReason: nextReason,
                symptoms: nextSymptoms,
                diagnosis: nextDiagnosis,
                treatment: nextTreatment,
                prescribedItems: nextPrescribedItems,
                followUpDate: nextFollowUpDate,
                notes: nextNotes,
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('저장'),
          ),
        ],
      ),
    );
  } finally {
    await _disposeDialogControllers([
      hospital,
      reason,
      symptoms,
      diagnosis,
      treatment,
      prescribedItems,
      followUpDate,
      notes,
    ]);
  }
}

Future<void> _confirmAndDelete({
  required BuildContext context,
  required String title,
  required String message,
  required int? id,
  required Future<void> Function(int id) onDelete,
}) async {
  if (id == null) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          key: const ValueKey('confirm-delete-button'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await onDelete(id);
  }
}

Future<void> _showFamilySharingDialog({
  required BuildContext context,
  required JsonMap dog,
  required Future<JsonMap> Function() loadMe,
  required DogMembersLoader loadMembers,
  required DogMemberAdder addMember,
  required DogMembershipUpdater updateMembership,
  required DogMembershipRemover removeMembership,
}) async {
  final dogId = _asInt(dog['id']);
  if (dogId == null) return;

  final email = TextEditingController();
  var newRole = 'viewer';
  var busy = false;
  String? errorText;

  Future<JsonMap> loadState() async {
    final results = await Future.wait<dynamic>([loadMe(), loadMembers(dogId)]);
    return {
      'me': results[0] as JsonMap,
      'members': results[1] as List<JsonMap>,
    };
  }

  var stateFuture = loadState();

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> refresh() async {
            setState(() {
              errorText = null;
              stateFuture = loadState();
            });
          }

          Future<void> runMemberAction(Future<void> Function() action) async {
            setState(() {
              busy = true;
              errorText = null;
            });
            try {
              await action();
              await refresh();
            } on ApiException catch (error) {
              setState(() => errorText = error.message);
            } catch (error) {
              setState(() => errorText = error.toString());
            } finally {
              setState(() => busy = false);
            }
          }

          return AlertDialog(
            title: const Text('가족 공유'),
            content: SizedBox(
              width: 560,
              child: FutureBuilder<JsonMap>(
                future: stateFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      '가족 공유 정보를 불러오지 못했습니다: ${snapshot.error}',
                      style: const TextStyle(color: _coral),
                    );
                  }

                  final me = snapshot.data?['me'] as JsonMap? ?? {};
                  final members =
                      (snapshot.data?['members'] as List<JsonMap>? ?? []);
                  final myId = _asInt(me['id']);
                  final canManage = members.any((member) {
                    final user = member['user'] as JsonMap?;
                    return _asInt(user?['id']) == myId &&
                        member['role'] == 'owner' &&
                        member['status'] == 'active';
                  });

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        dog['name'] == null
                            ? '함께 관리할 가족을 설정합니다.'
                            : '${dog['name']}를 함께 관리할 가족을 설정합니다.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (canManage) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('member-email-input'),
                                controller: email,
                                enabled: !busy,
                                decoration: const InputDecoration(
                                  labelText: '가입된 가족 이메일',
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 130,
                              child: DropdownButtonFormField<String>(
                                key: const ValueKey('member-role-input'),
                                initialValue: newRole,
                                decoration: const InputDecoration(
                                  labelText: '역할',
                                ),
                                items: _membershipRoleItems(),
                                onChanged: busy
                                    ? null
                                    : (value) => setState(
                                        () => newRole = value ?? newRole,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: IconButton.filled(
                                key: const ValueKey('member-add-button'),
                                tooltip: '가족 추가',
                                onPressed: busy || email.text.trim().isEmpty
                                    ? null
                                    : () => runMemberAction(() async {
                                        await addMember(
                                          dogId: dogId,
                                          email: email.text.trim(),
                                          role: newRole,
                                        );
                                        email.clear();
                                      }),
                                icon: const Icon(Icons.person_add_alt_1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ] else
                        const Text('공유 멤버 관리는 보호자 권한이 필요합니다.'),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: const TextStyle(color: _coral),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: members.length,
                          separatorBuilder: (_, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final user = member['user'] as JsonMap? ?? {};
                            final membershipId = _asInt(member['id']);
                            final isMe = _asInt(user['id']) == myId;
                            final role = member['role'] as String? ?? 'viewer';
                            final canEditThis =
                                canManage &&
                                membershipId != null &&
                                !(isMe && role == 'owner');

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: _teal.withValues(alpha: 0.1),
                                foregroundColor: _teal,
                                child: const Icon(Icons.person_outline),
                              ),
                              title: Text(
                                user['name'] as String? ??
                                    user['email'] as String? ??
                                    '가족',
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                [
                                  if (user['email'] is String)
                                    user['email'] as String,
                                  if (isMe) '나',
                                ].join(' · '),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 112,
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: role,
                                        items: _membershipRoleItems(),
                                        onChanged: canEditThis && !busy
                                            ? (value) {
                                                if (value == null ||
                                                    value == role) {
                                                  return;
                                                }
                                                runMemberAction(() async {
                                                  await updateMembership(
                                                    membershipId: membershipId,
                                                    role: value,
                                                  );
                                                });
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '멤버 제거',
                                    onPressed: canEditThis && !busy
                                        ? () => runMemberAction(() async {
                                            await removeMembership(
                                              membershipId,
                                            );
                                          })
                                        : null,
                                    icon: const Icon(Icons.person_remove_alt_1),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    email.dispose();
  }
}

Future<void> _showDogDeleteConfirmation({
  required BuildContext context,
  required JsonMap dog,
  required DogDeletePreviewLoader loadPreview,
  required DogDeleter onDelete,
}) async {
  final dogId = _asInt(dog['id']);
  if (dogId == null) return;

  final dogName = dog['name'] as String? ?? '반려견';
  final confirmation = TextEditingController();
  final previewFuture = loadPreview(dogId);

  try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('반려견 삭제'),
          content: SizedBox(
            width: 460,
            child: FutureBuilder<JsonMap>(
              future: previewFuture,
              builder: (context, snapshot) {
                final preview = snapshot.data;
                final counts = preview?['counts'] as JsonMap?;
                final attachmentBytes =
                    _asNum(preview?['attachmentBytes']) ?? 0;
                final canDelete =
                    snapshot.hasData && confirmation.text.trim() == dogName;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dogName 프로필과 연결된 데이터를 모두 삭제합니다.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '가족 공유가 추가되면 이 전체 삭제는 주 보호자만 실행할 수 있고, 가족 구성원은 별도의 공유 해제 기능을 사용하게 됩니다.',
                    ),
                    const SizedBox(height: 14),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Center(child: CircularProgressIndicator())
                    else if (snapshot.hasError)
                      Text(
                        '삭제 범위를 불러오지 못했습니다: ${snapshot.error}',
                        style: const TextStyle(color: _coral),
                      )
                    else ...[
                      _DeletePreviewRow(
                        label: '일정',
                        count: _asInt(counts?['schedules']) ?? 0,
                      ),
                      _DeletePreviewRow(
                        label: '건강 상태',
                        count: _asInt(counts?['conditions']) ?? 0,
                      ),
                      _DeletePreviewRow(
                        label: '복약',
                        count: _asInt(counts?['medications']) ?? 0,
                      ),
                      _DeletePreviewRow(
                        label: '건강 기록',
                        count: _asInt(counts?['healthLogs']) ?? 0,
                      ),
                      _DeletePreviewRow(
                        label: '병원 방문',
                        count: _asInt(counts?['medicalVisits']) ?? 0,
                      ),
                      _DeletePreviewRow(
                        label: '지출',
                        count: _asInt(counts?['expenses']) ?? 0,
                      ),
                      _DeletePreviewRow(
                        label: '리포트',
                        count: _asInt(counts?['visitReports']) ?? 0,
                      ),
                      _DeletePreviewRow(
                        label: '첨부파일',
                        count: _asInt(counts?['attachments']) ?? 0,
                        suffix: attachmentBytes > 0
                            ? ' · ${_formatBytes(attachmentBytes)}'
                            : '',
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('dog-delete-confirm-name'),
                      controller: confirmation,
                      decoration: InputDecoration(
                        labelText: '삭제 확인을 위해 "$dogName" 입력',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const ValueKey('dog-delete-confirm-button'),
                      onPressed: canDelete
                          ? () => Navigator.of(dialogContext).pop(true)
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('영구 삭제'),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await onDelete(dogId);
    }
  } finally {
    confirmation.dispose();
  }
}

class _DeletePreviewRow extends StatelessWidget {
  const _DeletePreviewRow({
    required this.label,
    required this.count,
    this.suffix = '',
  });

  final String label;
  final int count;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '$count개$suffix',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

List<DropdownMenuItem<String>> _membershipRoleItems() {
  return const [
    DropdownMenuItem(value: 'viewer', child: Text('보기')),
    DropdownMenuItem(value: 'editor', child: Text('편집')),
    DropdownMenuItem(value: 'owner', child: Text('보호자')),
  ];
}

class _VisitReportHistoryTile extends StatelessWidget {
  const _VisitReportHistoryTile({required this.report});

  final JsonMap report;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(report['title'] as String? ?? '방문 리포트'),
      subtitle: Text(_formatDate(report['generatedAt'] as String?)),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6D7471),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}

class _DogSelector extends StatelessWidget {
  const _DogSelector({
    required this.dogs,
    required this.selectedDogId,
    required this.enabled,
    required this.onChanged,
  });

  final List<JsonMap> dogs;
  final int? selectedDogId;
  final bool enabled;
  final Future<void> Function(int dogId) onChanged;

  @override
  Widget build(BuildContext context) {
    if (dogs.length <= 1) {
      final dog = dogs.isEmpty ? null : dogs.first;
      return Text(
        dog?['name'] as String? ?? '반려견',
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5C615F)),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        isExpanded: true,
        value: selectedDogId,
        borderRadius: BorderRadius.circular(8),
        items: dogs
            .map(
              (dog) => DropdownMenuItem<int>(
                value: _asInt(dog['id']),
                child: Text(
                  dog['name'] as String? ?? '반려견',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .where((item) => item.value != null)
            .toList(),
        onChanged: enabled
            ? (value) {
                if (value != null && value != selectedDogId) {
                  onChanged(value);
                }
              }
            : null,
      ),
    );
  }
}

Future<void> _showDogProfileEditor(
  BuildContext context,
  JsonMap dog,
  DogUpdater onSubmit,
) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: _fieldText(dog['name']));
  final breed = TextEditingController(text: _fieldText(dog['breed']));
  final birthDate = TextEditingController(
    text: _dateInput(dog['birthDate'] as String?),
  );
  final currentWeight = TextEditingController(
    text: _fieldText(dog['currentWeightKg']),
  );
  final targetWeight = TextEditingController(
    text: _fieldText(dog['targetWeightKg']),
  );
  final notes = TextEditingController(text: _fieldText(dog['notes']));
  var sex = dog['sex'] as String? ?? 'female';
  var activityLevel = dog['activityLevel'] as String? ?? 'medium';
  var insuranceStatus = dog['insuranceStatus'] as String? ?? 'none';
  var neutered = dog['neutered'] == true;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('프로필 수정'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey('dog-editor-name'),
                      controller: name,
                      decoration: const InputDecoration(labelText: '이름'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('dog-editor-breed'),
                      controller: breed,
                      decoration: const InputDecoration(labelText: '견종'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('dog-editor-birth-date'),
                      controller: birthDate,
                      decoration: const InputDecoration(
                        labelText: '생일 yyyy-mm-dd',
                      ),
                      validator: (input) {
                        final text = input?.trim() ?? '';
                        if (text.isEmpty) return null;
                        return DateTime.tryParse(text) == null
                            ? '날짜 형식이 필요합니다.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dog-editor-sex'),
                      initialValue: sex,
                      decoration: const InputDecoration(labelText: '성별'),
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('암컷')),
                        DropdownMenuItem(value: 'male', child: Text('수컷')),
                      ],
                      onChanged: (value) => setState(() => sex = value ?? sex),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      key: const ValueKey('dog-editor-neutered'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('중성화 완료'),
                      value: neutered,
                      onChanged: (value) => setState(() => neutered = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('dog-editor-current-weight'),
                            controller: currentWeight,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '현재 체중 kg',
                            ),
                            validator: _optionalNumberValidator,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('dog-editor-target-weight'),
                            controller: targetWeight,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '목표 체중 kg',
                            ),
                            validator: _optionalNumberValidator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dog-editor-activity'),
                      initialValue: activityLevel,
                      decoration: const InputDecoration(labelText: '활동량'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('낮음')),
                        DropdownMenuItem(value: 'medium', child: Text('보통')),
                        DropdownMenuItem(value: 'high', child: Text('높음')),
                      ],
                      onChanged: (value) => setState(
                        () => activityLevel = value ?? activityLevel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dog-editor-insurance'),
                      initialValue: insuranceStatus,
                      decoration: const InputDecoration(labelText: '보험 상태'),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('없음')),
                        DropdownMenuItem(value: 'enrolled', child: Text('가입')),
                        DropdownMenuItem(
                          value: 'reviewing',
                          child: Text('검토 중'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => insuranceStatus = value ?? insuranceStatus,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('dog-editor-notes'),
                      controller: notes,
                      decoration: const InputDecoration(labelText: '메모'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              key: const ValueKey('dog-editor-save'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final payload = <String, dynamic>{
                  'name': name.text.trim(),
                  'breed': breed.text.trim(),
                  'sex': sex,
                  'neutered': neutered,
                  'activityLevel': activityLevel,
                  'insuranceStatus': insuranceStatus,
                  'notes': notes.text.trim(),
                  if (birthDate.text.trim().isNotEmpty)
                    'birthDate': birthDate.text.trim(),
                  if (num.tryParse(currentWeight.text.trim()) != null)
                    'currentWeightKg': num.parse(currentWeight.text.trim()),
                  if (num.tryParse(targetWeight.text.trim()) != null)
                    'targetWeightKg': num.parse(targetWeight.text.trim()),
                };
                Navigator.of(dialogContext).pop();
                await onSubmit(payload);
              },
              icon: const Icon(Icons.check),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  } finally {
    await _disposeDialogControllers([
      name,
      breed,
      birthDate,
      currentWeight,
      targetWeight,
      notes,
    ]);
  }
}

Future<void> _showScheduleEditor(
  BuildContext context,
  JsonMap? schedule,
  ScheduleCreator onCreate, {
  ScheduleUpdater? onUpdate,
}) async {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(text: _fieldText(schedule?['title']));
  final dueDate = TextEditingController(
    text: _dateInput(schedule?['dueDate'] as String?),
  );
  final description = TextEditingController(
    text: _fieldText(schedule?['description']),
  );
  final repeatCycleDays = TextEditingController(
    text: _fieldText(schedule?['repeatCycleDays']),
  );
  var scheduleType = schedule?['scheduleType'] as String? ?? 'checkup';
  var priority = schedule?['priority'] as String? ?? 'medium';
  var reminderEnabled = schedule?['reminderEnabled'] != false;
  final scheduleId = _asInt(schedule?['id']);
  final editing = scheduleId != null;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editing ? '일정 수정' : '일정 추가'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!editing) ...[
                      DropdownButtonFormField<String>(
                        key: const ValueKey('schedule-editor-type'),
                        initialValue: scheduleType,
                        decoration: const InputDecoration(labelText: '일정 유형'),
                        items: const [
                          DropdownMenuItem(value: 'checkup', child: Text('검진')),
                          DropdownMenuItem(
                            value: 'heartworm',
                            child: Text('심장사상충'),
                          ),
                          DropdownMenuItem(
                            value: 'vaccine',
                            child: Text('예방접종'),
                          ),
                          DropdownMenuItem(
                            value: 'grooming',
                            child: Text('미용/위생'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('직접 입력'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => scheduleType = value ?? scheduleType,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const ValueKey('schedule-editor-title'),
                      controller: title,
                      decoration: const InputDecoration(labelText: '제목'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('schedule-editor-due-date'),
                      controller: dueDate,
                      decoration: const InputDecoration(
                        labelText: '예정일 yyyy-mm-dd',
                      ),
                      validator: (input) {
                        final text = input?.trim() ?? '';
                        if (text.isEmpty) return '필수 입력입니다.';
                        return DateTime.tryParse(text) == null
                            ? '날짜 형식이 필요합니다.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('schedule-editor-priority'),
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: '우선순위'),
                      items: const [
                        DropdownMenuItem(value: 'high', child: Text('높음')),
                        DropdownMenuItem(value: 'medium', child: Text('보통')),
                        DropdownMenuItem(value: 'low', child: Text('낮음')),
                      ],
                      onChanged: (value) =>
                          setState(() => priority = value ?? priority),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('schedule-editor-description'),
                      controller: description,
                      decoration: const InputDecoration(labelText: '설명'),
                      maxLines: 2,
                    ),
                    if (!editing) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('schedule-editor-repeat-days'),
                        controller: repeatCycleDays,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '반복 주기 일수 선택 입력',
                        ),
                        validator: _optionalIntValidator,
                      ),
                    ],
                    if (editing) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        key: const ValueKey('schedule-editor-reminder'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('로컬 알림 예약'),
                        value: reminderEnabled,
                        onChanged: (value) =>
                            setState(() => reminderEnabled = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              key: const ValueKey('schedule-editor-save'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final nextTitle = title.text.trim();
                final nextDueDate = dueDate.text.trim();
                final nextDescription = description.text.trim();
                final nextPriority = priority;
                final nextReminderEnabled = reminderEnabled;
                final nextScheduleType = scheduleType;
                final nextRepeatCycleDays = int.tryParse(
                  repeatCycleDays.text.trim(),
                );
                Navigator.of(dialogContext).pop();
                if (editing) {
                  await onUpdate!(
                    scheduleId: scheduleId,
                    title: nextTitle,
                    dueDate: nextDueDate,
                    description: nextDescription,
                    priority: nextPriority,
                    reminderEnabled: nextReminderEnabled,
                  );
                } else {
                  await onCreate(
                    scheduleType: nextScheduleType,
                    title: nextTitle,
                    dueDate: nextDueDate,
                    description: nextDescription,
                    priority: nextPriority,
                    repeatCycleDays: nextRepeatCycleDays,
                  );
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  } finally {
    await _disposeDialogControllers([
      title,
      dueDate,
      description,
      repeatCycleDays,
    ]);
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.dog,
    required this.dogName,
    required this.breed,
    required this.busy,
    required this.canManageDog,
    required this.onEditDog,
    required this.onLoadDeletePreview,
    required this.onDeleteDog,
    required this.onLoadMe,
    required this.onLoadMembers,
    required this.onAddMember,
    required this.onUpdateMembership,
    required this.onRemoveMembership,
    required this.onCreateReport,
  });

  final JsonMap? dog;
  final String dogName;
  final String breed;
  final bool busy;
  final bool canManageDog;
  final DogUpdater onEditDog;
  final DogDeletePreviewLoader onLoadDeletePreview;
  final DogDeleter onDeleteDog;
  final Future<JsonMap> Function() onLoadMe;
  final DogMembersLoader onLoadMembers;
  final DogMemberAdder onAddMember;
  final DogMembershipUpdater onUpdateMembership;
  final DogMembershipRemover onRemoveMembership;
  final VoidCallback? onCreateReport;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (breed.isNotEmpty) breed,
      if (_asNum(dog?['currentWeightKg']) != null)
        '${_asNum(dog?['currentWeightKg'])}kg',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dogName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle.isEmpty ? '관리 중인 반려견' : subtitle.join(' · '),
              style: const TextStyle(color: Color(0xFFC8D7D3), fontSize: 15),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            IconButton.filledTonal(
              key: const ValueKey('dog-profile-edit-open'),
              tooltip: canManageDog ? '프로필 수정' : '보호자만 수정 가능',
              onPressed: busy || dog == null || !canManageDog
                  ? null
                  : () => _showDogProfileEditor(context, dog!, onEditDog),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton.filledTonal(
              key: const ValueKey('family-sharing-open'),
              tooltip: '가족 공유',
              onPressed: busy || dog == null
                  ? null
                  : () => _showFamilySharingDialog(
                    context: context,
                    dog: dog!,
                    loadMe: onLoadMe,
                    loadMembers: onLoadMembers,
                    addMember: onAddMember,
                    updateMembership: onUpdateMembership,
                    removeMembership: onRemoveMembership,
                  ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              icon: const Icon(Icons.group_outlined),
            ),
            IconButton.filledTonal(
              key: const ValueKey('dog-delete-open'),
              tooltip: canManageDog ? '반려견 삭제' : '보호자만 삭제 가능',
              onPressed: busy || dog == null || !canManageDog
                  ? null
                  : () => _showDogDeleteConfirmation(
                    context: context,
                    dog: dog!,
                    loadPreview: onLoadDeletePreview,
                    onDelete: onDeleteDog,
                  ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              icon: const Icon(Icons.delete_outline),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              onPressed: onCreateReport,
              icon: const Icon(Icons.description_outlined),
              label: const Text('리포트'),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.all(compact ? 18 : 22),
          decoration: BoxDecoration(
            color: _deepTeal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroBandMark(compact: compact),
                    const SizedBox(height: 16),
                    details,
                    const SizedBox(height: 18),
                    actions,
                  ],
                )
              : Row(
                  children: [
                    _HeroBandMark(compact: compact),
                    const SizedBox(width: 18),
                    Expanded(child: details),
                    const SizedBox(width: 18),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}

class _HeroBandMark extends StatelessWidget {
  const _HeroBandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 48 : 58,
      height: compact ? 48 : 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Icon(Icons.pets, color: _gold),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.onComplete,
    required this.onEdit,
    required this.onSkip,
  });

  final JsonMap schedule;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final priority = schedule['priority'] as String? ?? 'medium';
    final color = switch (priority) {
      'high' => const Color(0xFFE75F45),
      'low' => const Color(0xFF6D7471),
      _ => const Color(0xFF276A66),
    };
    final id = _asInt(schedule['id']);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          schedule['title'] as String? ?? '일정',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          [
            _formatDate(schedule['dueDate'] as String?),
            if (schedule['description'] is String &&
                (schedule['description'] as String).isNotEmpty)
              schedule['description'] as String,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: _mutedInk, height: 1.25),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: id == null ? null : ValueKey('schedule-edit-$id'),
          tooltip: '일정 수정',
          onPressed: onEdit,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_calendar_outlined),
        ),
        IconButton(
          key: id == null ? null : ValueKey('schedule-skip-$id'),
          tooltip: '건너뛰기',
          onPressed: onSkip,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.skip_next_outlined),
        ),
        IconButton.filledTonal(
          key: id == null ? null : ValueKey('schedule-complete-$id'),
          tooltip: '완료',
          onPressed: onComplete,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.check),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: compact ? 76 : 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          body,
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: actions,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: body),
                          const SizedBox(width: 8),
                          actions,
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              first,
              SizedBox(height: spacing),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class QuickHealthLogPanel extends StatefulWidget {
  const QuickHealthLogPanel({
    super.key,
    required this.busy,
    required this.onSubmit,
  });

  final bool busy;
  final Future<void> Function({
    required String logType,
    required String title,
    required String memo,
    num? valueNumeric,
    String? valueUnit,
  })
  onSubmit;

  @override
  State<QuickHealthLogPanel> createState() => _QuickHealthLogPanelState();
}

class _QuickHealthLogPanelState extends State<QuickHealthLogPanel> {
  final _title = TextEditingController(text: '식욕 정상');
  final _memo = TextEditingController();
  final _value = TextEditingController();
  String _type = 'appetite';

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSubmit(
      logType: _type,
      title: _title.text.trim(),
      memo: _memo.text.trim(),
      valueNumeric: num.tryParse(_value.text.trim()),
      valueUnit: _type == 'weight' ? 'kg' : null,
    );
    _memo.clear();
    _value.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '건강 기록 추가',
      child: Column(
        children: [
          _ResponsivePair(
            first: DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '기록 유형'),
              items: const [
                DropdownMenuItem(value: 'appetite', child: Text('식욕')),
                DropdownMenuItem(value: 'stool', child: Text('배변')),
                DropdownMenuItem(value: 'weight', child: Text('체중')),
                DropdownMenuItem(value: 'symptom', child: Text('증상')),
              ],
              onChanged: widget.busy
                  ? null
                  : (value) => setState(() => _type = value ?? _type),
            ),
            second: TextField(
              key: const ValueKey('quick-health-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: '제목'),
            ),
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            first: TextField(
              key: const ValueKey('quick-health-value'),
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '수치 선택 입력'),
            ),
            second: TextField(
              key: const ValueKey('quick-health-memo'),
              controller: _memo,
              decoration: const InputDecoration(labelText: '메모'),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('quick-health-submit'),
              onPressed: widget.busy ? null : _submit,
              icon: const Icon(Icons.add),
              label: const Text('기록 저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickExpensePanel extends StatefulWidget {
  const QuickExpensePanel({
    super.key,
    required this.busy,
    required this.onSubmit,
  });

  final bool busy;
  final Future<void> Function({
    required String category,
    required num amount,
    required String vendorName,
    required String memo,
  })
  onSubmit;

  @override
  State<QuickExpensePanel> createState() => _QuickExpensePanelState();
}

class _QuickExpensePanelState extends State<QuickExpensePanel> {
  final _amount = TextEditingController(text: '35000');
  final _vendor = TextEditingController();
  final _memo = TextEditingController();
  String _category = 'hospital';

  @override
  void dispose() {
    _amount.dispose();
    _vendor.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amount.text.trim());
    if (amount == null) return;
    await widget.onSubmit(
      category: _category,
      amount: amount,
      vendorName: _vendor.text.trim(),
      memo: _memo.text.trim(),
    );
    _memo.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '지출 추가',
      child: Column(
        children: [
          _ResponsivePair(
            first: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '분류'),
              items: const [
                DropdownMenuItem(value: 'hospital', child: Text('병원')),
                DropdownMenuItem(value: 'food', child: Text('사료')),
                DropdownMenuItem(value: 'grooming', child: Text('미용')),
                DropdownMenuItem(value: 'supplies', child: Text('용품')),
              ],
              onChanged: widget.busy
                  ? null
                  : (value) => setState(() => _category = value ?? _category),
            ),
            second: TextField(
              key: const ValueKey('quick-expense-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '금액'),
            ),
          ),
          const SizedBox(height: 12),
          _ResponsivePair(
            first: TextField(
              key: const ValueKey('quick-expense-vendor'),
              controller: _vendor,
              decoration: const InputDecoration(labelText: '사용처'),
            ),
            second: TextField(
              key: const ValueKey('quick-expense-memo'),
              controller: _memo,
              decoration: const InputDecoration(labelText: '메모'),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('quick-expense-submit'),
              onPressed: widget.busy ? null : _submit,
              icon: const Icon(Icons.add_card),
              label: const Text('지출 저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class MedicalVisitPanel extends StatefulWidget {
  const MedicalVisitPanel({
    super.key,
    required this.busy,
    required this.onSubmit,
    required this.onCreateReport,
  });

  final bool busy;
  final Future<void> Function({
    required String hospitalName,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required num? expenseAmount,
  })
  onSubmit;
  final Future<void> Function() onCreateReport;

  @override
  State<MedicalVisitPanel> createState() => _MedicalVisitPanelState();
}

class _MedicalVisitPanelState extends State<MedicalVisitPanel> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalName = TextEditingController(text: '동네동물병원');
  final _visitReason = TextEditingController(text: '정기 진료');
  final _symptoms = TextEditingController();
  final _diagnosis = TextEditingController();
  final _treatment = TextEditingController();
  final _prescribedItems = TextEditingController();
  final _followUpDate = TextEditingController();
  final _expenseAmount = TextEditingController();

  @override
  void dispose() {
    _hospitalName.dispose();
    _visitReason.dispose();
    _symptoms.dispose();
    _diagnosis.dispose();
    _treatment.dispose();
    _prescribedItems.dispose();
    _followUpDate.dispose();
    _expenseAmount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(
      hospitalName: _hospitalName.text.trim(),
      visitReason: _visitReason.text.trim(),
      symptoms: _symptoms.text.trim(),
      diagnosis: _diagnosis.text.trim(),
      treatment: _treatment.text.trim(),
      prescribedItems: _prescribedItems.text.trim(),
      followUpDate: _followUpDate.text.trim(),
      expenseAmount: num.tryParse(_expenseAmount.text.trim()),
    );
    _symptoms.clear();
    _diagnosis.clear();
    _treatment.clear();
    _prescribedItems.clear();
    _followUpDate.clear();
    _expenseAmount.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '병원 방문 기록',
      trailing: TextButton.icon(
        onPressed: widget.busy ? null : widget.onCreateReport,
        icon: const Icon(Icons.description_outlined),
        label: const Text('리포트 갱신'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ResponsivePair(
              first: TextFormField(
                key: const ValueKey('quick-medical-visit-hospital'),
                controller: _hospitalName,
                decoration: const InputDecoration(labelText: '병원명'),
                validator: _required,
              ),
              second: TextFormField(
                key: const ValueKey('quick-medical-visit-reason'),
                controller: _visitReason,
                decoration: const InputDecoration(labelText: '방문 사유'),
              ),
            ),
            const SizedBox(height: 12),
            _ResponsivePair(
              first: TextFormField(
                key: const ValueKey('quick-medical-visit-symptoms'),
                controller: _symptoms,
                decoration: const InputDecoration(labelText: '증상'),
                maxLines: 2,
              ),
              second: TextFormField(
                key: const ValueKey('quick-medical-visit-diagnosis'),
                controller: _diagnosis,
                decoration: const InputDecoration(labelText: '진단/소견'),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            _ResponsivePair(
              first: TextFormField(
                key: const ValueKey('quick-medical-visit-treatment'),
                controller: _treatment,
                decoration: const InputDecoration(labelText: '처치/치료'),
                maxLines: 2,
              ),
              second: TextFormField(
                key: const ValueKey('quick-medical-visit-prescribed'),
                controller: _prescribedItems,
                decoration: const InputDecoration(labelText: '처방/복약'),
              ),
            ),
            const SizedBox(height: 12),
            _ResponsivePair(
              first: TextFormField(
                key: const ValueKey('quick-medical-visit-follow-up-date'),
                controller: _followUpDate,
                decoration: const InputDecoration(labelText: '재방문일 yyyy-mm-dd'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return DateTime.tryParse(text) == null
                      ? '날짜 형식이 필요합니다.'
                      : null;
                },
              ),
              second: TextFormField(
                key: const ValueKey('quick-medical-visit-expense-amount'),
                controller: _expenseAmount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '진료비'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return num.tryParse(text) == null ? '숫자로 입력하세요.' : null;
                },
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('quick-medical-visit-submit'),
                onPressed: widget.busy ? null : _submit,
                icon: const Icon(Icons.local_hospital_outlined),
                label: const Text('방문 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VisitReportPanel extends StatelessWidget {
  const VisitReportPanel({
    super.key,
    required this.report,
    required this.busy,
    required this.onCreate,
  });

  final JsonMap? report;
  final bool busy;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final summary = report?['summary'] as JsonMap?;
    final notice = report?['notice'] as String?;

    return _Section(
      title: '병원 방문 리포트',
      trailing: FilledButton.icon(
        onPressed: busy ? null : onCreate,
        icon: const Icon(Icons.description_outlined),
        label: const Text('생성'),
      ),
      child: report == null
          ? const _EmptyState(text: '생성된 방문 리포트가 없습니다.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report!['title'] as String? ?? '방문 리포트',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '최근 증상: ${(summary?['recentSymptoms'] as List<dynamic>? ?? []).join(', ')}',
                ),
                const SizedBox(height: 6),
                Text(
                  '최근 방문: ${(summary?['recentVisits'] as List<dynamic>? ?? []).length}건',
                ),
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    notice,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7A4F19),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ForecastDetail extends StatelessWidget {
  const _ForecastDetail({
    required this.forecast,
    required this.fallback,
    required this.history,
    required this.busy,
    required this.onRecalculate,
  });

  final JsonMap? forecast;
  final JsonMap? fallback;
  final List<JsonMap> history;
  final bool busy;
  final Future<void> Function() onRecalculate;

  @override
  Widget build(BuildContext context) {
    final current = forecast ?? fallback;
    final monthly = _asNum(
      forecast?['monthlyEstimate'] ?? fallback?['monthlyEstimate'],
    );
    final yearly = _asNum(
      forecast?['yearlyEstimate'] ?? fallback?['yearlyEstimate'],
    );
    final rangeMin = _asNum(forecast?['rangeMin']);
    final rangeMax = _asNum(forecast?['rangeMax']);
    final sixMonth = _asNum(current?['sixMonthEstimate']);
    final lifetime = _asNum(current?['lifetimeEstimate']);
    final confidence = current?['confidenceLevel'] as String?;
    final breakdown = current?['breakdown'] as JsonMap?;

    return _Section(
      title: '비용 예측',
      trailing: TextButton.icon(
        key: const ValueKey('forecast-recalculate-button'),
        onPressed: busy ? null : onRecalculate,
        icon: const Icon(Icons.calculate_outlined),
        label: const Text('재계산'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineStats(
            items: [
              _InlineStat('월 예상', _won(monthly)),
              _InlineStat('6개월', _won(sixMonth)),
              _InlineStat('연 예상', _won(yearly)),
            ],
          ),
          if (rangeMin != null && rangeMax != null) ...[
            const SizedBox(height: 14),
            Text('월 예상 범위 ${_won(rangeMin)} - ${_won(rangeMax)}'),
          ],
          if (confidence != null || lifetime != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (confidence != null)
                  '신뢰도 ${_forecastConfidenceLabel(confidence)}',
                if (lifetime != null) '예상 생애 비용 ${_won(lifetime)}',
              ].join(' · '),
            ),
          ],
          if (breakdown != null) ...[
            const SizedBox(height: 14),
            _InlineStats(
              items: [
                _InlineStat('고정비', _won(breakdown['fixedCost'])),
                _InlineStat('예방관리', _won(breakdown['plannedCareCost'])),
                _InlineStat('건강 리스크', _won(breakdown['riskAdjustedCost'])),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '예측은 기록 기반 참고값이며 진료 판단이나 보험 견적을 대체하지 않습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D7471)),
          ),
          if (history.isNotEmpty) ...[
            const Divider(height: 28),
            Text(
              '최근 예측 이력',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Column(
              children: history
                  .take(6)
                  .map((item) => _ForecastHistoryTile(forecast: item))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForecastHistoryTile extends StatelessWidget {
  const _ForecastHistoryTile({required this.forecast});

  final JsonMap forecast;

  @override
  Widget build(BuildContext context) {
    final scenario = forecast['scenario'] as String? ?? 'basic';
    final monthly = _won(forecast['monthlyEstimate']);
    final generatedAt = _formatDate(forecast['generatedAt'] as String?);
    final confidence = forecast['confidenceLevel'] as String?;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.history),
      title: Text('${_forecastScenarioLabel(scenario)} · $monthly'),
      subtitle: Text(
        [
          generatedAt,
          if (confidence != null) _forecastConfidenceLabel(confidence),
        ].join(' · '),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6D7471)),
      ),
    );
  }
}

String? _required(String? value) {
  return (value ?? '').trim().isEmpty ? '필수 입력입니다.' : null;
}

String? _optionalNumberValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return num.tryParse(text) == null ? '숫자로 입력하세요.' : null;
}

String? _optionalIntValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return int.tryParse(text) == null ? '정수로 입력하세요.' : null;
}

String? _optionalDateValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) == null ? '날짜 형식이 필요합니다.' : null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

num? _asNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

String _formatBytes(num bytes) {
  if (bytes < 1024) return '${bytes.round()} B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

String _won(Object? value) {
  final number = _asNum(value);
  if (number == null) return '-';
  return '${NumberFormat.decimalPattern().format(number.round())}원';
}

String _forecastScenarioLabel(String value) {
  return switch (value) {
    'basic' => '기본',
    'caution' => '주의',
    'high_risk' => '고위험',
    _ => value,
  };
}

String _forecastConfidenceLabel(String value) {
  return switch (value) {
    'high' => '높음',
    'medium' => '보통',
    'low' => '낮음',
    _ => value,
  };
}

String _formatDate(String? value) {
  final date = value == null ? null : DateTime.tryParse(value)?.toLocal();
  if (date == null) return '-';
  return DateFormat('M월 d일').format(date);
}

String? _nullableDate(String? value) {
  final formatted = _formatDate(value);
  return formatted == '-' ? null : formatted;
}

String _fieldText(Object? value) {
  if (value == null) return '';
  return value.toString();
}

String _dateInput(String? value) {
  final date = value == null ? null : DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  return DateFormat('yyyy-MM-dd').format(date);
}

Future<void> _disposeDialogControllers(
  List<TextEditingController> controllers,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final controller in controllers) {
    controller.dispose();
  }
}
