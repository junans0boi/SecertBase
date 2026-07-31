import { query, transaction } from './db.js';

// XP needed to reach the next level: level × 100
export function xpForNextLevel(level) {
  return level * 100;
}

/**
 * Grant XP to a user. Creates user_levels row if missing.
 * Returns { level, xp, leveledUp, newLevel } after applying the grant.
 */
export async function grantXp(userId, amount) {
  return transaction(async (conn) => {
    await conn.execute(
      'INSERT IGNORE INTO user_levels (user_id, level, xp) VALUES (?, 1, 0)',
      [userId],
    );

    const [[row]] = await conn.execute(
      'SELECT level, xp FROM user_levels WHERE user_id = ? FOR UPDATE',
      [userId],
    );

    let { level, xp } = row;
    xp += amount;
    let leveledUp = false;

    // Level-up loop (in case multiple levels are gained at once)
    let needed = xpForNextLevel(level);
    while (xp >= needed) {
      xp -= needed;
      level += 1;
      leveledUp = true;
      needed = xpForNextLevel(level);
    }

    await conn.execute(
      'UPDATE user_levels SET level = ?, xp = ? WHERE user_id = ?',
      [level, xp, userId],
    );

    return { level, xp, xpNeeded: xpForNextLevel(level), leveledUp };
  });
}

/**
 * Get user's current level/XP/tickets.
 */
export async function getUserLevel(userId) {
  await query('INSERT IGNORE INTO user_levels (user_id, level, xp) VALUES (?, 1, 0)', [userId]);
  await query('INSERT IGNORE INTO wallets (user_id, balance) VALUES (?, 10000)', [userId]);

  const { rows: lvRows } = await query(
    'SELECT level, xp FROM user_levels WHERE user_id = ?',
    [userId],
  );
  const { rows: wRows } = await query(
    'SELECT gacha_tickets FROM wallets WHERE user_id = ?',
    [userId],
  );

  const { level, xp } = lvRows[0] ?? { level: 1, xp: 0 };
  return {
    level,
    xp,
    xpNeeded: xpForNextLevel(level),
    tickets: wRows[0]?.gacha_tickets ?? 0,
  };
}

/**
 * ISO week string: 'YYYY-WW'
 */
function currentWeekKey() {
  const now = new Date();
  const jan4 = new Date(now.getFullYear(), 0, 4);
  const week = Math.ceil((((now - jan4) / 86400000) + jan4.getDay() + 1) / 7);
  return `${now.getFullYear()}-${String(week).padStart(2, '0')}`;
}

/**
 * Get all missions for a user with progress.
 */
export async function getMissions(userId) {
  const weekKey = currentWeekKey();

  const { rows } = await query(
    `SELECT
       mt.id, mt.type, mt.title, mt.description, mt.game,
       mt.event_key, mt.target_count,
       mt.reward_coins, mt.reward_tickets, mt.reward_xp,
       COALESCE(um.progress, 0)   AS progress,
       um.claimed_at              AS claimed_at
     FROM mission_templates mt
     LEFT JOIN user_missions um
       ON um.template_id = mt.id
      AND um.user_id = ?
      AND um.period_key = (CASE WHEN mt.type = 'weekly' THEN ? ELSE 'all' END)
     WHERE mt.active = 1
     ORDER BY mt.sort_order`,
    [userId, weekKey],
  );

  return rows.map((r) => ({
    id: r.id,
    type: r.type,
    title: r.title,
    description: r.description,
    game: r.game,
    eventKey: r.event_key,
    targetCount: r.target_count,
    rewardCoins: r.reward_coins,
    rewardTickets: r.reward_tickets,
    rewardXp: r.reward_xp,
    progress: r.progress,
    completed: r.progress >= r.target_count,
    claimed: !!r.claimed_at,
  }));
}

/**
 * Update mission progress for a specific event (game_play, game_win, item_buy, gacha_pull).
 * Only increments missions where the game matches (or is null = all games).
 */
export async function updateMissionProgress(userId, eventKey, game = null) {
  const weekKey = currentWeekKey();

  const { rows: templates } = await query(
    `SELECT id, type, target_count
     FROM mission_templates
     WHERE active = 1 AND event_key = ?
       AND (game IS NULL OR game = ?)`,
    [eventKey, game ?? ''],
  );

  for (const tmpl of templates) {
    const periodKey = tmpl.type === 'weekly' ? weekKey : 'all';

    // Upsert progress, but don't exceed target
    await query(
      `INSERT INTO user_missions (user_id, template_id, period_key, progress)
       VALUES (?, ?, ?, 1)
       ON DUPLICATE KEY UPDATE
         progress = LEAST(progress + 1, ?)`,
      [userId, tmpl.id, periodKey, tmpl.target_count],
    );
  }
}

