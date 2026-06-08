import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineQueue {
  static const _key = 'sbd_offline_queue';
  static const int _maxRetries = 3;
  static const int _maxQueueSize = 50;

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

    // Deduplicate: if a 'create' action with the same clientId is already queued, skip
    if (action['type'] == 'create') {
      final clientId = (action['data'] as Map<String, dynamic>?)?['clientId'];
      if (clientId != null) {
        final alreadyQueued = queue.any((item) =>
          item['type'] == 'create' &&
          (item['data'] as Map<String, dynamic>?)?['clientId'] == clientId);
        if (alreadyQueued) return; // Already in queue, don't add duplicate
      }
    }

    // Enforce max queue size
    if (queue.length >= _maxQueueSize) {
      queue.removeAt(0); // Drop oldest
    }
    queue.add({
      ...action,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
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
      final retries = (item['retries'] as int?) ?? 0;

      // Skip items that have exceeded max retries
      if (retries >= _maxRetries) continue;

      // Prevent rapid retry loops — wait at least 30s between attempts
      final lastAttempt = item['lastAttempt'] as int?;
      if (lastAttempt != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastAttempt;
        if (elapsed < 30000) {
          remaining.add(item);
          continue;
        }
      }

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
        // Keep failed items for retry with incremented count
        remaining.add({
          ...item,
          'retries': retries + 1,
          'lastAttempt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }

    await _saveQueue(remaining);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
