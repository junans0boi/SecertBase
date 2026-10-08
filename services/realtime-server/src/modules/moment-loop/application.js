import { businessDate } from '../../business-date.js';
import {
  MomentLoopError,
  momentLoopPolicy,
  parseJsonArray,
  parseMomentId,
  resolveMomentScope,
  shiftDate,
  serializeTodayMomentRow,
  validateUploadedMedia,
} from './domain.js';

const resolveMapPin = async (repository, mapPinValue, coupleId) => {
  if (!mapPinValue) return null;

  const pinId = Number(mapPinValue);
  if (!Number.isInteger(pinId) || pinId <= 0) {
    throw new MomentLoopError(400, 'invalid_map_pin');
  }
  const pin = await repository.findMapPin(pinId);
  if (!pin) throw new MomentLoopError(400, 'map_pin_not_found');
  if (!coupleId || Number(pin.couple_id) !== Number(coupleId)) {
    throw new MomentLoopError(400, 'map_pin_forbidden');
  }
  return pinId;
};

const CLIP_ERROR_REASONS = new Set([
  'clip_duration_unreadable',
  'clip_too_long',
  'clip_conversion_failed',
]);

const normalizeClipError = (error) => {
  const reason = error instanceof Error ? error.message : '';
  return new MomentLoopError(
    422,
    CLIP_ERROR_REASONS.has(reason) ? reason : 'clip_conversion_failed',
  );
};

