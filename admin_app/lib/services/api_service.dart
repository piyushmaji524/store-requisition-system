import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'https://req.gunayatangatepass.com';

  static const String keyToken = 'admin_api_token';
  static const String keyUser = 'admin_user_profile';

  static String? _cachedToken;
  static AdminUser? _currentUser;

  static AdminUser? get currentUser => _currentUser;
  static String? get token => _cachedToken;

  /// Safe JSON Decode Helper (Prevents FormatException when Office WiFi returns HTML/Captive Portal)
  static dynamic _safeJsonDecode(String body) {
    try {
      final trimmed = body.trim();
      if (trimmed.startsWith('<') || trimmed.contains('<!DOCTYPE') || trimmed.contains('<html')) {
        return null;
      }
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  /// Headers helper with proper Mobile User-Agent
  static Map<String, String> _headers({bool withAuth = true}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 GunayatanApp/1.0',
    };
    if (withAuth && _cachedToken != null) {
      map['Authorization'] = 'Bearer $_cachedToken';
    }
    return map;
  }

  /// Admin Login
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers(withAuth: false),
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          'device_name': 'Admin Mobile App',
        }),
      );

      final json = _safeJsonDecode(res.body);
      if (json == null) {
        if (res.statusCode == 403) {
          return {
            'success': false,
            'message': 'Office WiFi / Firewall ne connection block kar diya (403 Forbidden). Kripya Mobile Data use karein ya WiFi captive portal login check karein.',
          };
        } else if (res.statusCode == 502 || res.statusCode == 503) {
          return {
            'success': false,
            'message': 'Server Gateway Temporary Error (${res.statusCode}). Kripya 1 minute baad dobara koshish karein.',
          };
        }
        return {
          'success': false,
          'message': 'Office WiFi network par Captive Portal / Firewall HTML intercept kar raha hai. Kripya browser me koi page kholkar WiFi login verify karein ya Mobile Hotspot use karein.',
        };
      }

      final isSuccess = res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true);
      if (isSuccess) {
        final data = json['data'];
        final userObj = AdminUser.fromJson(data['user']);

        // Verify admin role
        if (!['SUPER_ADMIN', 'ADMIN'].contains(userObj.role)) {
          return {
            'success': false,
            'message': 'Access Denied: This app is strictly for Administrators and Super Admins.',
          };
        }

        _cachedToken = data['token'];
        _currentUser = userObj;

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyToken, _cachedToken!);
        await prefs.setString(keyUser, jsonEncode(userObj.toJson()));

        return {'success': true, 'user': userObj};
      } else {
        return {'success': false, 'message': json['message'] ?? 'Login failed. Please check your credentials.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Restore Saved Session
  static Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(keyToken);
      final savedUserStr = prefs.getString(keyUser);

      if (savedToken != null && savedUserStr != null) {
        _cachedToken = savedToken;
        _currentUser = AdminUser.fromJson(jsonDecode(savedUserStr));
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Logout
  static Future<void> logout() async {
    try {
      if (_cachedToken != null) {
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: _headers(),
        );
      }
    } catch (_) {}
    _cachedToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
    await prefs.remove(keyUser);
  }

  /// Get Dashboard Metrics
  static Future<DashboardMetrics?> getDashboardMetrics({String? dateFrom, String? dateTo}) async {
    try {
      final queryParams = <String, String>{};
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/admin/dashboard').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return DashboardMetrics.fromJson(json['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get Timing Status
  static Future<Map<String, dynamic>?> getTimingStatus([String? date]) async {
    try {
      final uri = Uri.parse('$baseUrl/api/admin/timing-status' + (date != null ? '?date=$date' : ''));
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return json['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get Date Overrides List
  static Future<List<DateOverrideItem>> getDateOverrides() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/admin/date-overrides'), headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final list = json['data'] as List;
        return list.map((e) => DateOverrideItem.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Create Date Override
  static Future<Map<String, dynamic>> createDateOverride(String date, String reason, int durationHours) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/date-override'),
        headers: _headers(),
        body: jsonEncode({
          'override_date': date,
          'reason': reason,
          'duration_hours': durationHours,
        }),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'Override processed.',
        'data': json['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Force Close Date Override
  static Future<bool> closeDateOverride(int overrideId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/date-overrides/$overrideId/close'),
        headers: _headers(),
      );
      final json = jsonDecode(res.body);
      return res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Get Requisitions
  static Future<Map<String, dynamic>> getRequisitions({
    String? dateFrom,
    String? dateTo,
    String? status,
    int? locationId,
    String? search,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (locationId != null && locationId > 0) queryParams['location_id'] = locationId.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/api/admin/requisitions').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final data = json['data'];
        final list = (data['requisitions'] as List).map((e) => AdminRequisition.fromJson(e)).toList();
        return {
          'success': true,
          'requisitions': list,
          'total': data['total'] ?? list.length,
          'total_pages': data['total_pages'] ?? 1,
        };
      }
      return {'success': false, 'requisitions': <AdminRequisition>[]};
    } catch (e) {
      return {'success': false, 'requisitions': <AdminRequisition>[], 'error': e.toString()};
    }
  }

  /// Get Requisition Detail
  static Future<Map<String, dynamic>?> getRequisitionDetails(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/admin/requisitions/$id'), headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return json['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get Materials
  static Future<List<MaterialItem>> getMaterials({String? search, String? status}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/api/admin/materials').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final list = json['data'] as List;
        return list.map((e) => MaterialItem.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Save Material
  static Future<Map<String, dynamic>> saveMaterial(Map<String, dynamic> data, {int? id}) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (id != null) payload['id'] = id;
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/materials'),
        headers: _headers(),
        body: jsonEncode(payload),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'Saved successfully.',
      };
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  /// Quick Stock Edit
  static Future<Map<String, dynamic>> quickStockEdit(int materialId, double newStock, String remark) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/materials/$materialId/quick-stock'),
        headers: _headers(),
        body: jsonEncode({
          'current_stock': newStock,
          'remark': remark,
        }),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'Stock updated.',
        'data': json['data'],
      };
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  /// Toggle Material Status
  static Future<bool> toggleMaterialStatus(int materialId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/materials/$materialId/toggle-status'),
        headers: _headers(),
      );
      final json = jsonDecode(res.body);
      return res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Get Users
  static Future<List<UserItem>> getUsers({String? search, String? role, String? status}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (role != null && role != 'ALL') queryParams['role'] = role;
      if (status != null && status != 'ALL') queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/api/admin/users').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final list = json['data']['users'] as List;
        return list.map((e) => UserItem.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Save User
  static Future<Map<String, dynamic>> saveUser(Map<String, dynamic> data, {int? id}) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (id != null) payload['id'] = id;
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/users'),
        headers: _headers(),
        body: jsonEncode(payload),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'User saved.',
      };
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  /// Toggle User Status
  static Future<bool> toggleUserStatus(int userId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/users/$userId/toggle-status'),
        headers: _headers(),
      );
      final json = jsonDecode(res.body);
      return res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Reset User Password
  static Future<Map<String, dynamic>> resetUserPassword(int userId, String newPassword) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/users/$userId/reset-password'),
        headers: _headers(),
        body: jsonEncode({'new_password': newPassword}),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'Password reset successfully.',
      };
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  /// Get Locations
  static Future<List<LocationItem>> getLocations() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/admin/locations'), headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final list = json['data'] as List;
        return list.map((e) => LocationItem.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Save Location
  static Future<Map<String, dynamic>> saveLocation(Map<String, dynamic> data, {int? id}) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (id != null) payload['id'] = id;
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/locations'),
        headers: _headers(),
        body: jsonEncode(payload),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'Location saved.',
      };
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  /// Toggle Location Status
  static Future<bool> toggleLocationStatus(int locationId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/locations/$locationId/toggle-status'),
        headers: _headers(),
      );
      final json = jsonDecode(res.body);
      return res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Get Tally Preview
  static Future<Map<String, dynamic>?> getTallyPreview({
    required String dateFrom,
    required String dateTo,
    String exportStatus = 'NOT_EXPORTED',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/admin/tally/preview').replace(queryParameters: {
        'date_from': dateFrom,
        'date_to': dateTo,
        'export_status': exportStatus,
      });
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return json['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Generate Tally Export
  static Future<Map<String, dynamic>> generateTallyExport({
    required String dateFrom,
    required String dateTo,
    required List<int> subRequisitionIds,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/tally/export'),
        headers: _headers(),
        body: jsonEncode({
          'date_from': dateFrom,
          'date_to': dateTo,
          'sub_requisition_ids': subRequisitionIds,
        }),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'Tally export generated.',
        'data': json['data'],
      };
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  /// Get Settings
  static Future<Map<String, dynamic>?> getSettings() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/admin/settings'), headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return json['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Save Settings
  static Future<Map<String, dynamic>> saveSettings(Map<String, String> settingsMap) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/settings'),
        headers: _headers(),
        body: jsonEncode({'settings': settingsMap}),
      );
      final json = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true),
        'message': json['message'] ?? 'Settings updated.',
      };
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  /// Get Activity Logs
  static Future<List<ActivityLogItem>> getActivityLogs({String? search, int page = 1, int limit = 50}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/api/admin/activity-logs').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final list = json['data'] as List;
        return list.map((e) => ActivityLogItem.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get Reports
  static Future<Map<String, dynamic>?> getReports({
    required String dateFrom,
    required String dateTo,
    int? userId,
    int? locationId,
    int? materialId,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'date_from': dateFrom,
        'date_to': dateTo,
      };
      if (userId != null && userId > 0) queryParams['user_id'] = userId.toString();
      if (locationId != null && locationId > 0) queryParams['location_id'] = locationId.toString();
      if (materialId != null && materialId > 0) queryParams['material_id'] = materialId.toString();
      if (status != null && status.isNotEmpty && status != 'ALL') queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/api/admin/reports').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return json['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
