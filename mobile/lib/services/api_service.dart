import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://sbd-tracker.onrender.com/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sbd_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> register(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
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
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load sessions');
  }

  static Future<Map<String, dynamic>> getSession(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/sessions/$id'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Session not found');
  }

  static Future<Map<String, dynamic>> createSession(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to create');
  }

  static Future<Map<String, dynamic>> updateSession(String id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/sessions/$id'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update');
  }

  static Future<void> deleteSession(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/sessions/$id'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to delete');
  }

  // Stats
  static Future<Map<String, dynamic>> getPRs() async {
    final res = await http.get(Uri.parse('$baseUrl/sessions/stats/prs'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load PRs');
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final res = await http.get(Uri.parse('$baseUrl/sessions/stats/analytics'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load analytics');
  }

  // Leaderboard
  static Future<List<dynamic>> getLeaderboard() async {
    final res = await http.get(Uri.parse('$baseUrl/leaderboard'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load leaderboard');
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(Uri.parse('$baseUrl/profile'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load profile');
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/profile'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to update profile');
  }
}
