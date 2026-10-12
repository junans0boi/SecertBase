import { query } from '../../db.js';
import { createFcmSender, createNotifier } from './notifier.js';

// Process-wide notifier. sender is null (no-op + log) without Firebase credentials.
export const notifier = createNotifier({ queryFn: query, sender: createFcmSender() });
