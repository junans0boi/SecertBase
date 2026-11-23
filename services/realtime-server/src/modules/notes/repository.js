import { NotesError } from './domain.js';

const OPEN = '(n.open_at IS NULL OR n.open_at <= NOW())';

// 가림 규칙은 SQL에서 먼저 적용한다: 받는 사람은 열리기 전·삭제된 쪽지의 본문·첨부·참조를 받지 못한다.
const visible = (column) => `CASE
    WHEN n.deleted_at IS NOT NULL THEN NULL
    WHEN n.sender_id = ? OR ${OPEN} THEN ${column}
    ELSE NULL END`;

const SELECT_NOTE = `SELECT n.id, n.couple_id, n.sender_id, n.deleted_at,
    ${OPEN} AS is_open,
    ${visible('n.body')} AS body,
    ${visible('n.media_url')} AS media_url,
    ${visible('n.map_pin_id')} AS map_pin_id,
    ${visible('n.setlog_post_id')} AS setlog_post_id,
    ${visible('n.reaction')} AS reaction,
    UNIX_TIMESTAMP(n.open_at) AS open_at_ts,
    UNIX_TIMESTAMP(n.created_at) AS created_at_ts,
    UNIX_TIMESTAMP(n.read_at) AS read_at_ts,
    mp.place_name AS pin_place_name, mp.category AS pin_category,
    (p.id IS NOT NULL) AS post_exists,
    p.taken_at AS post_taken_at, p.media_type AS post_media_type, p.caption AS post_caption,
    EXISTS(SELECT 1 FROM today_moments tm WHERE tm.setlog_post_id = p.id
           AND tm.deleted_at IS NULL AND tm.revealed_at IS NULL) AS post_today_locked
  FROM couple_notes n
  LEFT JOIN map_pins mp ON mp.id = n.map_pin_id AND mp.couple_id = n.couple_id
  LEFT JOIN setlog_posts p ON p.id = n.setlog_post_id AND p.couple_id = n.couple_id`;
const viewerParams = (viewerUserId) => Array(5).fill(viewerUserId);

