import { canReplaceTodayMoment, MomentLoopError } from './domain.js';

const defaultQuery = async (...args) => {
  const { query } = await import('../../db.js');
  return query(...args);
};

const defaultTransaction = async (...args) => {
  const { transaction } = await import('../../db.js');
  return transaction(...args);
};

const postWithOwnerSql = `
  SELECT p.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName,
         mp.place_name AS linked_place_name, mp.category AS linked_place_category,
         mp.archived_at AS linked_place_archived_at
  FROM setlog_posts p
  LEFT JOIN Users u ON p.user_id = u.UserId
  LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
`;

const activeCoupleSql = `
  SELECT c.CoupleId, c.User1Id, c.User2Id, c.RoomCode,
         u.UserCode, COALESCE(u.Nickname, u.UserName, u.UserCode) AS Nickname
  FROM Couples c
  JOIN Users u ON u.UserId = ?
  WHERE c.Status = 'active' AND (c.User1Id = ? OR c.User2Id = ?)
  LIMIT 1
`;

export async function selectTodayMomentOnConnection(
  connection,
  { coupleId, userId, postId, date, canReplace = canReplaceTodayMoment },
) {
  await connection.execute(
    'SELECT CoupleId FROM Couples WHERE CoupleId = ? AND Status = \'active\' FOR UPDATE',
    [coupleId],
  );
  const [posts] = await connection.execute(
    `SELECT id FROM setlog_posts
     WHERE id = ? AND couple_id = ? AND user_id = ? AND taken_at = ?
     LIMIT 1`,
    [postId, coupleId, userId, date],
  );
  if (!posts[0]) throw new MomentLoopError(404, 'today_moment_not_found');

  const [current] = await connection.execute(
    `SELECT revealed_at FROM today_moments
     WHERE couple_id = ? AND user_id = ? AND business_date = ?
     LIMIT 1 FOR UPDATE`,
    [coupleId, userId, date],
  );
  if (current[0] && !canReplace(current[0].revealed_at)) {
    throw new MomentLoopError(409, 'today_loop_locked');
  }

  await connection.execute(
    `INSERT INTO today_moments
       (couple_id, user_id, business_date, setlog_post_id, selected_at, revealed_at, deleted_at)
     VALUES (?, ?, ?, ?, NOW(), NULL, NULL)
     ON DUPLICATE KEY UPDATE
       setlog_post_id = VALUES(setlog_post_id), selected_at = NOW(), deleted_at = NULL`,
    [coupleId, userId, date, postId],
  );

  const [participants] = await connection.execute(
    `SELECT COUNT(*) AS count FROM today_moments
     WHERE couple_id = ? AND business_date = ? AND setlog_post_id IS NOT NULL`,
    [coupleId, date],
  );
  if (Number(participants[0]?.count) >= 2) {
    await connection.execute(
      `UPDATE today_moments SET revealed_at = COALESCE(revealed_at, NOW())
       WHERE couple_id = ? AND business_date = ?`,
      [coupleId, date],
    );
  }
}

