import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'local_db.dart';

/// Background sync engine that pushes local sessions to the server
/// and pulls fresh data when connectivity is available.
///
/// Replaces the old OfflineQueue with a proper bidirectional sync.
class SyncEngine {
  static Timer? _syncTimer;
  static bool _syncing = false;
  static StreamSubscription? _connectivitySub;

  /// Start the sync engine. Call once at app startup.
  static void start() {
    // Periodic sync every 30 seconds
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncAll());

    // Listen for connectivity changes
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        // Connectivity restored — sync immediately
        syncAll();
      }
    });
  }

  /// Stop the sync engine (e.g., on logout).
  static void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Push unsynced sessions to server and pull fresh data.
  static Future<SyncResult> syncAll() async {
    if (_syncing) return SyncResult(pushed: 0, pulled: 0, errors: 0);
    _syncing = true;

    int pushed = 0;
    int pulled = 0;
    int errors = 0;

    try {
      // ── PUSH: Upload unsynced sessions ──
      final unsynced = LocalDB.getUnsyncedSessions();
      for (final session in unsynced) {
        final localId = session['_localId']?.toString() ?? '';
        if (localId.isEmpty) continue;

        try {
          await LocalDB.updateSyncState(localId, SyncState.syncing);

          // Build clean payload (strip local-only fields)
          final payload = Map<String, dynamic>.from(session);
          payload.remove('_localId');
          payload.remove('_serverId');
          payload.remove('_syncState');
          payload.remove('_updatedAt');
          payload.remove('_id');
          payload.remove('__v');
          payload.remove('user');
          payload.remove('createdAt');
          payload.remove('updatedAt');

          // Ensure clientId for idempotency
          payload['clientId'] ??= const Uuid().v4();

          final serverId = session['_serverId']?.toString();
          Map<String, dynamic> result;

          if (serverId != null && serverId.isNotEmpty) {
            // Update existing server session
            result = await ApiService.updateSession(serverId, payload);
          } else {
            // Create new session on server
            result = await ApiService.createSession(payload);
          }

          final newServerId = result['_id']?.toString() ?? '';
          await LocalDB.updateSyncState(localId, SyncState.synced, serverId: newServerId);
          pushed++;
        } catch (e) {
          await LocalDB.updateSyncState(localId, SyncState.failed);
          errors++;
        }
      }

      // ── PULL: Download latest sessions from server ──
      try {
        final serverSessions = await ApiService.getSessions();
        await LocalDB.replaceServerSessions(
          serverSessions.map((s) => Map<String, dynamic>.from(s as Map)).toList(),
        );
        pulled = serverSessions.length;
      } catch (_) {
        // Pull failed — not critical, local data is still valid
      }
    } finally {
      _syncing = false;
    }

    return SyncResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  /// Check if we're currently syncing.
  static bool get isSyncing => _syncing;

  /// Get number of items pending sync.
  static int get pendingCount => LocalDB.getUnsyncedCount();
}

/// Result of a sync operation.
class SyncResult {
  final int pushed;
  final int pulled;
  final int errors;

  SyncResult({required this.pushed, required this.pulled, required this.errors});

  bool get hasErrors => errors > 0;
  bool get hadChanges => pushed > 0 || pulled > 0;
}
