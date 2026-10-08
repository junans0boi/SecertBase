import mysql from 'mysql2/promise';
import { config } from './config.js';

// MariaDB 연결 풀. 테스트 하네스는 같은 프로세스에서 disposable DB를
// 순차적으로 교체하므로, 닫힌 풀도 현재 설정으로 다시 만들 수 있어야 한다.
let pool = mysql.createPool(config.DATABASE_URL);
let poolUrl = config.DATABASE_URL;

const getPool = () => {
  const nextUrl = config.DATABASE_URL;
  if (pool && poolUrl === nextUrl) return pool;

  const previousPool = pool;
  pool = mysql.createPool(nextUrl);
  poolUrl = nextUrl;
  if (previousPool) void previousPool.end().catch(() => {});
  return pool;
};

// 연결 테스트
getPool().getConnection()
  .then(conn => {
    console.log('[DB] MariaDB connected');
    conn.release();
  })
  .catch(err => {
    console.error('[DB] Connection error:', err);
  });

/**
 * SQL 쿼리 실행 헬퍼
 * @param {string} text - SQL 쿼리
 * @param {Array} params - 파라미터 배열
 */
export async function query(text, params = []) {
  const start = Date.now();
  try {
    // MariaDB/MySQL은 $1 대신 ?를 사용하므로 호환성을 위해 변환하거나 직접 ? 사용 권장
    // 여기서는 신규 코드이므로 ?를 사용하도록 안내하고 래퍼 제공
    const [rows] = await getPool().execute(text, params);
    const duration = Date.now() - start;
    console.log('[DB] Query executed', { text: text.substring(0, 50), duration, rowCount: rows.length });
    return { rows };
  } catch (err) {
    console.error('[DB] Query error:', { text, params, error: err.message });
    throw err;
  }
}

/**
 * 트랜잭션 헬퍼
 * @param {Function} callback - 트랜잭션 콜백 (connection) => Promise
 */
export async function transaction(callback) {
  const connection = await getPool().getConnection();
  try {
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}

/**
 * 연결 종료
 */
export async function close() {
  const activePool = pool;
  pool = null;
  if (activePool) await activePool.end();
  console.log('[DB] MariaDB connection closed');
}

export default { query, transaction, close };
