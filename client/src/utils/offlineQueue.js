/**
 * Offline mutation queue.
 * Stores pending create/update/delete operations in localStorage
 * so they can be replayed when connectivity returns.
 */

const QUEUE_KEY = 'sbd_offline_queue';

/**
 * Get the current queue.
 */
export function getQueue() {
  try {
    const raw = localStorage.getItem(QUEUE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

/**
 * Save the queue.
 */
function saveQueue(queue) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(queue));
}

/**
 * Add a mutation to the queue.
 * @param {Object} action - { type: 'create'|'update'|'delete', url, data?, id? }
 */
export function enqueue(action) {
  const queue = getQueue();
  queue.push({
    ...action,
    id: action.id || crypto.randomUUID(),
    timestamp: Date.now(),
  });
  saveQueue(queue);
  return queue.length;
}

/**
 * Remove the first item from the queue (after successful sync).
 */
export function dequeue() {
  const queue = getQueue();
  const removed = queue.shift();
  saveQueue(queue);
  return removed;
}

/**
 * Remove a specific item by its queue ID.
 */
export function removeFromQueue(queueId) {
  const queue = getQueue();
  const filtered = queue.filter((item) => item.id !== queueId);
  saveQueue(filtered);
}

/**
 * Clear the entire queue.
 */
export function clearQueue() {
  localStorage.removeItem(QUEUE_KEY);
}

/**
 * Check if the browser is online.
 */
export function isOnline() {
  return navigator.onLine;
}

/**
 * Get queue length.
 */
export function getQueueLength() {
  return getQueue().length;
}
