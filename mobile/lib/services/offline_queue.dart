import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineQueue {
  static const _key = 'sbd_offline_queue';

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(queue));
  }

  static Future<void> enqueue(Map<String, dynamic> action) async {
    final queue = await getQueue();
    queue.add({
      ...action,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _saveQueue(queue);
  }

  static Future<int> getLength() async {
    return (await getQueue()).length;
  }

  static Future<void> syncAll() async {
    final queue = await getQueue();
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];

    for (final item in queue) {
      try {
        switch (item['type']) {
          case 'create':
            await ApiService.createSession(Map<String, dynamic>.from(item['data']));
            break;
          case 'update':
            await ApiService.updateSession(item['sessionId'], Map<String, dynamic>.from(item['data']));
            break;
          case 'delete':
            await ApiService.deleteSession(item['sessionId']);
            break;
        }
      } catch (e) {
        // Keep failed items for retry
        remaining.add(item);
      }
    }

    await _saveQueue(remaining);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