export function MomentLoopService({
  repository,
  policy = momentLoopPolicy,
  media,
  now = businessDate,
}) {
  if (!repository) throw new Error('MomentLoopService requires a repository');
  if (!media) throw new Error('MomentLoopService requires a media adapter');

  const scopeFor = async (actor) => {
    const couple = await repository.resolveActiveCouple(actor?.userId);
    return resolveMomentScope(actor, couple);
  };

  const mutationTarget = async (actor, value) => {
    const scope = await scopeFor(actor);
    const id = parseMomentId(value, 'invalid_moment_id');
    const post = await repository.findMoment(id);
    if (!post) throw new MomentLoopError(404, 'moment_not_found');
    if (Number(post.user_id) !== scope.userId) {
      throw new MomentLoopError(403, 'moment_author_required');
    }
    if (Number(post.couple_id) !== scope.coupleId) {
      throw new MomentLoopError(403, 'active_couple_required');
    }
    return { id, post, scope };
  };

  return {
    async listFeed(actor, month) {
      const scope = await scopeFor(actor);
      const posts = await repository.listFeed({
        coupleId: scope.coupleId,
        viewerUserId: scope.userId,
        month,
      });
      return posts.map((post) => policy.maskLockedTodayMoment({
        post,
        viewerUserId: scope.userId,
      }));
    },

    async createMoment(actor, fields = {}, file = null) {
      let keepUpload = false;
      try {
        validateUploadedMedia(file);

        const takenAt = String(fields.taken_at ?? '').trim();
        if (!takenAt) throw new MomentLoopError(400, 'missing_fields');

        const mediaTypeFromFile = file?.mimetype?.startsWith('video/') ? 'video' : 'image';
        const mediaType = file ? mediaTypeFromFile : (fields.media_type || 'text');
        if (!['text', 'image', 'video'].includes(mediaType)) {
          throw new MomentLoopError(400, 'invalid_media_type');
        }
        if (mediaType === 'text' && !fields.caption?.trim()) {
          throw new MomentLoopError(400, 'caption_required');
        }

        const scope = await scopeFor(actor);
        const mapPinId = await resolveMapPin(repository, fields.map_pin_id, scope.coupleId);
        const designateAsToday = fields.today_moment === true || fields.today_moment === 'true';
        const today = now();
        if (designateAsToday && takenAt !== today) {
          throw new MomentLoopError(400, 'today_moment_date_required');
        }

        let prepared = null;
        if (file) {
          try {
            prepared = await media.prepare(file);
          } catch (error) {
            if (file.mimetype?.startsWith('video/')) {
              throw normalizeClipError(error);
            }
            throw error;
          }
        }
        const userCode = await repository.getUserCode(scope.userId);
        const created = await repository.createMoment({
          coupleId: scope.coupleId,
          userId: scope.userId,
          userCode: userCode || scope.userCode,
          mapPinId,
          mediaType: prepared?.mediaType ?? mediaType,
          mediaUrl: prepared?.mediaUrl ?? null,
          caption: fields.caption || null,
          tags: parseJsonArray(fields.tags),
          takenAt: takenAt,
          capturedAt: fields.captured_at || null,
          sessionId: fields.session_id || null,
          designateAsToday,
          todayDate: today,
          canReplace: policy.canReplaceTodayMoment,
        });
        keepUpload = true;
        return created;
      } finally {
        if (file && !keepUpload) {
          await media.remove(file).catch(() => {});
        }
      }
    },

    async toggleReaction(actor, fields = {}) {
      const sessionId = fields.session_id;
      const emoji = fields.emoji;
      if (!sessionId || !emoji) {
        throw new MomentLoopError(400, 'missing_fields');
      }
      const scope = await scopeFor(actor);
      return repository.toggleReaction({
        coupleId: scope.coupleId,
        userId: scope.userId,
        sessionId,
        emoji,
      });
    },

    async updateMoment(actor, value, fields = {}) {
      const { id, scope } = await mutationTarget(actor, value);
      const changes = {};
      const caption = typeof fields.caption === 'string' ? fields.caption.trim() : null;
      const takenAt = typeof fields.taken_at === 'string' ? fields.taken_at : null;
      const hasTags = fields.tags !== undefined;
      const hasMapPinId = Object.prototype.hasOwnProperty.call(fields, 'map_pin_id');

      if (caption !== null) changes.caption = caption;
      if (takenAt !== null) changes.takenAt = takenAt;
      if (hasTags) changes.tags = JSON.stringify(parseJsonArray(fields.tags));
      if (hasMapPinId) {
        changes.mapPinId = fields.map_pin_id ? await resolveMapPin(
          repository,
          fields.map_pin_id,
          scope.coupleId,
        ) : null;
      }
      if (Object.keys(changes).length === 0) {
        throw new MomentLoopError(400, 'no_changes');
      }

      const updated = await repository.updateMoment({ id, changes });
      return updated;
    },

    async deleteMoment(actor, value) {
      const { id } = await mutationTarget(actor, value);
      const deletion = await repository.deleteMoment({ id });
      if (deletion === null || deletion?.deleted === false) {
        throw new MomentLoopError(404, 'moment_not_found');
      }
      const mediaUrl = typeof deletion === 'string' ? deletion : deletion.mediaUrl;
      await media.removeByUrl(mediaUrl).catch(() => {});
      return true;
    },

    async readToday(actor) {
      const scope = await scopeFor(actor);
      const date = now();
      const { rows, viewedAt } = await repository.readToday({
        coupleId: scope.coupleId,
        userId: scope.userId,
        date,
      });
      const mine = rows.find((row) => Number(row.user_id) === scope.userId) ?? null;
      const partner = rows.find((row) => Number(row.user_id) !== scope.userId) ?? null;
      const hasMine = Boolean(mine);
      const hasPartner = Boolean(partner);
      const revealedAt = mine?.revealed_at ?? partner?.revealed_at ?? null;
      const canViewPartner = hasPartner && policy.canViewTodayMoment({
        isAuthor: false,
        revealed: Boolean(revealedAt),
        viewerHasMoment: hasMine,
      });

      return {
        ok: true,
        date,
        status: policy.todayMomentStatus({ hasMine, hasPartner, viewed: Boolean(viewedAt) }),
        hasPartnerMoment: hasPartner,
        revealedAt,
        viewedAt,
        myMoment: serializeTodayMomentRow(mine),
        partnerMoment: canViewPartner ? serializeTodayMomentRow(partner) : null,
      };
    },

    async markTodayViewed(actor) {
      const scope = await scopeFor(actor);
      const date = now();
      const viewedAt = await repository.markTodayViewed({
        coupleId: scope.coupleId,
        userId: scope.userId,
        date,
      });
      return { ok: true, date, viewedAt };
    },

    async summarize(actor, requestedDays) {
      const scope = await scopeFor(actor);
      const requested = Number(requestedDays ?? 7);
      const days = Number.isFinite(requested)
        ? Math.min(Math.max(Math.trunc(requested), 1), 30)
        : 7;
      const endDate = now();
      const startDate = shiftDate(endDate, -(days - 1));
      const { row } = await repository.summary({
        coupleId: scope.coupleId,
        days,
        startDate,
        endDate,
      });
      const momentsTotal = Number(row.moments_total ?? 0);
      const momentsViewedWithin24Hours = Number(row.viewed_within_24_hours ?? 0);
      return {
        ok: true,
        days,
        startDate,
        endDate,
        loopDays: Number(row.loop_days ?? 0),
        momentsTotal,
        momentsViewedWithin24Hours,
        viewRateWithin24Hours: momentsTotal === 0
          ? 0
          : momentsViewedWithin24Hours / momentsTotal,
      };
    },

    async selectToday(actor, value) {
      const postId = parseMomentId(value);
      const scope = await scopeFor(actor);
      const date = now();
      await repository.selectTodayMoment({
        coupleId: scope.coupleId,
        userId: scope.userId,
        postId,
        date,
        canReplace: policy.canReplaceTodayMoment,
      });
      return { ok: true, date, postId };
    },

    async removeToday(actor) {
      const scope = await scopeFor(actor);
      const date = now();
      const removed = await repository.removeToday({
        coupleId: scope.coupleId,
        userId: scope.userId,
        date,
        canReplace: policy.canReplaceTodayMoment,
      });
      return { ok: true, removed };
    },
  };
}

export { resolveMapPin };
