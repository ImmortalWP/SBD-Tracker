import { useState, useEffect } from 'react';
import { HiStatusOffline, HiRefresh, HiCheckCircle, HiExclamationCircle } from 'react-icons/hi';
import { onSyncStatus, syncNow } from '../utils/syncEngine';
import { getQueueLength } from '../utils/offlineQueue';

export default function OfflineBanner() {
  const [online, setOnline] = useState(navigator.onLine);
  const [syncStatus, setSyncStatus] = useState('idle');
  const [queueCount, setQueueCount] = useState(getQueueLength());

  useEffect(() => {
    const handleOnline = () => setOnline(true);
    const handleOffline = () => setOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    const unsub = onSyncStatus((status) => {
      setSyncStatus(status);
      setQueueCount(getQueueLength());
    });

    // Poll queue length while offline
    const interval = setInterval(() => {
      setQueueCount(getQueueLength());
    }, 2000);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
      unsub();
      clearInterval(interval);
    };
  }, []);

  // Nothing to show
  if (online && syncStatus === 'idle' && queueCount === 0) return null;

  // Synced flash
  if (syncStatus === 'synced') {
    return (
      <div className="bg-accent-green/15 border-b border-accent-green/25 px-4 py-2 flex items-center justify-center gap-2 animate-fade-in">
        <HiCheckCircle className="text-accent-green text-base" />
        <span className="text-xs font-semibold text-accent-green">
          All changes synced!
        </span>
      </div>
    );
  }

  // Error flash
  if (syncStatus === 'error') {
    return (
      <div className="bg-red-500/15 border-b border-red-500/25 px-4 py-2 flex items-center justify-center gap-2 animate-fade-in">
        <HiExclamationCircle className="text-red-400 text-base" />
        <span className="text-xs font-semibold text-red-400">
          Some changes failed to sync
        </span>
      </div>
    );
  }

  // Syncing
  if (syncStatus === 'syncing') {
    return (
      <div className="bg-accent-amber/15 border-b border-accent-amber/25 px-4 py-2 flex items-center justify-center gap-2 animate-fade-in">
        <HiRefresh className="text-accent-amber text-base animate-spin" />
        <span className="text-xs font-semibold text-accent-amber">
          Syncing {queueCount} change{queueCount !== 1 ? 's' : ''}...
        </span>
      </div>
    );
  }

  // Offline
  if (!online) {
    return (
      <div className="bg-gym-800/80 border-b border-gym-700/50 px-4 py-2 flex items-center justify-center gap-2 animate-fade-in">
        <HiStatusOffline className="text-gym-400 text-base" />
        <span className="text-xs font-semibold text-gym-400">
          You're offline
          {queueCount > 0
            ? ` — ${queueCount} change${queueCount !== 1 ? 's' : ''} will sync when reconnected`
            : ' — cached data shown'}
        </span>
      </div>
    );
  }

  // Online but has queued items (shouldn't happen long, sync will start)
  if (queueCount > 0) {
    return (
      <div className="bg-accent-amber/10 border-b border-accent-amber/20 px-4 py-2 flex items-center justify-center gap-2 animate-fade-in">
        <HiRefresh className="text-accent-amber text-base" />
        <span className="text-xs font-semibold text-accent-amber">
          {queueCount} pending change{queueCount !== 1 ? 's' : ''}
        </span>
        <button
          onClick={syncNow}
          className="text-xs font-bold text-accent-amber underline underline-offset-2 hover:text-accent-red transition-colors"
        >
          Sync now
        </button>
      </div>
    );
  }

  return null;
}
