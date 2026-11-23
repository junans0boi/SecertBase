import {
  NOTE_ALLOWED_MIMES,
  NOTE_MEDIA_MAX_BYTES,
  NotesError,
  parseBody,
  parseClientRequestId,
  parseOpenAt,
  parsePage,
  parsePositiveId,
  parseReaction,
  parseRequiredId,
  presentNote,
  resolveNoteScope,
} from './domain.js';

const isDuplicateKey = (error) => error?.code === 'ER_DUP_ENTRY' || error?.errno === 1062;

export function NotesService({
  repository,
  media = null,
  notifier = null,
  publish = () => {},
  now = () => new Date(),
  log = console,
} = {}) {
  if (!repository) throw new TypeError('NotesService requires a repository');

  const scopeFor = async (actor) => {
    const userId = Number(actor?.userId);
    if (!Number.isInteger(userId) || userId <= 0) throw new NotesError(401, 'auth_required');
    return resolveNoteScope(actor, await repository.resolveActiveCouple(userId));
  };

  const emit = (userId, event, payload) => {
    try {
      publish(userId, event, payload);
    } catch {
      log.error?.('[Notes] realtime publish failed');
    }
  };

  const validateFile = (file) => {
    if (!file) return;
    if (!NOTE_ALLOWED_MIMES.has(file.mimetype) || Number(file.size) > NOTE_MEDIA_MAX_BYTES) {
      throw new NotesError(400, 'invalid_media');
    }
  };

  // 열린 쪽지를 받는 사람에게 실시간 이벤트 + 고정 문구 푸시로 알린다. 한 번만(claim).
  const deliver = async ({ id, coupleId, recipientId }) => {
    if (!(await repository.claimDelivery(id))) return false;
    const row = await repository.getNote({ coupleId, id, viewerUserId: recipientId });
    if (!row) return false;
    emit(recipientId, 'note:new', { note: presentNote(row, recipientId) });
    // notifier는 던지지 않는다. 푸시 실패가 전송을 되돌리지 않게 한다.
    await notifier?.notifyUser(recipientId, 'partner_note', {});
    return true;
  };

  return {
    async send(actor, fields = {}, file = null) {
      let keepUpload = false;
      try {
        const scope = await scopeFor(actor);
        const clientRequestId = parseClientRequestId(fields.client_request_id);
        const replay = async () => {
          if (!clientRequestId) return null;
          const row = await repository.findByClientRequest({
            coupleId: scope.coupleId, userId: scope.userId, clientRequestId,
          });
          return row ? { note: presentNote(row, scope.userId), created: false } : null;
        };
        const existing = await replay();
        if (existing) return existing;

        const body = parseBody(fields.body);
        validateFile(file);
        const mapPinId = parsePositiveId(fields.map_pin_id, 'invalid_map_pin_id');
        const setlogPostId = parsePositiveId(fields.setlog_post_id, 'invalid_setlog_post_id');
        const openAt = parseOpenAt(fields.open_at, now());
        if (!body && !file && !mapPinId && !setlogPostId) throw new NotesError(400, 'empty_note');
        if (mapPinId) {
          const pin = await repository.findMapPin(mapPinId);
          if (!pin || Number(pin.couple_id) !== scope.coupleId) throw new NotesError(404, 'reference_not_found');
        }
        if (setlogPostId) {
          const post = await repository.findSetlogPost(setlogPostId);
          if (!post || Number(post.couple_id) !== scope.coupleId) throw new NotesError(404, 'reference_not_found');
        }
        const prepared = file ? await media.prepare(file) : null;

        let id;
        try {
          id = await repository.insertNote({
            coupleId: scope.coupleId,
            userId: scope.userId,
            body,
            mediaUrl: prepared?.mediaUrl ?? null,
            mapPinId,
            setlogPostId,
            openAt,
            clientRequestId,
          });
        } catch (error) {
          if (isDuplicateKey(error)) {
            const raced = await replay();
            if (raced) return raced;
          }
          throw error;
        }
        keepUpload = true;

        const row = await repository.getNote({ coupleId: scope.coupleId, id, viewerUserId: scope.userId });
        if (!openAt) await deliver({ id, coupleId: scope.coupleId, recipientId: scope.partnerUserId });
        return { note: presentNote(row, scope.userId), created: true };
      } finally {
        if (file && !keepUpload) await media?.remove(file).catch(() => {});
      }
    },

    async list(actor, query = {}) {
      const scope = await scopeFor(actor);
      const { before, limit } = parsePage(query);
      const rows = await repository.listNotes({
        coupleId: scope.coupleId, viewerUserId: scope.userId, before, limit,
      });
      const page = rows.slice(0, limit);
      return {
        notes: page.map((row) => presentNote(row, scope.userId)),
        next_before: rows.length > limit ? Number(page.at(-1).id) : null,
        unread_count: await repository.unreadCount({ coupleId: scope.coupleId, userId: scope.userId }),
      };
    },

    async unread(actor) {
      const scope = await scopeFor(actor);
      return { unread_count: await repository.unreadCount({ coupleId: scope.coupleId, userId: scope.userId }) };
    },

    async markRead(actor, fields = {}) {
      const scope = await scopeFor(actor);
      const upToId = parseRequiredId(fields.last_read_id, 'invalid_last_read_id');
      const changed = await repository.markRead({
        coupleId: scope.coupleId, userId: scope.userId, upToId,
      });
      if (changed > 0) {
        emit(scope.partnerUserId, 'note:read', { up_to_id: upToId, read_at: now().toISOString() });
      }
      return { unread_count: await repository.unreadCount({ coupleId: scope.coupleId, userId: scope.userId }) };
    },

    async remove(actor, noteId) {
      const scope = await scopeFor(actor);
      const id = parseRequiredId(noteId, 'invalid_id');
      const row = await repository.getNote({ coupleId: scope.coupleId, id, viewerUserId: scope.userId });
      if (!row) throw new NotesError(404, 'note_not_found');
      if (Number(row.sender_id) !== scope.userId) throw new NotesError(403, 'not_author');
      if (row.deleted_at) return { ok: true };
      const changed = await repository.softDelete({ coupleId: scope.coupleId, id, userId: scope.userId });
      if (changed > 0) {
        if (row.media_url) await media?.removeByUrl(row.media_url).catch(() => {});
        emit(scope.partnerUserId, 'note:deleted', { id });
      }
      return { ok: true };
    },

    async react(actor, noteId, fields = {}) {
      const scope = await scopeFor(actor);
      const id = parseRequiredId(noteId, 'invalid_id');
      const emoji = parseReaction(fields.emoji);
      const row = await repository.getNote({ coupleId: scope.coupleId, id, viewerUserId: scope.userId });
      if (!row || row.deleted_at) throw new NotesError(404, 'note_not_found');
      if (Number(row.sender_id) === scope.userId) throw new NotesError(403, 'cannot_react_to_own_note');
      if (!Number(row.is_open)) throw new NotesError(409, 'note_not_open');
      await repository.setReaction({ coupleId: scope.coupleId, id, emoji });
      const updated = await repository.getNote({ coupleId: scope.coupleId, id, viewerUserId: scope.userId });
      emit(Number(row.sender_id), 'note:reaction', { id, reaction: emoji });
      return { note: presentNote(updated, scope.userId) };
    },

    // 예약 열람 시각이 지난 쪽지를 전달한다(활성 Couple만). 스케줄러가 매분 호출한다.
    async deliverDue({ limit = 100 } = {}) {
      const due = await repository.listDueDeliveries({ limit });
      let delivered = 0;
      for (const item of due) {
        try {
          if (await deliver({
            id: Number(item.id), coupleId: Number(item.couple_id), recipientId: Number(item.recipient_id),
          })) delivered += 1;
        } catch {
          log.error?.('[Notes] delivery failed');
        }
      }
      return delivered;
    },
  };
}
