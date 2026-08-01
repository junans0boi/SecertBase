import { query, transaction } from './db.js';

const DAILY_BONUS = 500;
const STARTING_BALANCE = 10000;

async function _resolveUserId(userCode) {
  const { rows } = await query('SELECT UserId FROM Users WHERE UserCode = ?', [userCode]);
  if (!rows[0]) throw new Error(`Unknown UserCode: ${userCode}`);
  return rows[0].UserId;
}

async function _ensureWallet(conn, numericUserId) {
  await conn.execute(
    'INSERT IGNORE INTO wallets (user_id, balance) VALUES (?, ?)',
    [numericUserId, STARTING_BALANCE]
  );
}

export async function getBalance(userId) {
  await query(
    'INSERT IGNORE INTO wallets (user_id, balance) VALUES (?, ?)',
    [userId, STARTING_BALANCE]
  );
  const { rows } = await query(
    'SELECT balance, last_bonus_date FROM wallets WHERE user_id = ?',
    [userId]
  );
  return rows[0];
}

export async function claimDailyBonus(userId) {
  const today = new Date().toISOString().slice(0, 10);
  // daily_bonus_add: 장착 아이템으로 일일 보너스 증가
  const stats = await getEquippedStats(userId);
  const bonusAdd = Math.floor(stats.daily_bonus_add ?? 0);
  const totalBonus = DAILY_BONUS + bonusAdd;

  return await transaction(async (conn) => {
    await _ensureWallet(conn, userId);
    const [[wallet]] = await conn.execute(
      'SELECT balance, last_bonus_date FROM wallets WHERE user_id = ? FOR UPDATE',
      [userId]
    );
    const lastDate = wallet.last_bonus_date
      ? wallet.last_bonus_date.toISOString?.().slice(0, 10) ?? String(wallet.last_bonus_date).slice(0, 10)
      : null;
    if (lastDate === today) {
      return { already_claimed: true, balance: wallet.balance };
    }
    const newBalance = wallet.balance + totalBonus;
    await conn.execute(
      'UPDATE wallets SET balance = ?, last_bonus_date = ? WHERE user_id = ?',
      [newBalance, today, userId]
    );
    await conn.execute(
      'INSERT INTO wallet_transactions (user_id, delta, balance_after, reason) VALUES (?, ?, ?, ?)',
      [userId, totalBonus, newBalance, 'daily_bonus']
    );
    return { already_claimed: false, balance: newBalance, delta: totalBonus };
  });
}

// 게임 결과 정산: 올인 캡 적용 원자적 이체
// winnerCode/loserCode는 UserCode(소켓 userId) — 내부에서 numeric UserId로 변환
// winnerBonusPct: coin_bonus_pct from equipped items (0–20)
// catchBonus: flat coin bonus accumulated during game (catches + win_coin + streak)
// loserRefundPct: lose_refund_pct — loser gets back % of loss (max 20%)
export async function transferGameReward(winnerCode, loserCode, amount, gameRef, { winnerBonusPct = 0, catchBonus = 0, loserRefundPct = 0 } = {}) {
  const [winnerId, loserId] = await Promise.all([
    _resolveUserId(winnerCode),
    _resolveUserId(loserCode),
  ]);
  return await transaction(async (conn) => {
    await _ensureWallet(conn, winnerId);
    await _ensureWallet(conn, loserId);
    const [[loser]] = await conn.execute(
      'SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE',
      [loserId]
    );
    const [[winner]] = await conn.execute(
      'SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE',
      [winnerId]
    );
    const actual = Math.min(amount, loser.balance); // 올인 캡
    const bonusMultiplier = 1 + Math.min(winnerBonusPct, 20) / 100;
    const winnerGain = Math.floor(actual * bonusMultiplier) + Math.floor(catchBonus);

    // lose_refund_pct: loser gets back % of their loss (창출 코인, 최대 20%)
    const refundAmt = Math.floor(actual * Math.min(loserRefundPct, 20) / 100);
    const loserAfter = loser.balance - actual + refundAmt;
    const winnerAfter = winner.balance + winnerGain;

    await conn.execute('UPDATE wallets SET balance = ? WHERE user_id = ?', [loserAfter, loserId]);
    await conn.execute('UPDATE wallets SET balance = ? WHERE user_id = ?', [winnerAfter, winnerId]);
    await conn.execute(
      'INSERT INTO wallet_transactions (user_id, delta, balance_after, reason, ref_id) VALUES (?, ?, ?, ?, ?)',
      [winnerId, winnerGain, winnerAfter, 'game_win', gameRef]
    );
    await conn.execute(
      'INSERT INTO wallet_transactions (user_id, delta, balance_after, reason, ref_id) VALUES (?, ?, ?, ?, ?)',
      [loserId, -(actual - refundAmt), loserAfter, 'game_loss', gameRef]
    );
    return { actual, winnerGain, winnerBalance: winnerAfter, loserBalance: loserAfter, loserRefund: refundAmt };
  });
}

// 유저의 장착 아이템 스탯 집계 (게임 시작 시 호출)
export async function getEquippedStats(userId) {
  const { rows } = await query(
    `SELECT ist.stat_key, SUM(ist.stat_value) AS total
     FROM equipped_items ei
     JOIN item_stats ist ON ist.item_id = ei.item_id
     WHERE ei.user_id = ?
     GROUP BY ist.stat_key`,
    [userId]
  );
  const stats = {};
  for (const row of rows) {
    stats[row.stat_key] = Number(row.total);
  }
  return stats;
}

// 유저의 장착 아이템 정보 (슬롯별 이름/아이콘/등급) — 상대방 표시용
export async function getEquippedItemsInfo(userId) {
  const { rows } = await query(
    `SELECT ei.slot, si.name, si.icon, si.grade,
            (SELECT JSON_OBJECTAGG(stat_key, stat_value)
             FROM item_stats WHERE item_id = si.id) AS stats
     FROM equipped_items ei
     JOIN shop_items si ON si.id = ei.item_id
     WHERE ei.user_id = ?`,
    [userId]
  );
  const info = {};
  for (const row of rows) {
    info[row.slot] = {
      name: row.name,
      icon: row.icon,
      grade: row.grade,
      stats: row.stats ? JSON.parse(row.stats) : {},
    };
  }
  return info;
}