export function createMomentLoopRepository({
  queryFn = defaultQuery,
  transactionFn = defaultTransaction,
} = {}) {
  const findMoment = async (id) => {
    const result = await queryFn(
      `${postWithOwnerSql} WHERE p.id = ?`,
      [id],
    );
    return result.rows[0] ?? null;
  };

  return {
    async resolveActiveCouple(userId) {
      const numericUserId = Number(userId);
      if (!Number.isInteger(numericUserId) || numericUserId <= 0) return null;
      const result = await queryFn(activeCoupleSql, [
        numericUserId,
        numericUserId,
        numericUserId,
      ]);
      return result.rows[0] ?? null;
    },

    async getUserCode(userId) {
      const result = await queryFn(
        'SELECT UserCode FROM Users WHERE UserId = ? LIMIT 1',
        [userId],
      );
      return result.rows[0]?.UserCode ?? null;
    },

    async listFeed({ coupleId, viewerUserId, month }) {
      let sql = `SELECT p.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName,
                        mp.place_name AS linked_place_name, mp.category AS linked_place_category,
                        mp.archived_at AS linked_place_archived_at,
                        tm.business_date AS today_business_date,
                        tm.revealed_at AS today_revealed_at,
                        viewer_tm.id AS viewer_today_moment_id,
                        (SELECT JSON_ARRAYAGG(JSON_OBJECT('user_id', r.user_id, 'emoji', r.emoji))
                         FROM setlog_reactions r
                         WHERE p.session_id IS NOT NULL AND r.session_id = p.session_id AND r.couple_id = p.couple_id
                        ) AS session_reactions
                 FROM setlog_posts p
                 LEFT JOIN Users u ON p.user_id = u.UserId
                 LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
                 LEFT JOIN today_moments tm ON tm.setlog_post_id = p.id
                 LEFT JOIN today_moments viewer_tm
                   ON viewer_tm.couple_id = tm.couple_id
                  AND viewer_tm.business_date = tm.business_date
                  AND viewer_tm.user_id = ?
                 WHERE p.couple_id = ?`;
      const params = [viewerUserId, coupleId];

      if (month) {
        sql += ` AND DATE_FORMAT(p.taken_at, '%Y-%m') = ?`;
        params.push(month);
      }

      sql += ' ORDER BY p.captured_at DESC, p.id DESC';
      const result = await queryFn(sql, params);
      return result.rows;
    },

    async findMapPin(mapPinId) {
      const result = await queryFn(
        'SELECT id, user_id, couple_id FROM map_pins WHERE id = ? LIMIT 1',
        [mapPinId],
      );
      return result.rows[0] ?? null;
    },

    async createMoment({
      coupleId,
      userId,
      userCode,
      mapPinId,
      mediaType,
      mediaUrl,
      caption,
      tags,
      takenAt,
      capturedAt,
      sessionId,
      designateAsToday,
      todayDate,
      canReplace = canReplaceTodayMoment,
    }) {
      return transactionFn(async (connection) => {
        const [result] = await connection.execute(
          `INSERT INTO setlog_posts
           (couple_id, user_id, map_pin_id, user_code, media_type, media_url, caption, tags, taken_at, captured_at, session_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW()), ?)`,
          [
            coupleId,
            userId,
            mapPinId ?? null,
            userCode || null,
            mediaType,
            mediaUrl,
            caption || null,
            JSON.stringify(tags),
            takenAt,
            capturedAt || null,
            sessionId || null,
          ],
        );

        if (designateAsToday) {
          await selectTodayMomentOnConnection(connection, {
            coupleId,
            userId,
            postId: result.insertId,
            date: todayDate,
            canReplace,
          });
        }

        const [created] = await connection.execute(
          `${postWithOwnerSql} WHERE p.id = ?`,
          [result.insertId],
        );
        return created[0] ?? null;
      });
    },

    async toggleReaction({ coupleId, userId, sessionId, emoji }) {
      const existing = await queryFn(
        'SELECT emoji FROM setlog_reactions WHERE couple_id = ? AND session_id = ? AND user_id = ? LIMIT 1',
        [coupleId, sessionId, userId],
      );

      if (existing.rows[0]?.emoji === emoji) {
        await queryFn(
          'DELETE FROM setlog_reactions WHERE couple_id = ? AND session_id = ? AND user_id = ?',
          [coupleId, sessionId, userId],
        );
      } else {
        await queryFn(
          `INSERT INTO setlog_reactions (couple_id, session_id, user_id, emoji)
           VALUES (?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE emoji = VALUES(emoji), created_at = NOW()`,
          [coupleId, sessionId, userId, emoji],
        );
      }

      const reactions = await queryFn(
        'SELECT user_id, emoji FROM setlog_reactions WHERE couple_id = ? AND session_id = ?',
        [coupleId, sessionId],
      );
      return reactions.rows;
    },

    findMoment,

    async updateMoment({ id, changes }) {
      const updates = [];
      const params = [];
      const columns = [
        ['caption', 'caption'],
        ['takenAt', 'taken_at'],
        ['tags', 'tags'],
        ['mapPinId', 'map_pin_id'],
      ];
      for (const [key, column] of columns) {
        if (!Object.prototype.hasOwnProperty.call(changes, key)) continue;
        updates.push(`${column} = ?`);
        params.push(changes[key]);
      }
      if (updates.length === 0) return findMoment(id);

      await queryFn(
        `UPDATE setlog_posts SET ${updates.join(', ')} WHERE id = ?`,
        [...params, id],
      );
      return findMoment(id);
    },

    async deleteMoment({ id }) {
      const mediaUrl = await transactionFn(async (connection) => {
        const [lockedPosts] = await connection.execute(
          'SELECT id, media_url FROM setlog_posts WHERE id = ? LIMIT 1 FOR UPDATE',
          [id],
        );
        if (!lockedPosts[0]) return null;

        const [todayRows] = await connection.execute(
          `SELECT id, revealed_at FROM today_moments
           WHERE setlog_post_id = ? LIMIT 1 FOR UPDATE`,
          [id],
        );
        const todayMoment = todayRows[0];
        if (todayMoment?.revealed_at) {
          await connection.execute(
            `UPDATE today_moments
             SET setlog_post_id = NULL, deleted_at = NOW()
             WHERE id = ?`,
            [todayMoment.id],
          );
        } else if (todayMoment) {
          await connection.execute('DELETE FROM today_moments WHERE id = ?', [todayMoment.id]);
        }

        await connection.execute(
          `UPDATE afterglow_contributions
           SET setlog_post_id = NULL, deleted_at = NOW()
           WHERE setlog_post_id = ?`,
          [id],
        );
        await connection.execute('DELETE FROM setlog_posts WHERE id = ?', [id]);
        return {
          deleted: true,
          mediaUrl: lockedPosts[0].media_url ?? null,
        };
      });
      return mediaUrl;
    },

    async readToday({ coupleId, userId, date }) {
      const result = await queryFn(
        `SELECT tm.user_id, tm.revealed_at, tm.deleted_at,
                p.id, p.media_type, p.media_url, p.caption, p.tags, p.taken_at, p.captured_at,
                p.map_pin_id, mp.place_name AS linked_place_name,
                COALESCE(u.Nickname, u.UserName) AS UserName
         FROM today_moments tm
         LEFT JOIN setlog_posts p ON p.id = tm.setlog_post_id
         LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
         LEFT JOIN Users u ON u.UserId = tm.user_id
         WHERE tm.couple_id = ? AND tm.business_date = ?`,
        [coupleId, date],
      );
      const viewResult = await queryFn(
        `SELECT viewed_at FROM today_loop_views
         WHERE couple_id = ? AND user_id = ? AND business_date = ? LIMIT 1`,
        [coupleId, userId, date],
      );
      return {
        rows: result.rows,
        viewedAt: viewResult.rows[0]?.viewed_at ?? null,
      };
    },

    async markTodayViewed({ coupleId, userId, date }) {
      return transactionFn(async (connection) => {
        const [moments] = await connection.execute(
          `SELECT COUNT(*) AS count, MIN(revealed_at) AS revealed_at
           FROM today_moments
           WHERE couple_id = ? AND business_date = ? AND revealed_at IS NOT NULL`,
          [coupleId, date],
        );
        if (Number(moments[0]?.count) < 2 || !moments[0]?.revealed_at) {
          throw new MomentLoopError(409, 'today_loop_not_revealed');
        }
        await connection.execute(
          `INSERT INTO today_loop_views (couple_id, user_id, business_date, viewed_at)
           VALUES (?, ?, ?, NOW())
           ON DUPLICATE KEY UPDATE viewed_at = LEAST(viewed_at, VALUES(viewed_at))`,
          [coupleId, userId, date],
        );
        const [views] = await connection.execute(
          `SELECT viewed_at FROM today_loop_views
           WHERE couple_id = ? AND user_id = ? AND business_date = ? LIMIT 1`,
          [coupleId, userId, date],
        );
        return views[0]?.viewed_at ?? null;
      });
    },

    async summary({ coupleId, days, startDate, endDate }) {
      const result = await queryFn(
        `SELECT
           COUNT(DISTINCT CASE WHEN daily.contribution_count >= 2 THEN daily.business_date END) AS loop_days,
           COUNT(tm.id) AS moments_total,
           COALESCE(SUM(CASE
             WHEN v.viewed_at >= tm.selected_at
               AND v.viewed_at <= DATE_ADD(tm.selected_at, INTERVAL 24 HOUR)
             THEN 1 ELSE 0 END), 0) AS viewed_within_24_hours
         FROM today_moments tm
         JOIN Couples c ON c.CoupleId = tm.couple_id AND c.Status = 'active'
         JOIN (
           SELECT couple_id, business_date, COUNT(*) AS contribution_count
           FROM today_moments
           WHERE revealed_at IS NOT NULL
           GROUP BY couple_id, business_date
         ) daily ON daily.couple_id = tm.couple_id AND daily.business_date = tm.business_date
         LEFT JOIN today_loop_views v
           ON v.couple_id = tm.couple_id
          AND v.business_date = tm.business_date
          AND v.user_id = CASE WHEN tm.user_id = c.User1Id THEN c.User2Id ELSE c.User1Id END
         WHERE tm.couple_id = ? AND tm.business_date BETWEEN ? AND ?`,
        [coupleId, startDate, endDate],
      );
      return { days, row: result.rows[0] ?? {} };
    },

    async selectTodayMoment({ coupleId, userId, postId, date, canReplace = canReplaceTodayMoment }) {
      return transactionFn((connection) => selectTodayMomentOnConnection(connection, {
        coupleId,
        userId,
        postId,
        date,
        canReplace,
      }));
    },

    async removeToday({ coupleId, userId, date, canReplace = canReplaceTodayMoment }) {
      return transactionFn(async (connection) => {
        const [rows] = await connection.execute(
          `SELECT id, revealed_at FROM today_moments
           WHERE couple_id = ? AND user_id = ? AND business_date = ?
           LIMIT 1 FOR UPDATE`,
          [coupleId, userId, date],
        );
        if (!rows[0]) return false;
        if (!canReplace(rows[0].revealed_at)) {
          throw new MomentLoopError(409, 'today_loop_locked');
        }
        await connection.execute('DELETE FROM today_moments WHERE id = ?', [rows[0].id]);
        return true;
      });
    },
  };
}
