// 쪽지(Notes): 활성 Couple 안의 짧은 대화. 서버가 예약 열람(open_at)과 삭제를 강제한다.
export const NOTE_BODY_MAX = 1000;
export const NOTE_MEDIA_MAX_BYTES = 10 * 1024 * 1024;
export const NOTE_ALLOWED_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp']);
export const NOTE_REACTIONS = Object.freeze(['❤️', '😊', '😂', '😢', '👍', '🔥']);
export const NOTE_OPEN_AT_MAX_DAYS = 366;
export const NOTE_PAGE_DEFAULT = 30;
export const NOTE_PAGE_MAX = 50;
export const NOTE_PUSH_BODY = '쪽지가 도착했어요';

export class NotesError extends Error {
  constructor(status, reason) {
    super(reason);
    this.name = 'NotesError';
    this.status = status;
    this.reason = reason;
  }
}

export function resolveNoteScope(actor, couple) {
  const userId = Number(actor?.userId);
  if (!Number.isInteger(userId) || userId <= 0) throw new NotesError(401, 'auth_required');
  if (!couple) throw new NotesError(409, 'active_couple_required');
  const user1 = Number(couple.User1Id);
  const user2 = Number(couple.User2Id);
  if (userId !== user1 && userId !== user2) throw new NotesError(403, 'active_couple_required');
  return {
    userId,
    coupleId: Number(couple.CoupleId),
    partnerUserId: userId === user1 ? user2 : user1,
  };
}

export function parsePositiveId(value, reason) {
  if (value === undefined || value === null || value === '') return null;
  const text = String(value);
  if (!/^\d{1,15}$/.test(text) || Number(text) <= 0) throw new NotesError(400, reason);
  return Number(text);
}

export function parseRequiredId(value, reason = 'invalid_id') {
  const id = parsePositiveId(value, reason);
  if (id === null) throw new NotesError(400, reason);
  return id;
}

export function parseClientRequestId(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !value.trim() || value.length > 64) {
    throw new NotesError(400, 'invalid_client_request_id');
  }
  return value;
}

export function parseBody(value) {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') throw new NotesError(400, 'invalid_body');
  const body = value.trim();
  if ([...body].length > NOTE_BODY_MAX) throw new NotesError(400, 'note_too_long');
  return body;
}

// open_at: 미래의 ISO 시각. 과거·너무 먼 미래·잘못된 형식은 거부한다.
export function parseOpenAt(value, now) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw new NotesError(400, 'invalid_open_at');
  const at = new Date(value);
  if (!Number.isFinite(at.getTime())) throw new NotesError(400, 'invalid_open_at');
  const nowMs = now.getTime();
  if (at.getTime() <= nowMs) throw new NotesError(400, 'open_at_not_future');
  if (at.getTime() > nowMs + NOTE_OPEN_AT_MAX_DAYS * 86400_000) {
    throw new NotesError(400, 'open_at_too_far');
  }
  return at;
}

export function parseReaction(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !NOTE_REACTIONS.includes(value)) {
    throw new NotesError(400, 'invalid_reaction');
  }
  return value;
}

export function parsePage({ before, limit }) {
  const beforeId = parsePositiveId(before, 'invalid_before');
  let size = NOTE_PAGE_DEFAULT;
  if (limit !== undefined && limit !== null && limit !== '') {
    if (!/^\d{1,4}$/.test(String(limit)) || Number(limit) < 1) throw new NotesError(400, 'invalid_limit');
    size = Math.min(Number(limit), NOTE_PAGE_MAX);
  }
  return { before: beforeId, limit: size };
}

const isoOrNull = (value) => {
  if (value === null || value === undefined) return null;
  const ms = typeof value === 'number' ? value * 1000 : new Date(value).getTime();
  return Number.isFinite(ms) ? new Date(ms).toISOString() : null;
};

// 저장소 행 -> 보는 사람 기준의 응답. SQL에서도 가리지만 여기서 한 번 더 가려
// 어떤 저장소 구현이든 열리기 전 본문·첨부가 나가지 않게 한다.
export function presentNote(row, viewerUserId) {
  const mine = Number(row.sender_id) === Number(viewerUserId);
  const deleted = row.deleted_at !== null && row.deleted_at !== undefined;
  const opened = Boolean(Number(row.is_open));
  const hidden = deleted || (!mine && !opened);
  const status = deleted ? 'deleted' : (!mine && !opened ? 'locked' : 'visible');
  const note = {
    id: Number(row.id),
    mine,
    sender_id: Number(row.sender_id),
    status,
    created_at: isoOrNull(row.created_at_ts ?? row.created_at),
    open_at: deleted ? null : isoOrNull(row.open_at_ts ?? row.open_at),
    body: hidden ? null : String(row.body ?? ''),
    media_url: hidden ? null : (row.media_url ?? null),
    map_pin_id: hidden ? null : (row.map_pin_id ?? null),
    setlog_post_id: hidden ? null : (row.setlog_post_id ?? null),
    map_pin: null,
    setlog_post: null,
    reaction: hidden ? null : (row.reaction ?? null),
    read_at: mine && !hidden ? isoOrNull(row.read_at_ts ?? row.read_at) : null,
  };
  if (!hidden && note.map_pin_id && row.pin_place_name !== undefined) {
    note.map_pin = row.pin_place_name === null
      ? { id: note.map_pin_id, deleted: true }
      : { id: note.map_pin_id, place_name: String(row.pin_place_name), category: row.pin_category ?? null };
  }
  if (!hidden && note.setlog_post_id && row.post_exists !== undefined) {
    const exists = Boolean(Number(row.post_exists));
    const lockedToday = Boolean(Number(row.post_today_locked));
    if (!exists) note.setlog_post = { id: note.setlog_post_id, deleted: true };
    else if (lockedToday) note.setlog_post = { id: note.setlog_post_id, locked: true };
    else {
      note.setlog_post = {
        id: note.setlog_post_id,
        taken_at: row.post_taken_at ? String(row.post_taken_at).slice(0, 10) : null,
        media_type: row.post_media_type ?? null,
        caption: row.post_caption ? [...String(row.post_caption)].slice(0, 40).join('') : null,
      };
    }
  }
  return note;
}
