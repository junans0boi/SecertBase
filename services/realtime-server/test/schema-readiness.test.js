import assert from 'node:assert/strict';
import test from 'node:test';
import { assertSchemaReady } from '../src/schema-readiness.js';

const schemaRows = {
  tables: [
    { TABLE_NAME: 'Users' },
    { TABLE_NAME: 'setlog_posts' },
    { TABLE_NAME: 'map_pins' },
    { TABLE_NAME: 'setlog_reactions' },
  ],
  columns: [
    { TABLE_NAME: 'Users', COLUMN_NAME: 'IsDeleted' },
    { TABLE_NAME: 'Users', COLUMN_NAME: 'DeletedAt' },
    { TABLE_NAME: 'setlog_posts', COLUMN_NAME: 'map_pin_id' },
    { TABLE_NAME: 'setlog_posts', COLUMN_NAME: 'session_id' },
    { TABLE_NAME: 'map_pins', COLUMN_NAME: 'media_url' },
  ],
};

const fakeQuery = async (sql) => ({
  rows: sql.includes('INFORMATION_SCHEMA.TABLES')
    ? schemaRows.tables
    : schemaRows.columns,
});

test('schema readiness passes when request-time dependencies exist', async () => {
  assert.deepEqual(await assertSchemaReady({ queryFn: fakeQuery }), { ok: true });
});

test('schema readiness fails before serving when a dependency is missing', async () => {
  await assert.rejects(
    assertSchemaReady({
      queryFn: async (sql) => {
        const result = await fakeQuery(sql);
        return {
          rows: result.rows.filter((row) =>
            !(row.TABLE_NAME === 'map_pins' && row.COLUMN_NAME === 'media_url')),
        };
      },
    }),
    /Missing column map_pins\.media_url/,
  );
});
