import { query, transaction } from './db.js';

const DAILY_BONUS = 500;
const STARTING_BALANCE = 10000;

async function _ensureWallet(conn, userId) {
  await conn.execute(
    'INSERT IGNORE INTO wallets (user_id, balance) VALUES (?, ?)',
    [userId, STARTING_BALANCE]
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
    const newBalance = wallet.balance + DAILY_BONUS;
    await conn.execute(
      'UPDATE wallets SET balance = ?, last_bonus_date = ? WHERE user_id = ?',
      [newBalance, today, userId]
    );
    await conn.execute(
      'INSERT INTO wallet_transactions (user_id, delta, balance_after, reason) VALUES (?, ?, ?, ?)',
      [userId, DAILY_BONUS, newBalance, 'daily_bonus']
    );
    return { already_claimed: false, balance: newBalance, delta: DAILY_BONUS };
  });
}

// 게임 결과 정산: 올인 캡 적용 원자적 이체
export async function transferGameReward(winnerId, loserId, amount, gameRef) {
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
    const loserAfter = loser.balance - actual;
    const winnerAfter = winner.balance + actual;
    await conn.execute('UPDATE wallets SET balance = ? WHERE user_id = ?', [loserAfter, loserId]);
    await conn.execute('UPDATE wallets SET balance = ? WHERE user_id = ?', [winnerAfter, winnerId]);
    await conn.execute(
      'INSERT INTO wallet_transactions (user_id, delta, balance_after, reason, ref_id) VALUES (?, ?, ?, ?, ?)',
      [winnerId, actual, winnerAfter, 'game_win', gameRef]
    );
    await conn.execute(
      'INSERT INTO wallet_transactions (user_id, delta, balance_after, reason, ref_id) VALUES (?, ?, ?, ?, ?)',
      [loserId, -actual, loserAfter, 'game_loss', gameRef]
    );
    return { actual, winnerBalance: winnerAfter, loserBalance: loserAfter };
  });
}
