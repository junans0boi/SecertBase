import {
  canReplaceTodayMoment,
  canViewTodayMoment,
  maskLockedTodayMoment,
  todayMomentStatus,
} from '../../today-moment-policy.js';

export {
  canReplaceTodayMoment,
  canViewTodayMoment,
  maskLockedTodayMoment,
  todayMomentStatus,
};

export const MOMENT_MEDIA_MAX_BYTES = 30 * 1024 * 1024;

export const ALLOWED_MOMENT_MIMES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'video/mp4',
  'video/quicktime',
  'video/webm',
]);

export class MomentLoopError extends Error {
  constructor(status, reason) {
    super(reason);
    this.name = 'MomentLoopError';
    this.status = status;
    this.reason = reason;
  }
}

export const momentLoopPolicy = Object.freeze({
  canReplaceTodayMoment,
  canViewTodayMoment,
  maskLockedTodayMoment,
  todayMomentStatus,
});

export const parseJsonArray = (value) => {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string') return [];

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }
};

export const dateOnly = (value) => {
  if (!value) return null;
  if (value instanceof Date) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, '0');
    const day = String(value.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  return String(value).split('T')[0];
};

export const shiftDate = (date, days) => {
  const value = new Date(`${date}T12:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
};

export function resolveMomentScope(actor, couple) {
  const userId = Number(actor?.userId);
  if (!Number.isInteger(userId) || userId <= 0) {
    throw new MomentLoopError(401, 'auth_required');
  }

  const coupleId = Number(couple?.CoupleId ?? couple?.coupleId);
  if (!Number.isInteger(coupleId) || coupleId <= 0) {
    throw new MomentLoopError(409, 'active_couple_required');
  }

  const user1Id = Number(couple?.User1Id ?? couple?.user1Id);
  const user2Id = Number(couple?.User2Id ?? couple?.user2Id);
  if (![user1Id, user2Id].includes(userId)) {
    throw new MomentLoopError(403, 'active_couple_required');
  }

  return {
    userId,
    coupleId,
    userCode: actor?.userCode ?? couple?.UserCode ?? null,
    partnerUserId: user1Id === userId ? user2Id : user1Id,
  };
}

export function validateUploadedMedia(file) {
  if (!file) return;
  if (Number(file.size) > MOMENT_MEDIA_MAX_BYTES) {
    throw new MomentLoopError(413, 'media_too_large');
  }
  if (!ALLOWED_MOMENT_MIMES.has(file.mimetype)) {
    throw new MomentLoopError(415, 'unsupported_media_type');
  }
}

export function serializeTodayMomentRow(row) {
  if (!row) return null;
  if (row.deleted_at || !row.id) {
    return {
      user_id: row.user_id,
      UserName: row.UserName,
      deleted: true,
    };
  }
  return {
    id: row.id,
    user_id: row.user_id,
    UserName: row.UserName,
    media_type: row.media_type,
    media_url: row.media_url,
    caption: row.caption,
    tags: parseJsonArray(row.tags),
    taken_at: dateOnly(row.taken_at),
    captured_at: row.captured_at,
    map_pin_id: row.map_pin_id,
    linked_place_name: row.linked_place_name,
    deleted: false,
  };
}

export function parseMomentId(value, reason = 'invalid_post_id') {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) {
    throw new MomentLoopError(400, reason);
  }
  return id;
}
