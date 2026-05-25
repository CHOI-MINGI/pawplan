import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef JsonMap = Map<String, dynamic>;

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl ?? resolveDefaultApiBaseUrl(),
      _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _accessToken;

  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;

  void setSessionToken(String? token) {
    _accessToken = token;
  }

  void clearSession() {
    _accessToken = null;
  }

  Future<JsonMap> register({
    required String email,
    required String password,
    required String name,
  }) {
    return _request<JsonMap>(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password, 'name': name},
    );
  }

  Future<JsonMap> login({
    required String email,
    required String password,
  }) async {
    final data = await _request<JsonMap>(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    _accessToken = data['accessToken'] as String?;
    return data;
  }

  Future<List<JsonMap>> dogs() async {
    final data = await _request<List<dynamic>>('GET', '/dogs');
    return data.cast<JsonMap>();
  }

  Future<JsonMap> me() {
    return _request<JsonMap>('GET', '/auth/me');
  }

  Future<JsonMap> onboardDog(JsonMap payload) {
    return _request<JsonMap>('POST', '/onboarding/dogs', body: payload);
  }

  Future<JsonMap> updateDog({required int dogId, required JsonMap payload}) {
    return _request<JsonMap>('PATCH', '/dogs/$dogId', body: payload);
  }

  Future<JsonMap> dogDeletePreview(int dogId) {
    return _request<JsonMap>('GET', '/dogs/$dogId/delete-preview');
  }

  Future<JsonMap> deleteDog(int dogId) {
    return _request<JsonMap>('DELETE', '/dogs/$dogId');
  }

  Future<List<JsonMap>> dogMembers(int dogId) async {
    final data = await _request<List<dynamic>>('GET', '/dogs/$dogId/members');
    return data.cast<JsonMap>();
  }

  Future<JsonMap> addDogMember({
    required int dogId,
    required String email,
    required String role,
  }) {
    return _request<JsonMap>(
      'POST',
      '/dogs/$dogId/members',
      body: {'email': email, 'role': role},
    );
  }

  Future<JsonMap> updateDogMembership({
    required int membershipId,
    required String role,
  }) {
    return _request<JsonMap>(
      'PATCH',
      '/dog-memberships/$membershipId',
      body: {'role': role},
    );
  }

  Future<JsonMap> removeDogMembership(int membershipId) {
    return _request<JsonMap>('DELETE', '/dog-memberships/$membershipId');
  }

  Future<JsonMap> dashboard(int dogId) {
    return _request<JsonMap>('GET', '/dogs/$dogId/dashboard');
  }

  Future<List<JsonMap>> careSchedules(int dogId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/dogs/$dogId/care-schedules?status=pending',
    );
    return data.cast<JsonMap>();
  }

  Future<List<JsonMap>> healthLogs(int dogId) async {
    final data = await _pagedList('/dogs/$dogId/health-logs?pageSize=50');
    return data;
  }

  Future<List<JsonMap>> medicalVisits(int dogId) async {
    final data = await _pagedList('/dogs/$dogId/medical-visits?pageSize=50');
    return data;
  }

  Future<List<JsonMap>> visitAttachments(int visitId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/medical-visits/$visitId/attachments',
    );
    return data.cast<JsonMap>();
  }

  Future<List<JsonMap>> expenses(int dogId) async {
    final data = await _pagedList('/dogs/$dogId/expenses?pageSize=50');
    return data;
  }

  Future<List<JsonMap>> timeline(int dogId) async {
    final data = await _pagedList('/dogs/$dogId/timeline?pageSize=60');
    return data;
  }

  Future<List<JsonMap>> activity(int dogId) async {
    final data = await _pagedList('/dogs/$dogId/activity?pageSize=30');
    return data;
  }

  Future<List<JsonMap>> visitReports(int dogId) async {
    final data = await _pagedList('/dogs/$dogId/visit-reports?pageSize=20');
    return data;
  }

  Future<List<JsonMap>> conditions(int dogId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/dogs/$dogId/conditions',
    );
    return data.cast<JsonMap>();
  }

  Future<List<JsonMap>> medications(int dogId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/dogs/$dogId/medications',
    );
    return data.cast<JsonMap>();
  }

  Future<JsonMap> createCondition({
    required int dogId,
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/dogs/$dogId/conditions',
      body: {
        'conditionType': conditionType,
        'conditionName': conditionName,
        'severity': severity,
        'diagnosedOn': diagnosedOn.trim().isEmpty ? null : diagnosedOn,
        'status': status,
        'notes': notes,
        'isSensitive': isSensitive,
      },
    );
  }

  Future<JsonMap> updateCondition({
    required int conditionId,
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'conditionType': conditionType,
      'conditionName': conditionName,
      'severity': severity,
      'diagnosedOn': diagnosedOn.trim().isEmpty ? null : diagnosedOn,
      'status': status,
      'notes': notes,
    };
    if (isSensitive != null) {
      body['isSensitive'] = isSensitive;
    }
    return _request<JsonMap>('PATCH', '/conditions/$conditionId', body: body);
  }

  Future<JsonMap> deleteCondition(int conditionId) {
    return _request<JsonMap>('DELETE', '/conditions/$conditionId');
  }

  Future<JsonMap> createMedication({
    required int dogId,
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/dogs/$dogId/medications',
      body: {
        'medicationName': medicationName,
        'dosage': dosage,
        'frequencyText': frequencyText,
        'startedOn': startedOn.trim().isEmpty ? null : startedOn,
        'endedOn': endedOn.trim().isEmpty ? null : endedOn,
        'prescribedBy': prescribedBy,
        'isActive': isActive,
        'notes': notes,
        'isSensitive': isSensitive,
      },
    );
  }

  Future<JsonMap> updateMedication({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'medicationName': medicationName,
      'dosage': dosage,
      'frequencyText': frequencyText,
      'startedOn': startedOn.trim().isEmpty ? null : startedOn,
      'endedOn': endedOn.trim().isEmpty ? null : endedOn,
      'prescribedBy': prescribedBy,
      'isActive': isActive,
      'notes': notes,
    };
    if (isSensitive != null) {
      body['isSensitive'] = isSensitive;
    }
    return _request<JsonMap>('PATCH', '/medications/$medicationId', body: body);
  }

  Future<JsonMap> deleteMedication(int medicationId) {
    return _request<JsonMap>('DELETE', '/medications/$medicationId');
  }

  Future<JsonMap> completeSchedule(int scheduleId) {
    return _request<JsonMap>('POST', '/care-schedules/$scheduleId/complete');
  }

  Future<JsonMap> createCareSchedule({
    required int dogId,
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    int? repeatCycleDays,
    int? assignedToUserId,
  }) {
    final body = <String, dynamic>{
      'scheduleType': scheduleType,
      'title': title,
      'dueDate': dueDate,
      'description': description,
      'priority': priority,
    };
    if (repeatCycleDays != null) {
      body['repeatCycleDays'] = repeatCycleDays;
    }
    if (assignedToUserId != null) {
      body['assignedToUserId'] = assignedToUserId;
    }

    return _request<JsonMap>('POST', '/dogs/$dogId/care-schedules', body: body);
  }

  Future<JsonMap> updateCareSchedule({
    required int scheduleId,
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    required bool reminderEnabled,
    int? repeatCycleDays,
    int? assignedToUserId,
  }) {
    final body = <String, dynamic>{
      'scheduleType': scheduleType,
      'title': title,
      'dueDate': dueDate,
      'description': description,
      'priority': priority,
      'reminderEnabled': reminderEnabled,
      'repeatCycleDays': repeatCycleDays,
    };
    if (assignedToUserId != null) {
      body['assignedToUserId'] = assignedToUserId;
    }
    return _request<JsonMap>(
      'PATCH',
      '/care-schedules/$scheduleId',
      body: body,
    );
  }

  Future<JsonMap> skipSchedule(int scheduleId) {
    return _request<JsonMap>('POST', '/care-schedules/$scheduleId/skip');
  }

  Future<JsonMap> latestForecast(int dogId) {
    return _request<JsonMap>('GET', '/dogs/$dogId/cost-forecasts/latest');
  }

  Future<List<JsonMap>> forecastHistory(int dogId) async {
    final data = await _pagedList(
      '/dogs/$dogId/cost-forecasts/history?pageSize=30',
    );
    return data;
  }

  Future<JsonMap> recalculateForecast(int dogId) {
    return _request<JsonMap>('POST', '/dogs/$dogId/cost-forecasts/recalculate');
  }

  Future<JsonMap> createHealthLog({
    required int dogId,
    required String logType,
    required String title,
    String? memo,
    String? recordedAt,
    num? valueNumeric,
    String? valueUnit,
    JsonMap? metadata,
    bool isSensitive = false,
  }) {
    final body = <String, dynamic>{'logType': logType, 'title': title};
    if (memo != null && memo.trim().isNotEmpty) {
      body['memo'] = memo;
    }
    if (recordedAt != null && recordedAt.trim().isNotEmpty) {
      body['recordedAt'] = recordedAt;
    }
    if (valueNumeric != null) {
      body['valueNumeric'] = valueNumeric;
    }
    if (valueUnit != null && valueUnit.trim().isNotEmpty) {
      body['valueUnit'] = valueUnit;
    }
    if (metadata != null && metadata.isNotEmpty) {
      body['metadata'] = metadata;
    }
    body['isSensitive'] = isSensitive;

    return _request<JsonMap>('POST', '/dogs/$dogId/health-logs', body: body);
  }

  Future<JsonMap> updateHealthLog({
    required int logId,
    required String logType,
    required String title,
    required String memo,
    String? recordedAt,
    num? valueNumeric,
    String? valueUnit,
    JsonMap? metadata,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'logType': logType,
      'title': title,
      'memo': memo,
    };
    if (recordedAt != null && recordedAt.trim().isNotEmpty) {
      body['recordedAt'] = recordedAt;
    }
    if (valueNumeric != null) {
      body['valueNumeric'] = valueNumeric;
    }
    if (valueUnit?.trim().isNotEmpty ?? false) {
      body['valueUnit'] = valueUnit;
    }
    if (metadata != null) {
      body['metadata'] = metadata;
    }
    if (isSensitive != null) {
      body['isSensitive'] = isSensitive;
    }

    return _request<JsonMap>('PATCH', '/health-logs/$logId', body: body);
  }

  Future<JsonMap> deleteHealthLog(int logId) {
    return _request<JsonMap>('DELETE', '/health-logs/$logId');
  }

  Future<JsonMap> createExpense({
    required int dogId,
    required String category,
    required num amount,
    String? expenseDate,
    String? vendorName,
    String? memo,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/dogs/$dogId/expenses',
      body: {
        'expenseCategory': category,
        'amount': amount,
        if (expenseDate != null && expenseDate.trim().isNotEmpty)
          'expenseDate': expenseDate,
        if (vendorName != null && vendorName.trim().isNotEmpty)
          'vendorName': vendorName,
        if (memo != null && memo.trim().isNotEmpty) 'memo': memo,
        'isSensitive': isSensitive,
      },
    );
  }

  Future<JsonMap> updateExpense({
    required int expenseId,
    required String category,
    required num amount,
    required String expenseDate,
    required String vendorName,
    required String memo,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'expenseCategory': category,
      'amount': amount,
      if (expenseDate.trim().isNotEmpty) 'expenseDate': expenseDate,
      'vendorName': vendorName,
      'memo': memo,
    };
    if (isSensitive != null) {
      body['isSensitive'] = isSensitive;
    }
    return _request<JsonMap>('PATCH', '/expenses/$expenseId', body: body);
  }

  Future<JsonMap> deleteExpense(int expenseId) {
    return _request<JsonMap>('DELETE', '/expenses/$expenseId');
  }

  Future<JsonMap> createMedicalVisit({
    required int dogId,
    required String hospitalName,
    String? veterinarianName,
    String? visitDate,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    String? notes,
    required num? expenseAmount,
    String? expenseDate,
    String? expenseMemo,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/dogs/$dogId/medical-visits',
      body: {
        'hospitalName': hospitalName,
        if (veterinarianName != null && veterinarianName.trim().isNotEmpty)
          'veterinarianName': veterinarianName,
        if (visitDate != null && visitDate.trim().isNotEmpty)
          'visitDate': visitDate,
        if (visitReason.trim().isNotEmpty) 'visitReason': visitReason,
        if (symptoms.trim().isNotEmpty) 'symptoms': symptoms,
        if (diagnosis.trim().isNotEmpty) 'diagnosis': diagnosis,
        if (treatment.trim().isNotEmpty) 'treatment': treatment,
        if (prescribedItems.trim().isNotEmpty)
          'prescribedItems': prescribedItems,
        if (followUpDate.trim().isNotEmpty) 'followUpDate': followUpDate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes,
        'isSensitive': isSensitive,
        if (expenseAmount != null && expenseAmount > 0)
          'expense': {
            'create': true,
            'amount': expenseAmount,
            if (expenseDate != null && expenseDate.trim().isNotEmpty)
              'expenseDate': expenseDate,
            'vendorName': hospitalName,
            if (expenseMemo != null && expenseMemo.trim().isNotEmpty)
              'memo': expenseMemo,
          },
      },
    );
  }

  Future<JsonMap> updateMedicalVisit({
    required int visitId,
    required String hospitalName,
    String? veterinarianName,
    String? visitDate,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required String notes,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'hospitalName': hospitalName,
      if (veterinarianName != null && veterinarianName.trim().isNotEmpty)
        'veterinarianName': veterinarianName,
      if (visitDate != null && visitDate.trim().isNotEmpty)
        'visitDate': visitDate,
      'visitReason': visitReason,
      'symptoms': symptoms,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'prescribedItems': prescribedItems,
      if (followUpDate.trim().isNotEmpty) 'followUpDate': followUpDate,
      'notes': notes,
    };
    if (isSensitive != null) {
      body['isSensitive'] = isSensitive;
    }
    return _request<JsonMap>('PATCH', '/medical-visits/$visitId', body: body);
  }

  Future<JsonMap> deleteMedicalVisit(int visitId) {
    return _request<JsonMap>('DELETE', '/medical-visits/$visitId');
  }

  Future<JsonMap> uploadVisitAttachment({
    required int visitId,
    required String fileType,
    required String filename,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/$'), '')}/medical-visits/$visitId/attachments',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      })
      ..fields['fileType'] = fileType
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    try {
      final streamed = await _http.send(request);
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse<JsonMap>(response);
    } on http.ClientException {
      throw ApiException(
        'API 서버 연결에 실패했습니다. 백엔드 서버와 API 주소를 확인하세요. ($baseUrl)',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<Uint8List> downloadAttachment(int attachmentId) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/$'), '')}/attachments/$attachmentId/download',
    );
    try {
      final response = await _http.get(
        uri,
        headers: {
          if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          '첨부파일 다운로드에 실패했습니다.',
          statusCode: response.statusCode,
        );
      }
      return response.bodyBytes;
    } on http.ClientException {
      throw ApiException(
        'API 서버 연결에 실패했습니다. 백엔드 서버와 API 주소를 확인하세요. ($baseUrl)',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<JsonMap> deleteAttachment(int attachmentId) {
    return _request<JsonMap>('DELETE', '/attachments/$attachmentId');
  }

  Future<JsonMap> generateVisitReport(int dogId) {
    return _request<JsonMap>('POST', '/dogs/$dogId/visit-reports');
  }

  Future<JsonMap?> latestVisitReport(int dogId) {
    return _request<JsonMap?>('GET', '/dogs/$dogId/visit-reports/latest');
  }

  // ── Cat API methods ──────────────────────────────────────────────────────

  Future<List<JsonMap>> cats() async {
    final data = await _request<List<dynamic>>('GET', '/cats');
    return data.cast<JsonMap>();
  }

  Future<JsonMap> onboardCat(JsonMap payload) {
    return _request<JsonMap>('POST', '/onboarding/cats', body: payload);
  }

  Future<JsonMap> updateCat({required int catId, required JsonMap payload}) {
    return _request<JsonMap>('PATCH', '/cats/$catId', body: payload);
  }

  Future<JsonMap> catDeletePreview(int catId) {
    return _request<JsonMap>('GET', '/cats/$catId/delete-preview');
  }

  Future<JsonMap> deleteCat(int catId) {
    return _request<JsonMap>('DELETE', '/cats/$catId');
  }

  Future<List<JsonMap>> catMembers(int catId) async {
    final data = await _request<List<dynamic>>('GET', '/cats/$catId/members');
    return data.cast<JsonMap>();
  }

  Future<JsonMap> addCatMember({
    required int catId,
    required String email,
    required String role,
  }) {
    return _request<JsonMap>(
      'POST',
      '/cats/$catId/members',
      body: {'email': email, 'role': role},
    );
  }

  Future<JsonMap> updateCatMembership({
    required int membershipId,
    required String role,
  }) {
    return _request<JsonMap>(
      'PATCH',
      '/cat-memberships/$membershipId',
      body: {'role': role},
    );
  }

  Future<JsonMap> removeCatMembership(int membershipId) {
    return _request<JsonMap>('DELETE', '/cat-memberships/$membershipId');
  }

  Future<JsonMap> catDashboard(int catId) {
    return _request<JsonMap>('GET', '/cats/$catId/dashboard');
  }

  Future<List<JsonMap>> catCareSchedules(int catId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/cats/$catId/care-schedules?status=pending',
    );
    return data.cast<JsonMap>();
  }

  Future<JsonMap> createCatCareSchedule({
    required int catId,
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    int? repeatCycleDays,
    int? assignedToUserId,
  }) {
    final body = <String, dynamic>{
      'scheduleType': scheduleType,
      'title': title,
      'dueDate': dueDate,
      'description': description,
      'priority': priority,
    };
    if (repeatCycleDays != null) body['repeatCycleDays'] = repeatCycleDays;
    if (assignedToUserId != null) body['assignedToUserId'] = assignedToUserId;
    return _request<JsonMap>('POST', '/cats/$catId/care-schedules', body: body);
  }

  Future<JsonMap> updateCatCareSchedule({
    required int scheduleId,
    required String scheduleType,
    required String title,
    required String dueDate,
    required String description,
    required String priority,
    required bool reminderEnabled,
    int? repeatCycleDays,
    int? assignedToUserId,
  }) {
    final body = <String, dynamic>{
      'scheduleType': scheduleType,
      'title': title,
      'dueDate': dueDate,
      'description': description,
      'priority': priority,
      'reminderEnabled': reminderEnabled,
      'repeatCycleDays': repeatCycleDays,
    };
    if (assignedToUserId != null) body['assignedToUserId'] = assignedToUserId;
    return _request<JsonMap>(
      'PATCH',
      '/cat-care-schedules/$scheduleId',
      body: body,
    );
  }

  Future<JsonMap> completeCatSchedule(int scheduleId) {
    return _request<JsonMap>(
      'POST',
      '/cat-care-schedules/$scheduleId/complete',
    );
  }

  Future<JsonMap> skipCatSchedule(int scheduleId) {
    return _request<JsonMap>('POST', '/cat-care-schedules/$scheduleId/skip');
  }

  Future<List<JsonMap>> catHealthLogs(int catId) async {
    return _pagedList('/cats/$catId/health-logs?pageSize=50');
  }

  Future<JsonMap> createCatHealthLog({
    required int catId,
    required String logType,
    required String title,
    String? memo,
    String? recordedAt,
    num? valueNumeric,
    String? valueUnit,
    JsonMap? metadata,
    bool isSensitive = false,
  }) {
    final body = <String, dynamic>{'logType': logType, 'title': title};
    if (memo != null && memo.trim().isNotEmpty) body['memo'] = memo;
    if (recordedAt != null && recordedAt.trim().isNotEmpty) {
      body['recordedAt'] = recordedAt;
    }
    if (valueNumeric != null) body['valueNumeric'] = valueNumeric;
    if (valueUnit != null && valueUnit.trim().isNotEmpty) {
      body['valueUnit'] = valueUnit;
    }
    if (metadata != null && metadata.isNotEmpty) body['metadata'] = metadata;
    body['isSensitive'] = isSensitive;
    return _request<JsonMap>('POST', '/cats/$catId/health-logs', body: body);
  }

  Future<JsonMap> updateCatHealthLog({
    required int logId,
    required String logType,
    required String title,
    required String memo,
    String? recordedAt,
    num? valueNumeric,
    String? valueUnit,
    JsonMap? metadata,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'logType': logType,
      'title': title,
      'memo': memo,
    };
    if (recordedAt != null && recordedAt.trim().isNotEmpty) {
      body['recordedAt'] = recordedAt;
    }
    if (valueNumeric != null) body['valueNumeric'] = valueNumeric;
    if (valueUnit?.trim().isNotEmpty ?? false) body['valueUnit'] = valueUnit;
    if (metadata != null) body['metadata'] = metadata;
    if (isSensitive != null) body['isSensitive'] = isSensitive;
    return _request<JsonMap>('PATCH', '/cat-health-logs/$logId', body: body);
  }

  Future<JsonMap> deleteCatHealthLog(int logId) {
    return _request<JsonMap>('DELETE', '/cat-health-logs/$logId');
  }

  Future<List<JsonMap>> catMedicalVisits(int catId) async {
    return _pagedList('/cats/$catId/medical-visits?pageSize=50');
  }

  Future<JsonMap> createCatMedicalVisit({
    required int catId,
    required String hospitalName,
    String? veterinarianName,
    String? visitDate,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    String? notes,
    required num? expenseAmount,
    String? expenseDate,
    String? expenseMemo,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/cats/$catId/medical-visits',
      body: {
        'hospitalName': hospitalName,
        if (veterinarianName != null && veterinarianName.trim().isNotEmpty)
          'veterinarianName': veterinarianName,
        if (visitDate != null && visitDate.trim().isNotEmpty)
          'visitDate': visitDate,
        if (visitReason.trim().isNotEmpty) 'visitReason': visitReason,
        if (symptoms.trim().isNotEmpty) 'symptoms': symptoms,
        if (diagnosis.trim().isNotEmpty) 'diagnosis': diagnosis,
        if (treatment.trim().isNotEmpty) 'treatment': treatment,
        if (prescribedItems.trim().isNotEmpty)
          'prescribedItems': prescribedItems,
        if (followUpDate.trim().isNotEmpty) 'followUpDate': followUpDate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes,
        'isSensitive': isSensitive,
        if (expenseAmount != null && expenseAmount > 0)
          'expense': {
            'create': true,
            'amount': expenseAmount,
            if (expenseDate != null && expenseDate.trim().isNotEmpty)
              'expenseDate': expenseDate,
            'vendorName': hospitalName,
            if (expenseMemo != null && expenseMemo.trim().isNotEmpty)
              'memo': expenseMemo,
          },
      },
    );
  }

  Future<JsonMap> updateCatMedicalVisit({
    required int visitId,
    required String hospitalName,
    String? veterinarianName,
    String? visitDate,
    required String visitReason,
    required String symptoms,
    required String diagnosis,
    required String treatment,
    required String prescribedItems,
    required String followUpDate,
    required String notes,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'hospitalName': hospitalName,
      if (veterinarianName != null && veterinarianName.trim().isNotEmpty)
        'veterinarianName': veterinarianName,
      if (visitDate != null && visitDate.trim().isNotEmpty)
        'visitDate': visitDate,
      'visitReason': visitReason,
      'symptoms': symptoms,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'prescribedItems': prescribedItems,
      if (followUpDate.trim().isNotEmpty) 'followUpDate': followUpDate,
      'notes': notes,
    };
    if (isSensitive != null) body['isSensitive'] = isSensitive;
    return _request<JsonMap>(
      'PATCH',
      '/cat-medical-visits/$visitId',
      body: body,
    );
  }

  Future<JsonMap> deleteCatMedicalVisit(int visitId) {
    return _request<JsonMap>('DELETE', '/cat-medical-visits/$visitId');
  }

  Future<List<JsonMap>> catVisitAttachments(int visitId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/cat-medical-visits/$visitId/attachments',
    );
    return data.cast<JsonMap>();
  }

  Future<JsonMap> uploadCatVisitAttachment({
    required int visitId,
    required String fileType,
    required String filename,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/$'), '')}/cat-medical-visits/$visitId/attachments',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      })
      ..fields['fileType'] = fileType
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    try {
      final streamed = await _http.send(request);
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse<JsonMap>(response);
    } on http.ClientException {
      throw ApiException(
        'API 서버 연결에 실패했습니다. 백엔드 서버와 API 주소를 확인하세요. ($baseUrl)',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<Uint8List> downloadCatAttachment(int attachmentId) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/$'), '')}/cat-attachments/$attachmentId/download',
    );
    try {
      final response = await _http.get(
        uri,
        headers: {
          if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          '첨부파일 다운로드에 실패했습니다.',
          statusCode: response.statusCode,
        );
      }
      return response.bodyBytes;
    } on http.ClientException {
      throw ApiException(
        'API 서버 연결에 실패했습니다. 백엔드 서버와 API 주소를 확인하세요. ($baseUrl)',
        code: 'NETWORK_ERROR',
      );
    }
  }

  Future<JsonMap> deleteCatAttachment(int attachmentId) {
    return _request<JsonMap>('DELETE', '/cat-attachments/$attachmentId');
  }

  Future<List<JsonMap>> catExpenses(int catId) async {
    return _pagedList('/cats/$catId/expenses?pageSize=50');
  }

  Future<JsonMap> createCatExpense({
    required int catId,
    required String category,
    required num amount,
    String? expenseDate,
    String? vendorName,
    String? memo,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/cats/$catId/expenses',
      body: {
        'expenseCategory': category,
        'amount': amount,
        if (expenseDate != null && expenseDate.trim().isNotEmpty)
          'expenseDate': expenseDate,
        if (vendorName != null && vendorName.trim().isNotEmpty)
          'vendorName': vendorName,
        if (memo != null && memo.trim().isNotEmpty) 'memo': memo,
        'isSensitive': isSensitive,
      },
    );
  }

  Future<JsonMap> updateCatExpense({
    required int expenseId,
    required String category,
    required num amount,
    required String expenseDate,
    required String vendorName,
    required String memo,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'expenseCategory': category,
      'amount': amount,
      if (expenseDate.trim().isNotEmpty) 'expenseDate': expenseDate,
      'vendorName': vendorName,
      'memo': memo,
    };
    if (isSensitive != null) body['isSensitive'] = isSensitive;
    return _request<JsonMap>('PATCH', '/cat-expenses/$expenseId', body: body);
  }

  Future<JsonMap> deleteCatExpense(int expenseId) {
    return _request<JsonMap>('DELETE', '/cat-expenses/$expenseId');
  }

  Future<List<JsonMap>> catConditions(int catId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/cats/$catId/conditions',
    );
    return data.cast<JsonMap>();
  }

  Future<JsonMap> createCatCondition({
    required int catId,
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/cats/$catId/conditions',
      body: {
        'conditionType': conditionType,
        'conditionName': conditionName,
        'severity': severity,
        'diagnosedOn': diagnosedOn.trim().isEmpty ? null : diagnosedOn,
        'status': status,
        'notes': notes,
        'isSensitive': isSensitive,
      },
    );
  }

  Future<JsonMap> updateCatCondition({
    required int conditionId,
    required String conditionType,
    required String conditionName,
    required String severity,
    required String diagnosedOn,
    required String status,
    required String notes,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'conditionType': conditionType,
      'conditionName': conditionName,
      'severity': severity,
      'diagnosedOn': diagnosedOn.trim().isEmpty ? null : diagnosedOn,
      'status': status,
      'notes': notes,
    };
    if (isSensitive != null) body['isSensitive'] = isSensitive;
    return _request<JsonMap>(
      'PATCH',
      '/cat-conditions/$conditionId',
      body: body,
    );
  }

  Future<JsonMap> deleteCatCondition(int conditionId) {
    return _request<JsonMap>('DELETE', '/cat-conditions/$conditionId');
  }

  Future<List<JsonMap>> catMedications(int catId) async {
    final data = await _request<List<dynamic>>(
      'GET',
      '/cats/$catId/medications',
    );
    return data.cast<JsonMap>();
  }

  Future<JsonMap> createCatMedication({
    required int catId,
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
    bool isSensitive = false,
  }) {
    return _request<JsonMap>(
      'POST',
      '/cats/$catId/medications',
      body: {
        'medicationName': medicationName,
        'dosage': dosage,
        'frequencyText': frequencyText,
        'startedOn': startedOn.trim().isEmpty ? null : startedOn,
        'endedOn': endedOn.trim().isEmpty ? null : endedOn,
        'prescribedBy': prescribedBy,
        'isActive': isActive,
        'notes': notes,
        'isSensitive': isSensitive,
      },
    );
  }

  Future<JsonMap> updateCatMedication({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required String frequencyText,
    required String startedOn,
    required String endedOn,
    required String prescribedBy,
    required bool isActive,
    required String notes,
    bool? isSensitive,
  }) {
    final body = <String, dynamic>{
      'medicationName': medicationName,
      'dosage': dosage,
      'frequencyText': frequencyText,
      'startedOn': startedOn.trim().isEmpty ? null : startedOn,
      'endedOn': endedOn.trim().isEmpty ? null : endedOn,
      'prescribedBy': prescribedBy,
      'isActive': isActive,
      'notes': notes,
    };
    if (isSensitive != null) body['isSensitive'] = isSensitive;
    return _request<JsonMap>(
      'PATCH',
      '/cat-medications/$medicationId',
      body: body,
    );
  }

  Future<JsonMap> deleteCatMedication(int medicationId) {
    return _request<JsonMap>('DELETE', '/cat-medications/$medicationId');
  }

  Future<JsonMap> latestCatForecast(int catId) {
    return _request<JsonMap>('GET', '/cats/$catId/cost-forecasts/latest');
  }

  Future<JsonMap> recalculateCatForecast(int catId) {
    return _request<JsonMap>(
      'POST',
      '/cats/$catId/cost-forecasts/recalculate',
    );
  }

  Future<List<JsonMap>> catForecastHistory(int catId) async {
    return _pagedList('/cats/$catId/cost-forecasts/history?pageSize=30');
  }

  Future<JsonMap> generateCatVisitReport(int catId) {
    return _request<JsonMap>('POST', '/cats/$catId/visit-reports');
  }

  Future<JsonMap?> latestCatVisitReport(int catId) {
    return _request<JsonMap?>('GET', '/cats/$catId/visit-reports/latest');
  }

  Future<List<JsonMap>> catVisitReports(int catId) async {
    return _pagedList('/cats/$catId/visit-reports?pageSize=20');
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<List<JsonMap>> _pagedList(String path) async {
    final data = await _request<JsonMap>('GET', path);
    return (data['items'] as List<dynamic>? ?? []).cast<JsonMap>();
  }

  Future<T> _request<T>(String method, String path, {JsonMap? body}) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers);
        case 'POST':
          response = await _http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'PATCH':
          response = await _http.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'DELETE':
          response = await _http.delete(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } on http.ClientException {
      throw ApiException(
        'API 서버 연결에 실패했습니다. 백엔드 서버와 API 주소를 확인하세요. ($baseUrl)',
        code: 'NETWORK_ERROR',
      );
    }

    return _decodeResponse<T>(response);
  }

  T _decodeResponse<T>(http.Response response) {
    late JsonMap decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as JsonMap;
    } on FormatException {
      throw ApiException(
        'API 응답을 해석할 수 없습니다.',
        code: 'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'] as JsonMap?;
      throw ApiException(
        error?['message'] as String? ?? 'API request failed',
        code: error?['code'] as String?,
        statusCode: response.statusCode,
      );
    }

    if (decoded['success'] != true) {
      throw ApiException(
        'Unexpected API response',
        statusCode: response.statusCode,
      );
    }

    return decoded['data'] as T;
  }
}

String resolveDefaultApiBaseUrl() {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) {
    return configured;
  }

  final hostRunsOnDeveloperMachine =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  return hostRunsOnDeveloperMachine
      ? 'http://localhost:4000/api/v1'
      : 'http://10.0.2.2:4000/api/v1';
}
