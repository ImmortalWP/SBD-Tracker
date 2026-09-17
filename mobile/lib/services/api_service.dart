import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_token_storage.dart';

class ApiService {
  static const String baseUrl = 'https://sbd-tracker.onrender.com/api';
  static const Duration _readTimeout = Duration(seconds: 15);
  static const Duration _writeTimeout = Duration(seconds: 60);
  static const int _maxRetries = 2;

  // Non-sensitive cache still uses SharedPreferences
  static SharedPreferences? _prefs;

  // Token cached in memory after loading from secure storage
  // Never persisted in SharedPreferences
  static String? _cachedToken;

  /// Set the cached token (called by AuthService on login/logout)
  static void setCachedToken(String? token) {
    _cachedToken = token;
  }

  /// Wake the Render server by pinging /api/health.
  /// Returns true if the server responded, false on error (non-fatal).
  static Future<bool> _wakeUpServer() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 60));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Execute a **read** request with timeout and retry logic.
  /// Safe to retry because reads are idempotent.
  static Future<http.Response> _executeRead(
    Future<http.Response> Function() request, {
    int retries = _maxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await request().timeout(_readTimeout);
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

  /// Execute a **write** request (POST/PUT/DELETE) with NO retries.
  /// Wakes the server first, then sends the request with a long timeout.
  /// On failure, the caller should queue to OfflineQueue instead of retrying.
  static Future<http.Response> _executeWrite(
    Future<http.Response> Function() request,
  ) async {
    // Wake up the server first (best-effort, non-blocking on failure)
    await _wakeUpServer();

    try {
      return await request().timeout(_writeTimeout);
    } on TimeoutException {
      throw Exception('Request timed out. The server may be starting up.');
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('Connection')) {
        throw Exception('Connection failed. Session saved offline.');
      }
      rethrow;
    }
  }

  // Auth — these don't need auth headers
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _executeRead(() => http.post(
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
    final res = await _executeRead(() => http.post(
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
    final res = await _executeRead(() => http.get(uri, headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load sessions');
  }

  static Future<Map<String, dynamic>> getSession(String id) async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/sessions/$id'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Session not found');
  }

  static Future<Map<String, dynamic>> createSession(Map<String, dynamic> data) async {
    final res = await _executeWrite(() => http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    // 201 = new session created, 200 = idempotent duplicate (server returned existing)
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to create');
  }

  static Future<Map<String, dynamic>> updateSession(String id, Map<String, dynamic> data) async {
    final res = await _executeWrite(() => http.put(
      Uri.parse('$baseUrl/sessions/$id'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update');
  }

  static Future<void> deleteSession(String id) async {
    final res = await _executeWrite(() => http.delete(Uri.parse('$baseUrl/sessions/$id'), headers: _headersSync()));
    if (res.statusCode != 200) throw Exception('Failed to delete');
  }

  // Stats
  static Future<Map<String, dynamic>> getPRs() async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/sessions/stats/prs'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load PRs');
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/sessions/stats/analytics'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load analytics');
  }

  // Leaderboard
  static Future<List<dynamic>> getLeaderboard() async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/leaderboard'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load leaderboard');
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/profile'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load profile');
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _executeWrite(() => http.put(
      Uri.parse('$baseUrl/profile'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update profile');
  }

  static Future<List<dynamic>> addPR(Map<String, dynamic> data) async {
    final res = await _executeWrite(() => http.post(
      Uri.parse('$baseUrl/profile/prs'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('Failed to save PR');
  }

  // Programs
  static Future<List<dynamic>> getPrograms() async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/programs'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load programs');
  }

  static Future<Map<String, dynamic>> getProgram(String id) async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/programs/$id'), headers: _headersSync()));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load program');
  }

  static Future<Map<String, dynamic>?> getActiveProgram() async {
    final res = await _executeRead(() => http.get(Uri.parse('$baseUrl/programs/user/active'), headers: _headersSync()));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body == null) return null;
      return body;
    }
    throw Exception('Failed to load active program');
  }

  static Future<Map<String, dynamic>> startProgram(String id) async {
    final res = await _executeWrite(() => http.post(
      Uri.parse('$baseUrl/programs/$id/start'),
      headers: _headersSync(),
    ));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to start program');
  }

  static Future<void> stopProgram(String id) async {
    final res = await _executeWrite(() => http.post(
      Uri.parse('$baseUrl/programs/$id/stop'),
      headers: _headersSync(),
    ));
    if (res.statusCode != 200) throw Exception('Failed to stop program');
  }

  static Future<Map<String, dynamic>> updateProgramProgress(String id, {int? currentWeek, int? currentDay}) async {
    final data = <String, dynamic>{};
    if (currentWeek != null) data['currentWeek'] = currentWeek;
    if (currentDay != null) data['currentDay'] = currentDay;
    final res = await _executeWrite(() => http.put(
      Uri.parse('$baseUrl/programs/$id/progress'),
      headers: _headersSync(),
      body: jsonEncode(data),
    ));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update progress');
  }

  // Headers helper — uses in-memory cached token (loaded from secure storage)
  // Never reads token from SharedPreferences
  static Map<String, String> _headersSync() {
    return {
      'Content-Type': 'application/json',
      if (_cachedToken != null) 'Authorization': 'Bearer $_cachedToken',
    };
  }

  /// Call once at app startup to pre-load prefs and token from secure storage
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Load token from secure storage into memory cache
    _cachedToken = await SecureTokenStorage.getToken();
  }
}