/**
 * Claim a completed mission. Returns { coins, tickets, xp } granted.
 * Throws if not completed or already claimed.
 */
export async function claimMission(userId, templateId) {
  return transaction(async (conn) => {
    const weekKey = currentWeekKey();

    const [[tmpl]] = await conn.execute(
      'SELECT * FROM mission_templates WHERE id = ? AND active = 1',
      [templateId],
    );
    if (!tmpl) throw Object.assign(new Error('Mission not found'), { status: 404 });

    const periodKey = tmpl.type === 'weekly' ? weekKey : 'all';

    // Lock the user_missions row (or create it)
    await conn.execute(
      `INSERT IGNORE INTO user_missions (user_id, template_id, period_key, progress)
       VALUES (?, ?, ?, 0)`,
      [userId, templateId, periodKey],
    );
    const [[um]] = await conn.execute(
      `SELECT progress, claimed_at FROM user_missions
       WHERE user_id = ? AND template_id = ? AND period_key = ? FOR UPDATE`,
      [userId, templateId, periodKey],
    );

    if (um.progress < tmpl.target_count) {
      throw Object.assign(new Error('Mission not completed yet'), { status: 400 });
    }
    if (um.claimed_at) {
      throw Object.assign(new Error('Already claimed'), { status: 409 });
    }

    // Mark claimed
    await conn.execute(
      `UPDATE user_missions SET claimed_at = NOW()
       WHERE user_id = ? AND template_id = ? AND period_key = ?`,
      [userId, templateId, periodKey],
    );

    // Grant coins
    if (tmpl.reward_coins > 0) {
      await conn.execute(
        'INSERT IGNORE INTO wallets (user_id, balance) VALUES (?, 10000)',
        [userId],
      );
      await conn.execute(
        'UPDATE wallets SET balance = balance + ? WHERE user_id = ?',
        [tmpl.reward_coins, userId],
      );
    }

    // Grant tickets
    if (tmpl.reward_tickets > 0) {
      await conn.execute(
        'INSERT IGNORE INTO wallets (user_id, balance) VALUES (?, 10000)',
        [userId],
      );
      await conn.execute(
        'UPDATE wallets SET gacha_tickets = gacha_tickets + ? WHERE user_id = ?',
        [tmpl.reward_tickets, userId],
      );
    }

    return {
      coins: tmpl.reward_coins,
      tickets: tmpl.reward_tickets,
      xp: tmpl.reward_xp,
    };
  });
}

/**
 * Execute a gacha pull. Spends 1 ticket, returns a random S/SS/SSS item.
 */
export async function pullGacha(userId) {
  return transaction(async (conn) => {
    // Check and decrement ticket
    const [[wallet]] = await conn.execute(
      'SELECT gacha_tickets FROM wallets WHERE user_id = ? FOR UPDATE',
      [userId],
    );
    if (!wallet || wallet.gacha_tickets < 1) {
      throw Object.assign(new Error('No gacha tickets'), { status: 400 });
    }
    await conn.execute(
      'UPDATE wallets SET gacha_tickets = gacha_tickets - 1 WHERE user_id = ?',
      [userId],
    );

    // Pick grade by probability: S 60%, SS 30%, SSS 10%
    const roll = Math.random();
    let grade;
    if (roll < 0.1) grade = 'SSS';
    else if (roll < 0.4) grade = 'SS';
    else grade = 'S';

    // Pick random item of that grade
    const [[item]] = await conn.execute(
      `SELECT id, name, description, icon, slot, game,
              (SELECT JSON_OBJECTAGG(stat_key, stat_value) FROM item_stats WHERE item_id = shop_items.id) AS stats
       FROM shop_items
       WHERE grade = ? AND active = 1
       ORDER BY RAND()
       LIMIT 1`,
      [grade],
    );
    if (!item) throw Object.assign(new Error('No items in gacha pool'), { status: 500 });

    // Add to owned_items
    await conn.execute(
      'INSERT INTO owned_items (user_id, item_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE item_id = item_id',
      [userId, item.id],
    );

    // Track mission progress
    await updateMissionProgress(userId, 'gacha_pull');

    return {
      item: {
        ...item,
        grade,
        stats: item.stats ? JSON.parse(item.stats) : {},
      },
    };
  });
}