export function createNotesRepository({ queryFn }) {
  if (!queryFn) throw new TypeError('Notes repository requires queryFn');

  return {
    async resolveActiveCouple(userId) {
      const { rows } = await queryFn(
        `SELECT CoupleId, User1Id, User2Id FROM Couples
         WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?) LIMIT 1`,
        [userId, userId],
      );
      return rows[0] ?? null;
    },

    async findByClientRequest({ coupleId, userId, clientRequestId }) {
      const { rows } = await queryFn(
        `${SELECT_NOTE} WHERE n.couple_id = ? AND n.sender_id = ? AND n.client_request_id = ? LIMIT 1`,
        [...viewerParams(userId), coupleId, userId, clientRequestId],
      );
      return rows[0] ?? null;
    },

    async findMapPin(id) {
      const { rows } = await queryFn('SELECT id, couple_id FROM map_pins WHERE id = ? LIMIT 1', [id]);
      return rows[0] ?? null;
    },

    async findSetlogPost(id) {
      const { rows } = await queryFn('SELECT id, couple_id FROM setlog_posts WHERE id = ? LIMIT 1', [id]);
      return rows[0] ?? null;
    },

    // 활성 Couple 확인과 삽입을 한 문장으로 묶어 연결 해제와의 경합을 막는다.
    async insertNote({ coupleId, userId, body, mediaUrl, mapPinId, setlogPostId, openAt, clientRequestId }) {
      const { rows } = await queryFn(
        `INSERT INTO couple_notes
           (couple_id, sender_id, body, media_url, map_pin_id, setlog_post_id, open_at, client_request_id)
         SELECT c.CoupleId, ?, ?, ?, ?, ?, ${openAt ? 'FROM_UNIXTIME(?)' : '?'}, ?
         FROM Couples c
         WHERE c.CoupleId = ? AND c.Status = 'active' AND (c.User1Id = ? OR c.User2Id = ?)`,
        [
          userId, body, mediaUrl, mapPinId, setlogPostId,
          openAt ? Math.floor(openAt.getTime() / 1000) : null,
          clientRequestId, coupleId, userId, userId,
        ],
      );
      if (!rows.affectedRows) throw new NotesError(409, 'active_couple_required');
      return Number(rows.insertId);
    },

    async getNote({ coupleId, id, viewerUserId }) {
      const { rows } = await queryFn(
        `${SELECT_NOTE} WHERE n.couple_id = ? AND n.id = ? LIMIT 1`,
        [...viewerParams(viewerUserId), coupleId, id],
      );
      return rows[0] ?? null;
    },

    async listNotes({ coupleId, viewerUserId, before, limit }) {
      const { rows } = await queryFn(
        `${SELECT_NOTE} WHERE n.couple_id = ? ${before ? 'AND n.id < ?' : ''}
         ORDER BY n.id DESC LIMIT ${Number(limit) + 1}`,
        [...viewerParams(viewerUserId), coupleId, ...(before ? [before] : [])],
      );
      return rows;
    },

    async markRead({ coupleId, userId, upToId }) {
      const { rows } = await queryFn(
        `UPDATE couple_notes n SET n.read_at = NOW()
         WHERE n.couple_id = ? AND n.sender_id <> ? AND n.id <= ? AND n.read_at IS NULL
           AND n.deleted_at IS NULL AND ${OPEN}`,
        [coupleId, userId, upToId],
      );
      return rows.affectedRows;
    },

    async unreadCount({ coupleId, userId }) {
      const { rows } = await queryFn(
        `SELECT COUNT(*) AS unread FROM couple_notes n
         WHERE n.couple_id = ? AND n.sender_id <> ? AND n.read_at IS NULL
           AND n.deleted_at IS NULL AND ${OPEN}`,
        [coupleId, userId],
      );
      return Number(rows[0]?.unread ?? 0);
    },

    // 삭제하면 본문·첨부를 지운다. 행은 남겨 상대에게 "삭제된 쪽지"로 보인다.
    async softDelete({ coupleId, id, userId }) {
      const { rows } = await queryFn(
        `UPDATE couple_notes SET deleted_at = NOW(), body = '', media_url = NULL,
           map_pin_id = NULL, setlog_post_id = NULL, reaction = NULL
         WHERE couple_id = ? AND id = ? AND sender_id = ? AND deleted_at IS NULL`,
        [coupleId, id, userId],
      );
      return rows.affectedRows;
    },

    async setReaction({ coupleId, id, emoji }) {
      await queryFn(
        'UPDATE couple_notes SET reaction = ? WHERE couple_id = ? AND id = ? AND deleted_at IS NULL',
        [emoji, coupleId, id],
      );
    },

    async claimDelivery(id) {
      const { rows } = await queryFn(
        `UPDATE couple_notes n SET n.delivered_at = NOW()
         WHERE n.id = ? AND n.delivered_at IS NULL AND n.deleted_at IS NULL AND ${OPEN}`,
        [id],
      );
      return rows.affectedRows > 0;
    },

    // 현재 활성인 Couple의 쪽지만 전달 대상이다. 비활성이면 재결합 후에 전달된다.
    async listDueDeliveries({ limit }) {
      const { rows } = await queryFn(
        `SELECT n.id, n.couple_id, n.sender_id,
                CASE WHEN c.User1Id = n.sender_id THEN c.User2Id ELSE c.User1Id END AS recipient_id
         FROM couple_notes n
         JOIN Couples c ON c.CoupleId = n.couple_id AND c.Status = 'active'
         WHERE n.delivered_at IS NULL AND n.deleted_at IS NULL AND ${OPEN}
         ORDER BY n.id LIMIT ${Number(limit)}`,
        [],
      );
      return rows;
    },
  };
}
