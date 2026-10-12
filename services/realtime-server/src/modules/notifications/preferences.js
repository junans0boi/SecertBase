export const DEFAULT_PREFS = Object.freeze({
  partner_moment: true,
  today_loop: true,
  game_invite: true,
  quiet_hours_enabled: true,
  quiet_start: '22:00',
  quiet_end: '08:00',
  reveal_hour: 21,
});

export const PREF_FIELDS = Object.freeze(Object.keys(DEFAULT_PREFS));
const BOOLEAN_FIELDS = new Set(['partner_moment', 'today_loop', 'game_invite', 'quiet_hours_enabled']);
const CLOCK_TIME = /^(?:[01]\d|2[0-3]):[0-5]\d$/;

export function notificationPrefs(row = {}) {
  return Object.fromEntries(PREF_FIELDS.map((field) => {
    const value = row[field] ?? DEFAULT_PREFS[field];
    return [field, BOOLEAN_FIELDS.has(field) ? Boolean(Number(value)) :
      field === 'reveal_hour' ? Number(value) : String(value).slice(0, 5)];
  }));
}

export function validPreferencePatch(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return false;
  const fields = Object.keys(input);
  return fields.length > 0 && fields.every((field) => {
    if (!PREF_FIELDS.includes(field)) return false;
    if (BOOLEAN_FIELDS.has(field)) return typeof input[field] === 'boolean';
    if (field === 'reveal_hour') return Number.isInteger(input[field]) && input[field] >= 0 && input[field] <= 23;
    return typeof input[field] === 'string' && CLOCK_TIME.test(input[field]);
  });
}

export function kstMinute(value) {
  const date = new Date(value.getTime() + 9 * 60 * 60 * 1000);
  return date.getUTCHours() * 60 + date.getUTCMinutes();
}

export function inQuietHours(prefs, value) {
  if (!prefs.quiet_hours_enabled) return false;
  const minutes = (time) => Number(time.slice(0, 2)) * 60 + Number(time.slice(3, 5));
  const start = minutes(prefs.quiet_start);
  const end = minutes(prefs.quiet_end);
  const current = kstMinute(value);
  return start < end ? current >= start && current < end :
    start > end && (current >= start || current < end);
}
