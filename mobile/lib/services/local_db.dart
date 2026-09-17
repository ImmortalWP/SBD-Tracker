import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Sync state for locally stored records.
enum SyncState { pending, syncing, synced, failed }

/// Local database backed by Hive for offline-first session storage.
/// 
/// Architecture:
///   Flutter UI → Repository → LocalDB → SyncEngine → Backend API → MongoDB
///
/// Sessions are saved locally first, displayed immediately, and synced
/// in the background when connectivity is available.
class LocalDB {
  static const String _sessionsBox = 'sessions';
  static const String _metaBox = 'meta';
  static bool _initialized = false;

  /// Initialize Hive and open boxes. Call once at app startup.
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox<Map>(_sessionsBox);
    await Hive.openBox(_metaBox);
    _initialized = true;
  }

  // ─── Sessions ───

  /// Save a session locally. If serverId is null, it's a new local-only session.
  static Future<void> saveSession(String localId, Map<String, dynamic> data, {
    String? serverId,
    SyncState syncState = SyncState.pending,
  }) async {
    final box = Hive.box<Map>(_sessionsBox);
    await box.put(localId, {
      ...data,
      '_localId': localId,
      if (serverId != null) '_serverId': serverId,
      '_syncState': syncState.name,
      '_updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get a session by local ID.
  static Map<String, dynamic>? getSession(String localId) {
    final box = Hive.box<Map>(_sessionsBox);
    final raw = box.get(localId);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Get all locally stored sessions, sorted by date descending.
  static List<Map<String, dynamic>> getAllSessions() {
    final box = Hive.box<Map>(_sessionsBox);
    final sessions = box.values
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
    
    sessions.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });
    
    return sessions;
  }

  /// Get sessions that need syncing (pending or failed).
  static List<Map<String, dynamic>> getUnsyncedSessions() {
    final box = Hive.box<Map>(_sessionsBox);
    return box.values
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((s) {
          final state = s['_syncState']?.toString() ?? 'pending';
          return state == 'pending' || state == 'failed';
        })
        .toList();
  }

  /// Mark a session's sync state.
  static Future<void> updateSyncState(String localId, SyncState state, {String? serverId}) async {
    final box = Hive.box<Map>(_sessionsBox);
    final raw = box.get(localId);
    if (raw == null) return;
    final data = Map<String, dynamic>.from(raw);
    data['_syncState'] = state.name;
    if (serverId != null) data['_serverId'] = serverId;
    data['_updatedAt'] = DateTime.now().toIso8601String();
    await box.put(localId, data);
  }

  /// Delete a session locally.
  static Future<void> deleteSession(String localId) async {
    final box = Hive.box<Map>(_sessionsBox);
    await box.delete(localId);
  }

  /// Replace all local sessions with fresh data from the server.
  /// Preserves any unsynced local sessions that aren't on the server yet.
  static Future<void> replaceServerSessions(List<Map<String, dynamic>> serverSessions) async {
    final box = Hive.box<Map>(_sessionsBox);
    
    // Preserve unsynced local sessions
    final unsynced = getUnsyncedSessions();
    final unsyncedIds = unsynced.map((s) => s['_localId']).toSet();
    
    // Clear and rebuild
    await box.clear();
    
    // Re-add server sessions (keyed by server _id)
    for (final s in serverSessions) {
      final serverId = s['_id']?.toString() ?? '';
      if (serverId.isEmpty) continue;
      await box.put(serverId, {
        ...s,
        '_localId': serverId,
        '_serverId': serverId,
        '_syncState': SyncState.synced.name,
        '_updatedAt': DateTime.now().toIso8601String(),
      });
    }
    
    // Re-add unsynced sessions that weren't matched by server
    for (final s in unsynced) {
      final localId = s['_localId']?.toString() ?? '';
      if (localId.isNotEmpty && !box.containsKey(localId)) {
        await box.put(localId, s);
      }
    }
  }

  /// Count of unsynced sessions.
  static int getUnsyncedCount() {
    return getUnsyncedSessions().length;
  }

  // ─── Meta / Settings ───

  /// Save a key-value pair.
  static Future<void> setMeta(String key, dynamic value) async {
    final box = Hive.box(_metaBox);
    await box.put(key, value);
  }

  /// Get a meta value.
  static T? getMeta<T>(String key) {
    final box = Hive.box(_metaBox);
    return box.get(key) as T?;
  }

  /// Clear all data (for logout).
  static Future<void> clearAll() async {
    if (!_initialized) return;
    await Hive.box<Map>(_sessionsBox).clear();
    await Hive.box(_metaBox).clear();
  }
}
