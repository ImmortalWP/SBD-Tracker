import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://sbd-tracker.onrender.com/api';
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxRetries = 2;

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }


  /// Execute a request with timeout and retry logic.
  static Future<http.Response> _execute(
    Future<http.Response> Function() request, {
    int retries = _maxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await request().timeout(_timeout);
      } on TimeoutException {
        attempt++;
        if (attempt > retries) {
          throw Exception('Request timed out. Check your connection.');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } on Exception catch (e) {
        final msg = e.toString();
        if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('Connection')) {
          attempt++;
          if (attempt > retries) rethrow;
          await Future.delayed(Duration(seconds: attempt * 2));
        } else {
          rethrow;
        }
      }
    }
  }

  // Auth
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _execute(() => http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ), retries: 1);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> register(String username, String password) async {
    final res = await _execute(() => http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ), retries: 1);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Registration failed');
  }

  // Sessions
  static Future<List<dynamic>> getSessions({int? block, String? day}) async {
    final params = <String, String>{};
    if (block != null) params['block'] = block.toString();
    if (day != null) params['day'] = day;
    final uri = Uri.parse('$baseUrl/sessions').replace(queryParameters: params.isEmpty ? null : params);
    final res = await _execute(() => http.get(uri, headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load sessions');
  }

  static Future<Map<String, dynamic>> getSession(String id) async {
    final res = await _execute(() => http.get(Uri.parse('$baseUrl/sessions/$id'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Session not found');
  }

  static Future<Map<String, dynamic>> createSession(Map<String, dynamic> data) async {
    final res = await _execute(() => http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to create');
  }

  static Future<Map<String, dynamic>> updateSession(String id, Map<String, dynamic> data) async {
    final res = await _execute(() => http.put(
      Uri.parse('$baseUrl/sessions/$id'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update');
  }

  static Future<void> deleteSession(String id) async {
    final res = await _execute(() => http.delete(Uri.parse('$baseUrl/sessions/$id'), headers: _headersSync()));
    if (res.statusCode != 200) throw Exception('Failed to delete');
  }

  // Stats
  static Future<Map<String, dynamic>> getPRs() async {
    final res = await _execute(() => http.get(Uri.parse('$baseUrl/sessions/stats/prs'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load PRs');
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final res = await _execute(() => http.get(Uri.parse('$baseUrl/sessions/stats/analytics'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load analytics');
  }

  // Leaderboard
  static Future<List<dynamic>> getLeaderboard() async {
    final res = await _execute(() => http.get(Uri.parse('$baseUrl/leaderboard'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load leaderboard');
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await _execute(() => http.get(Uri.parse('$baseUrl/profile'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load profile');
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _execute(() => http.put(
      Uri.parse('$baseUrl/profile'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update profile');
  }

  // Synchronous headers helper — for use inside _execute callbacks
  // We cache _prefs so this is safe after first call
  static Map<String, String> _headersSync() {
    final token = _prefs?.getString('sbd_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Call once at app startup to pre-load prefs
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
}
