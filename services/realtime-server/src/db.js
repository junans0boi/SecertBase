/**
 * PostgreSQL Database Connection
 * Phase 3: Archiving Zone (Setlog, Map, Q&A, Challenges, Jukebox)
 */

import pg from 'pg';
import { config } from './config.js';

const { Pool } = pg;

// PostgreSQL 연결 풀
const pool = new Pool({
  connectionString: config.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// 연결 테스트
pool.on('connect', () => {
  console.log('[DB] PostgreSQL connected');
});

pool.on('error', (err) => {
  console.error('[DB] Unexpected error:', err);
});

/**
 * SQL 쿼리 실행 헬퍼
 * @param {string} text - SQL 쿼리
 * @param {Array} params - 파라미터 배열
 */
export async function query(text, params = []) {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    console.log('[DB] Query executed', { text: text.substring(0, 50), duration, rows: res.rowCount });
    return res;
  } catch (err) {
    console.error('[DB] Query error:', { text, params, error: err.message });
    throw err;
  }
}

/**
 * 트랜잭션 헬퍼
 * @param {Function} callback - 트랜잭션 콜백 (client) => Promise
 */
export async function transaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * 연결 종료
 */
export async function close() {
  await pool.end();
  console.log('[DB] PostgreSQL connection closed');
}

export default { query, transaction, close };
