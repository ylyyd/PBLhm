#!/usr/bin/env node
/**
 * MCP SQLite Server for OpenCode
 * Uses sql.js (pure JS, no native dependencies)
 *
 * Usage: node mcp-sqlite.cjs <path-to-db>
 */

const initSqlJs = require('sql.js');
const path = require('path');
const fs = require('fs');

const DB_PATH = path.resolve(process.argv[2] || '');
if (!DB_PATH || !fs.existsSync(DB_PATH)) {
  console.error('Usage: node mcp-sqlite.cjs <path-to-db>');
  console.error('Database not found:', DB_PATH);
  process.exit(1);
}

let db = null;
let SQL = null;

async function getDb() {
  if (db) return db;
  SQL = await initSqlJs();
  db = new SQL.Database(fs.readFileSync(DB_PATH));
  return db;
}

// JSON-RPC over stdio
function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

// Tool definitions
const TOOLS = [
  {
    name: 'list_tables',
    description: 'List all tables in the database',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'describe_table',
    description: 'Get schema for a specific table including columns, types, constraints',
    inputSchema: {
      type: 'object',
      properties: {
        tableName: { type: 'string', description: 'Name of the table' }
      },
      required: ['tableName']
    }
  },
  {
    name: 'query',
    description: 'Execute a SELECT query on the database',
    inputSchema: {
      type: 'object',
      properties: {
        sql: { type: 'string', description: 'SELECT SQL statement' }
      },
      required: ['sql']
    }
  },
  {
    name: 'db_info',
    description: 'Get database metadata including tables, row counts, and file size',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

async function handleTool(name, args) {
  const database = await getDb();

  switch (name) {
    case 'list_tables': {
      const result = database.exec(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
      );
      const tables = result[0]?.values.map(r => r[0]) || [];
      return { content: [{ type: 'text', text: tables.join('\n') }] };
    }

    case 'describe_table': {
      const t = args.tableName.replace(/'/g, "''");
      const cols = database.exec(`PRAGMA table_info('${t}')`);
      const fks = database.exec(`PRAGMA foreign_key_list('${t}')`);
      const indexes = database.exec(`PRAGMA index_list('${t}')`);
      const colData = cols[0]?.values || [];
      const fkData = fks[0]?.values || [];
      const idxData = indexes[0]?.values || [];
      const info = {
        table: args.tableName,
        columns: colData.map(function(c) { return {
          cid: c[0], name: c[1], type: c[2], notNull: !!c[3], defaultValue: c[4], pk: !!c[5]
        }}),
        foreignKeys: fkData.map(function(f) { return {
          id: f[0], seq: f[1], table: f[2], from: f[3], to: f[4], onUpdate: f[5], onDelete: f[6]
        }}),
        indexes: idxData.map(function(i) { return {
          seq: i[0], name: i[1], unique: !!i[2]
        }})
      };
      return { content: [{ type: 'text', text: JSON.stringify(info, null, 2) }] };
    }

    case 'query': {
      if (!/^\s*SELECT\b/i.test(args.sql)) {
        return {
          content: [{ type: 'text', text: 'Only SELECT queries are allowed for safety.' }],
          isError: true
        };
      }
      try {
        const result = database.exec(args.sql);
        if (!result.length) return { content: [{ type: 'text', text: '[]' }] };

        const columns = result[0].columns;
        const rows = result[0].values;
        const output = {
          columns: columns,
          rows: rows.slice(0, 100),
          totalRows: rows.length,
          truncated: rows.length > 100
        };
        return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }] };
      } catch (err) {
        return { content: [{ type: 'text', text: 'Error: ' + err.message }], isError: true };
      }
    }

    case 'db_info': {
      const tableList = database.exec(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
      );
      const tables = (tableList[0]?.values || []).map(function(r) { return r[0] });
      const info = [];
      for (const t of tables) {
        const safe = t.replace(/'/g, "''");
        const cnt = database.exec(`SELECT COUNT(*) AS c FROM '${safe}'`);
        info.push({ table: t, rowCount: cnt[0]?.values[0][0] || 0 });
      }
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            database: path.basename(DB_PATH),
            sizeBytes: fs.statSync(DB_PATH).size,
            tables: info
          }, null, 2)
        }]
      };
    }

    default:
      return { content: [{ type: 'text', text: `Unknown tool: ${name}` }], isError: true };
  }
}

// ── MCP stdio transport ──
const buf = (() => {
  let data = '';
  return {
    push(chunk) {
      data += chunk;
      const lines = data.split('\n');
      data = lines.pop() || '';
      return lines.filter(l => l.trim());
    }
  };
})();

process.stdin.on('data', function(chunk) {
  const lines = buf.push(chunk.toString());
  for (const line of lines) {
    try {
      const msg = JSON.parse(line);
      handleMessage(msg);
    } catch { /* skip malformed */ }
  }
});

async function handleMessage(msg) {
  const { id, method, params = {} } = msg;

  try {
    switch (method) {
      case 'initialize':
        send({
          jsonrpc: '2.0', id,
          result: {
            protocolVersion: '2024-11-05',
            capabilities: { tools: {} },
            serverInfo: { name: 'harmony-sqlite-mcp', version: '1.0.0' }
          }
        });
        break;

      case 'notifications/initialized':
        // No response needed
        break;

      case 'tools/list':
        send({ jsonrpc: '2.0', id, result: { tools: TOOLS } });
        break;

      case 'tools/call': {
        const result = await handleTool(params.name, params.arguments || {});
        send({ jsonrpc: '2.0', id, result });
        break;
      }

      default:
        send({ jsonrpc: '2.0', id, error: { code: -32601, message: `Unknown method: ${method}` } });
    }
  } catch (err) {
    if (id) {
      send({ jsonrpc: '2.0', id, error: { code: -32603, message: err.message } });
    }
  }
}

console.error('MCP SQLite server ready:', DB_PATH);
