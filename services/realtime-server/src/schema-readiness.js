const defaultQuery = async (...args) => {
  const { query } = await import('./db.js');
  return query(...args);
};

// Keep this list limited to schema that was previously created lazily during
// requests. New request-time schema dependencies belong here and in a numbered
// migration, so a missing deployment fails at startup with an actionable error.
export const REQUIRED_SCHEMA = Object.freeze({
  Users: ['IsDeleted', 'DeletedAt'],
  setlog_posts: ['map_pin_id', 'session_id'],
  map_pins: ['media_url'],
  setlog_reactions: [],
});

export async function assertSchemaReady({
  queryFn = defaultQuery,
  requiredSchema = REQUIRED_SCHEMA,
} = {}) {
  const tableResult = await queryFn(
    `SELECT TABLE_NAME
     FROM INFORMATION_SCHEMA.TABLES
     WHERE TABLE_SCHEMA = DATABASE()`,
  );
  const columnResult = await queryFn(
    `SELECT TABLE_NAME, COLUMN_NAME
     FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()`,
  );

  const tables = new Set(tableResult.rows.map((row) => String(row.TABLE_NAME)));
  const columns = new Map();
  for (const row of columnResult.rows) {
    const table = String(row.TABLE_NAME);
    if (!columns.has(table)) columns.set(table, new Set());
    columns.get(table).add(String(row.COLUMN_NAME));
  }

  const missingTables = [];
  const missingColumns = [];
  for (const [table, requiredColumns] of Object.entries(requiredSchema)) {
    if (!tables.has(table)) {
      missingTables.push(table);
      continue;
    }
    const presentColumns = columns.get(table) ?? new Set();
    for (const column of requiredColumns) {
      if (!presentColumns.has(column)) missingColumns.push(`${table}.${column}`);
    }
  }

  if (missingTables.length || missingColumns.length) {
    const missing = [
      ...missingTables.map((table) => `table ${table}`),
      ...missingColumns.map((column) => `column ${column}`),
    ].join(', ');
    throw new Error(
      `Database schema is not ready; run the numbered migrations before starting the server. Missing ${missing}`,
    );
  }

  return { ok: true };
}
