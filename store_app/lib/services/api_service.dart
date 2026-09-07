import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'onesignal_service.dart';

class ApiService {
  static const String baseUrl = 'https://req.gunayatangatepass.com';

  static const String keyToken = 'store_api_token';
  static const String keyUser = 'store_user_profile';

  static String? _cachedToken;
  static StoreUser? _currentUser;

  static StoreUser? get currentUser => _currentUser;
  static String? get token => _cachedToken;

  /// Headers helper
  static Map<String, String> _headers({bool withAuth = true}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && _cachedToken != null) {
      map['Authorization'] = 'Bearer $_cachedToken';
    }
    return map;
  }

  /// Store Keeper Login
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers(withAuth: false),
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          'device_name': 'Store Terminal Mobile',
        }),
      );

      final json = jsonDecode(res.body);
      final isSuccess = res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true);
      if (isSuccess) {
        final data = json['data'];
        final userObj = StoreUser.fromJson(data['user']);

        // Verify role
        if (!['SUPER_ADMIN', 'ADMIN', 'STORE_USER'].contains(userObj.role)) {
          return {
            'success': false,
            'message': 'Access Denied: This app is only for Store Keepers and Warehouse Admins.',
          };
        }

        _cachedToken = data['token'];
        _currentUser = userObj;

        // Persist token, user and credentials for quick screen lock unlock
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyToken, _cachedToken!);
        await prefs.setString(keyUser, jsonEncode(userObj.toJson()));
        await prefs.setString('saved_store_identifier', identifier);
        await prefs.setString('saved_store_secret', base64Encode(utf8.encode(password)));

        // Bind with OneSignal
        OneSignalNotificationService.login(userObj.id.toString());

        return {
          'success': true,
          'user': userObj,
          'message': json['message'] ?? 'Login successful',
        };
      }

      return {
        'success': false,
        'message': json['message'] ?? 'Invalid credentials',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Quick Login with Saved Session & Device Lock
  static Future<bool> loginWithSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final identifier = prefs.getString('saved_store_identifier');
    final secretEncoded = prefs.getString('saved_store_secret');

    // 1. Primary: Re-authenticate with server to get fresh active token
    if (identifier != null && secretEncoded != null) {
      try {
        final password = utf8.decode(base64Decode(secretEncoded));
        final res = await login(identifier, password);
        if (res['success'] == true) {
          return true;
        }
      } catch (_) {}
    }

    // 2. Fallback: Check if existing saved token is still valid
    return await restoreSession();
  }

  /// Check Stored Token and Restore Session
  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(keyToken);
    final userJson = prefs.getString(keyUser);

    if (token != null && userJson != null) {
      _cachedToken = token;
      try {
        _currentUser = StoreUser.fromJson(jsonDecode(userJson));
        // Validate with server
        final res = await http.get(
          Uri.parse('$baseUrl/api/auth/me'),
          headers: _headers(),
        );
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          if (json['status'] == 'success' || json['success'] == true) {
            _currentUser = StoreUser.fromJson(json['data']['user']);
            OneSignalNotificationService.login(_currentUser!.id.toString());
            return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  /// Get Last Saved User for Biometric Screen Lock
  static Future<StoreUser?> getLastSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(keyUser);
    if (userJson != null) {
      try {
        return StoreUser.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }
    return null;
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

    OneSignalNotificationService.logout();
  }

  /// Get Store Live Feed
  static Future<Map<String, dynamic>> getFeed({
    String? date,
    int? locationId,
    String? status,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (locationId != null && locationId > 0) params['location_id'] = locationId.toString();
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$baseUrl/api/store/feed').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers());

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final data = json['data'];
        final items = (data['items'] as List?)?.map((i) => StoreItem.fromJson(i)).toList() ?? [];
        final stats = FeedStats.fromJson(data['stats'] ?? {});
        final locations = (data['locations'] as List?)?.map((l) => LocationItem.fromJson(l)).toList() ?? [];
        final timing = data['timing'] as Map<String, dynamic>?;

        return {
          'success': true,
          'items': items,
          'stats': stats,
          'locations': locations,
          'timing': timing,
        };
      }

      return {'success': false, 'message': json['message'] ?? 'Failed to load store feed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Single Item Action (Full Issue, Partial Issue, Not Available)
  static Future<Map<String, dynamic>> processItemAction({
    required int itemId,
    required String actionType, // 'FULL_ISSUE', 'PARTIAL_ISSUE', 'NOT_AVAILABLE'
    double issuedQuantity = 0,
    String? remark,
  }) async {
    try {
      String endpoint = '';
      final body = <String, dynamic>{'remark': remark};

      if (actionType == 'FULL_ISSUE') {
        endpoint = '$baseUrl/api/store/items/$itemId/issue';
      } else if (actionType == 'PARTIAL_ISSUE') {
        endpoint = '$baseUrl/api/store/items/$itemId/partial';
        body['issued_quantity'] = issuedQuantity;
      } else {
        endpoint = '$baseUrl/api/store/items/$itemId/not-available';
      }

      final res = await http.post(
        Uri.parse(endpoint),
        headers: _headers(),
        body: jsonEncode(body),
      );

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return {'success': true, 'data': json['data'], 'message': json['message']};
      }

      return {'success': false, 'message': json['message'] ?? 'Action failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Batch Issue Multiple Items
  static Future<Map<String, dynamic>> batchAction({
    required List<int> itemIds,
    String actionType = 'FULL_ISSUE',
    String? remark,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/store/batch-action'),
        headers: _headers(),
        body: jsonEncode({
          'item_ids': itemIds,
          'action_type': actionType,
          'remark': remark,
        }),
      );

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return {'success': true, 'data': json['data'], 'message': json['message']};
      }

      return {'success': false, 'message': json['message'] ?? 'Batch action failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get Emergency Options (Users, Locations, Materials with Stock)
  static Future<Map<String, dynamic>> getEmergencyOptions() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/store/emergency/options'),
        headers: _headers(),
      );

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final data = json['data'];
        final users = (data['users'] as List?)?.map((u) => TargetUser.fromJson(u)).toList() ?? [];
        final locations = (data['locations'] as List?)?.map((l) => LocationItem.fromJson(l)).toList() ?? [];
        final materials = (data['materials'] as List?)?.map((m) => StockMaterial.fromJson(m)).toList() ?? [];

        return {
          'success': true,
          'users': users,
          'locations': locations,
          'materials': materials,
        };
      }
      return {'success': false, 'message': json['message'] ?? 'Failed to load options'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Create Emergency Issue (Single or Bulk)
  static Future<Map<String, dynamic>> createEmergencyIssue({
    required int userId,
    required int locationId,
    required int materialId,
    required double quantity,
    required String reason,
    String? remark,
  }) async {
    return createBulkEmergencyIssue(
      userId: userId,
      locationId: locationId,
      reason: reason,
      remark: remark,
      items: [
        {
          'material_id': materialId,
          'quantity': quantity,
          'remark': remark,
        }
      ],
    );
  }

  /// Create Bulk Emergency Issue
  static Future<Map<String, dynamic>> createBulkEmergencyIssue({
    required int userId,
    required int locationId,
    required String reason,
    required List<Map<String, dynamic>> items,
    String? remark,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/store/emergency'),
        headers: _headers(),
        body: jsonEncode({
          'user_id': userId,
          'location_id': locationId,
          'reason': reason,
          'remark': remark,
          'items': items,
        }),
      );

      final json = jsonDecode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && (json['status'] == 'success' || json['success'] == true)) {
        return {'success': true, 'data': json['data'], 'message': json['message']};
      }

      return {'success': false, 'message': json['message'] ?? 'Emergency issue failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get Live Stock Inventory
  static Future<Map<String, dynamic>> getStock({String? search, String? category}) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (category != null && category.isNotEmpty) params['category'] = category;

      final uri = Uri.parse('$baseUrl/api/store/stock').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers());

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final data = json['data'];
        final materials = (data['materials'] as List?)?.map((m) => StockMaterial.fromJson(m)).toList() ?? [];
        final categories = (data['categories'] as List?)?.map((c) => c.toString()).toList() ?? [];

        return {
          'success': true,
          'materials': materials,
          'categories': categories,
        };
      }

      return {'success': false, 'message': json['message'] ?? 'Failed to load stock'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Change Password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/user/change-password'),
        headers: _headers(),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );

      final json = jsonDecode(res.body);
      final isSuccess = res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true);
      return {
        'success': isSuccess,
        'message': json['message'] ?? 'Password update failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get Store Issue History
  static Future<Map<String, dynamic>> getHistory({
    String? dateFrom,
    String? dateTo,
    String? status,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final uri = Uri.parse('$baseUrl/api/store/history').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers());

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        final data = json['data'];
        final items = (data['items'] as List?)?.map((i) => StoreItem.fromJson(i)).toList() ?? [];
        return {
          'success': true,
          'items': items,
          'total_count': data['total_count'] ?? 0,
          'total_pages': data['total_pages'] ?? 1,
        };
      }
      return {'success': false, 'message': json['message'] ?? 'Failed to load history'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get 360 Material Details & Audit Logs
  static Future<Map<String, dynamic>> getMaterialDetails(int materialId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/store/materials/$materialId/details'),
        headers: _headers(),
      );

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return {
          'success': true,
          'data': json['data'] ?? {},
        };
      }
      return {'success': false, 'message': json['message'] ?? 'Failed to load material details'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update Material Physical Stock Balance & Master Info
  static Future<Map<String, dynamic>> updateMaterialStock({
    required int materialId,
    required double currentStock,
    String? name,
    String? code,
    String? unit,
    double? defaultRate,
    int? categoryId,
    String? reason,
    bool updateMaster = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'current_stock': currentStock,
        'reason': reason ?? 'Physical stock count updated from Store Mobile App',
        'update_master': updateMaster,
      };
      if (name != null) payload['name'] = name;
      if (code != null) payload['code'] = code;
      if (unit != null) payload['unit'] = unit;
      if (defaultRate != null) payload['default_rate'] = defaultRate;
      if (categoryId != null) payload['category_id'] = categoryId;

      final res = await http.post(
        Uri.parse('$baseUrl/api/store/materials/$materialId/update-stock'),
        headers: _headers(),
        body: jsonEncode(payload),
      );

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['status'] == 'success' || json['success'] == true)) {
        return {
          'success': true,
          'message': json['message'] ?? 'Stock updated successfully',
          'data': json['data'] ?? {},
        };
      }
      return {'success': false, 'message': json['message'] ?? 'Failed to update stock'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}

