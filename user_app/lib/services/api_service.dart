import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'onesignal_service.dart';

class ApiService {
  // Production live backend API domain
  static String baseUrl = 'https://req.gunayatangatepass.com';
  
  static String? _token;
  static User? currentUser;

  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Real-time Event Notifier for instant cross-screen sync
  static final ValueNotifier<int> dataChangeNotifier = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    dataChangeNotifier.value++;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        currentUser = User.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Check if Device Lock / Biometrics is supported on this phone
  static Future<bool> isDeviceLockSupported() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported || canCheck;
    } catch (_) {
      return true;
    }
  }

  // Get Last Saved User for Quick Device Lock Login
  static Future<User?> getLastSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('saved_user_profile');
    if (userJson != null) {
      try {
        return User.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }
    return null;
  }

  // Prompt Native Device Screen Lock (PIN, Pattern, Fingerprint, Face ID)
  static Future<bool> authenticateWithDeviceLock() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock using Screen Lock or Fingerprint to open Store Requisition',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allows PIN, Pattern, Fingerprint, Face Unlock
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // Quick Login with Saved Session & Device Lock
  static Future<bool> loginWithSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final identifier = prefs.getString('saved_identifier');
    final secretEncoded = prefs.getString('saved_secret');

    // 1. Primary: Re-authenticate with server to get fresh active token & live user data
    if (identifier != null && secretEncoded != null) {
      try {
        final password = utf8.decode(base64Decode(secretEncoded));
        final res = await login(identifier, password);
        if (res['success'] == true) {
          return true;
        }
      } catch (_) {}
    }

    // 2. Fallback: Check if existing saved token is still valid on backend
    final token = prefs.getString('api_token');
    final userJson = prefs.getString('saved_user_profile');

    if (token != null && userJson != null) {
      try {
        _token = token;
        currentUser = User.fromJson(jsonDecode(userJson));

        // Test token validity with /api/auth/me
        final meRes = await http.get(Uri.parse('$baseUrl/api/auth/me'), headers: _headers);
        final meData = jsonDecode(meRes.body);
        if (meData['success'] == true) {
          await prefs.setString('current_user', userJson);
          OneSignalNotificationService.login(currentUser!.id.toString());
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  // Auth: Login
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          'device_name': 'Flutter Android App',
        }),
      );

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _token = data['data']['token'];
        currentUser = User.fromJson(data['data']['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_token', _token!);
        await prefs.setString('current_user', jsonEncode(currentUser!.toJson()));
        await prefs.setString('saved_user_profile', jsonEncode(currentUser!.toJson()));
        await prefs.setString('saved_identifier', identifier);
        await prefs.setString('saved_secret', base64Encode(utf8.encode(password)));

        // Link device in OneSignal (Strict 1-to-1 targeting)
        OneSignalNotificationService.login(currentUser!.id.toString());

        return {'success': true, 'message': 'Login successful'};
      }
      return {'success': false, 'message': data['message'] ?? 'Invalid credentials'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Auth: Logout
  static Future<void> logout() async {
    // Unlink device in OneSignal
    OneSignalNotificationService.logout();

    try {
      if (_token != null) {
        await http.post(Uri.parse('$baseUrl/api/auth/logout'), headers: _headers);
      }
    } catch (_) {}
    _token = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('api_token');
    // Note: saved_user_profile, saved_identifier, saved_secret are kept for Quick Device Lock login
  }

  // Get Today's Requisition & Dashboard
  static Future<Map<String, dynamic>?> getDashboard() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/user/dashboard'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get Today's Master Requisition Model
  static Future<MasterRequisitionModel?> getTodayRequisition() async {
    final data = await getDashboard();
    if (data != null && data['today_requisition'] != null) {
      try {
        return MasterRequisitionModel.fromJson(data['today_requisition']);
      } catch (_) {}
    }
    return null;
  }

  // Get Searchable Materials
  static Future<List<MaterialItem>> getMaterials([String query = '']) async {
    try {
      final uri = Uri.parse('$baseUrl/api/user/materials${query.isNotEmpty ? '?q=$query' : ''}');
      final res = await http.get(uri, headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        var list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((e) => MaterialItem.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get Locations
  static Future<List<LocationItem>> getLocations() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/user/locations'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        var list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((e) => LocationItem.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Add Item to today's Master Requisition
  static Future<Map<String, dynamic>> addItem({
    required int materialId,
    required double quantity,
    required int locationId,
    String? remark,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/user/requisition/items'),
        headers: _headers,
        body: jsonEncode({
          'material_id': materialId,
          'quantity': quantity,
          'location_id': locationId,
          'remark': remark,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        notifyDataChanged();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network connection error: $e'};
    }
  }

  // Add Bulk Items in one network batch
  static Future<Map<String, dynamic>> addBulkItems(List<Map<String, dynamic>> items) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/user/requisition/items/bulk'),
        headers: _headers,
        body: jsonEncode({'items': items}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        notifyDataChanged();
        return data;
      }

      // Fallback: if bulk endpoint reported an issue, try sequential submission
      int successCount = 0;
      for (final it in items) {
        final r = await addItem(
          materialId: it['material_id'],
          quantity: it['quantity'],
          locationId: it['location_id'],
          remark: it['remark'],
        );
        if (r['success'] == true) successCount++;
      }
      if (successCount > 0) {
        notifyDataChanged();
        return {'success': true, 'message': '$successCount items submitted successfully!'};
      }
      return data;
    } catch (e) {
      // Fallback: add sequentially on network/exception
      int successCount = 0;
      for (final it in items) {
        final r = await addItem(
          materialId: it['material_id'],
          quantity: it['quantity'],
          locationId: it['location_id'],
          remark: it['remark'],
        );
        if (r['success'] == true) successCount++;
      }
      if (successCount > 0) {
        notifyDataChanged();
        return {'success': true, 'message': '$successCount items added successfully!'};
      }
      return {'success': false, 'message': 'Error adding bulk items: $e'};
    }
  }

  // Get User Live In-App Notifications
  static Future<List<dynamic>> getNotifications() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/user/notifications'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'] as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Update Pending Item
  static Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required double quantity,
    required int locationId,
    String? remark,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/user/requisition/items/$itemId'),
        headers: _headers,
        body: jsonEncode({
          'quantity': quantity,
          'location_id': locationId,
          'remark': remark,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        notifyDataChanged();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network connection error: $e'};
    }
  }

  // Delete Pending Item
  static Future<Map<String, dynamic>> deleteItem(int itemId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/user/requisition/items/$itemId'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        notifyDataChanged();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network error deleting item: $e'};
    }
  }

  // Get User History
  static Future<List<dynamic>> getHistory([int page = 1]) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/user/requisition/history?page=$page'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data']['items'] is List) {
          return data['data']['items'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get Requisition Details by ID
  static Future<MasterRequisitionModel?> getRequisitionDetails(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/user/requisition/$id'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true && data['data'] != null) {
        return MasterRequisitionModel.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Change Password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/user/change-password'),
        headers: _headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_secret', base64Encode(utf8.encode(newPassword)));
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network connection error: $e'};
    }
  }

  // Get User Profile Lifetime Stats
  static Future<Map<String, dynamic>?> getProfileStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/user/profile-stats'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
