/**
 * Sync engine: replays queued offline mutations when connectivity returns.
 * 
 * Usage:
 *   import { initSync, syncNow, onSyncStatus } from './syncEngine';
 *   initSync();  // call once at app start
 *   onSyncStatus((status) => ...);  // 'idle' | 'syncing' | 'synced' | 'error'
 */

import API from '../api/sessions';
import { getQueue, dequeue, getQueueLength } from './offlineQueue';
import { cacheClearPattern } from './cache';

let statusListeners = [];
let currentStatus = 'idle';

function setStatus(status) {
  currentStatus = status;
  statusListeners.forEach((fn) => fn(status));
}

/**
 * Subscribe to sync status changes.
 * Returns an unsubscribe function.
 */
export function onSyncStatus(listener) {
  statusListeners.push(listener);
  // Send current status immediately
  listener(currentStatus);
  return () => {
    statusListeners = statusListeners.filter((fn) => fn !== listener);
  };
}

/**
 * Get current sync status.
 */
export function getSyncStatus() {
  return currentStatus;
}

/**
 * Replay all queued mutations.
 */
export async function syncNow() {
  if (!navigator.onLine) return;

  const queueLength = getQueueLength();
  if (queueLength === 0) return;

  setStatus('syncing');

  let synced = 0;
  let errors = 0;

  while (getQueueLength() > 0) {
    const queue = getQueue();
    const item = queue[0];

    try {
      switch (item.type) {
        case 'create':
          await API.post(item.url, item.data);
          break;
        case 'update':
          await API.put(item.url, item.data);
          break;
        case 'delete':
          await API.delete(item.url);
          break;
        default:
          console.warn('Unknown queue item type:', item.type);
      }
      dequeue();
      synced++;
    } catch (err) {
      // If it's a network error, stop trying
      if (!navigator.onLine || !err.response) {
        setStatus('idle');
        return;
      }
      // If it's a server error (4xx/5xx), skip this item to avoid infinite loop
      console.error('Sync failed for item:', item, err.response?.data);
      dequeue();
      errors++;
    }
  }

  // Invalidate caches so fresh data is fetched
  cacheClearPattern('sessions');
  cacheClearPattern('stats');
  cacheClearPattern('leaderboard');

  if (errors > 0) {
    setStatus('error');
  } else {
    setStatus('synced');
  }

  // Reset to idle after a brief flash
  setTimeout(() => setStatus('idle'), 3000);
}

/**
 * Initialize the sync engine. Call once at app start.
 * Listens for online events and auto-syncs.
 */
export function initSync() {
  // Sync on reconnect
  window.addEventListener('online', () => {
    syncNow();
  });

  // Try syncing on start if we have queued items and are online
  if (navigator.onLine && getQueueLength() > 0) {
    // Small delay to let app finish mounting
    setTimeout(syncNow, 1000);
  }
}
