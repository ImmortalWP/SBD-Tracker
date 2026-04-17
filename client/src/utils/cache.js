/**
 * Lightweight localStorage cache for API responses.
 * Keys are namespaced with 'sbd_cache_' to avoid collisions.
 */

const PREFIX = 'sbd_cache_';

/**
 * Store data in cache with a timestamp.
 */
export function cacheSet(key, data) {
  try {
    const entry = {
      data,
      cachedAt: Date.now(),
    };
    localStorage.setItem(PREFIX + key, JSON.stringify(entry));
  } catch (e) {
    // localStorage full or unavailable — silently fail
    console.warn('Cache write failed:', e.message);
  }
}

/**
 * Retrieve cached data. Returns null if not found.
 * Always returns stale data (no expiry) — freshness is handled by background fetch.
 */
export function cacheGet(key) {
  try {
    const raw = localStorage.getItem(PREFIX + key);
    if (!raw) return null;
    const entry = JSON.parse(raw);
    return entry.data;
  } catch {
    return null;
  }
}

/**
 * Get cache metadata (timestamp).
 */
export function cacheGetMeta(key) {
  try {
    const raw = localStorage.getItem(PREFIX + key);
    if (!raw) return null;
    const entry = JSON.parse(raw);
    return { cachedAt: entry.cachedAt };
  } catch {
    return null;
  }
}

/**
 * Invalidate a specific cache key.
 */
export function cacheClear(key) {
  localStorage.removeItem(PREFIX + key);
}

/**
 * Invalidate all caches matching a prefix pattern.
 * e.g., cacheClearPattern('sessions') clears sessions, sessions_block_1, etc.
 */
export function cacheClearPattern(pattern) {
  const fullPrefix = PREFIX + pattern;
  const keys = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k && k.startsWith(fullPrefix)) {
      keys.push(k);
    }
  }
  keys.forEach((k) => localStorage.removeItem(k));
}

/**
 * Invalidate all SBD caches (e.g., on logout).
 */
export function cacheClearAll() {
  const keys = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k && k.startsWith(PREFIX)) {
      keys.push(k);
    }
  }
  keys.forEach((k) => localStorage.removeItem(k));
}

/**
 * Generate a deterministic cache key from URL + params.
 */
export function makeCacheKey(url, params) {
  if (!params || Object.keys(params).length === 0) return url;
  const sorted = Object.keys(params)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&');
  return `${url}?${sorted}`;
}
