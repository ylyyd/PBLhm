#!/usr/bin/env node
/**
 * Lightweight MCP SQLite Server for OpenCode
 * Uses sql.js (pure JS, no native deps)
 *
 * Usage: node mcp-sqlite-server.cjs <path-to-db>
 */

const initSqlJs = require('sql.js');
const path = require('path');
const fs = require('fs');

const DB_PATH = process.argv[2];
if (!DB_PATH) {
  console.error('Usage: node mcp-sqlite-server.cjs <path-to-db>');
  process.exit(1);
}

const absPath = path.resolve(DB_PATH);

// MCP stdio transport — read JSON-RPC from stdin, write to stdout
const readline = require('readline');
const rl = readline.createInterface({ input: process.stdin, terminal: false });

let db = null;
let SQL = null;

async function getDb() {
  if (db) return db;
  SQL = await initSqlJs();
  const buf = fs.readFileSync(absPath);
  db = new SQL.Database(buf);
  // Enable WAL mode for concurrent reads
  db.run('PRAGMA journal_mode=WAL');
  return db;
}

function sendMessage(msg) {
  const str = JSON.stringify(msg);
  process.stdout.write(str.length + '\n' + str);
}

// Tool definitions
const TOOLS = [
  {
    name: 'list_tables',
    description: 'List all tables in the database',
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_table_schema',
    description: 'Get schema for a specific table',
    inputSchema: {
      type: 'object',
      properties: {
        tableName: { type: 'string', description: 'Table name' }
      },
      required: ['tableName']
    }
  },
  {
    name: 'query',
    description: 'Execute a read-only SELECT query',
    inputSchema: {
      type: 'object',
      properties: {
        sql: { type: 'string', description: 'SELECT SQL query' }
      },
      required: ['sql']
    }
  },
  {
    name: 'get_db_info',
    description: 'Get database metadata (tables, size, row counts)',
    inputSchema: { type: 'object', properties: {} }
  }
];

async function handleCallTool(name, args) {
  const database = await getDb();
  switch (name) {
    case 'list_tables': {
      const stmt = database.exec("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
      const tables = stmt.length > 0 ? stmt[0].values.map(v => v[0]) : [];
      return { content: [{ type: 'text', text: JSON.stringify(tables, null, 2) }] };
    }
    case 'get_table_schema': {
      const { tableName } = args;
      const cols = database.exec(`PRAGMA table_info('${tableName.replace(/'/g, "''")}')`);
      const foreignKeys = database.exec(`PRAGMA foreign_key_list('${tableName.replace(/'/g, "''")}')`);
      return {
        content: [
          { type: 'text', text: JSON.stringify({ columns: cols[0]?.values || [], foreignKeys: foreignKeys[0]?.values || [] }, null, 2) }
        ]
      };
    }
    case 'query': {
      const { sql } = args;
      if (!/^\s*SELECT/i.test(sql)) {
        return { content: [{ type: 'text', text: JSON.stringify({ error: 'Only SELECT queries are allowed' }) }], isError: true };
      }
      try {
        const result = database.exec(sql);
        return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
      } catch (err) {
        return { content: [{ type: 'text', text: JSON.stringify({ error: err.message }) }], isError: true };
      }
    }
    case 'get_db_info': {
      const tables = database.exec("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
      const tableNames = tables.length > 0 ? tables[0].values.map(v => v[0]) : [];
      const info = [];
      for (const t of tableNames) {
        const count = database.exec(`SELECT COUNT(*) as cnt FROM '${t.replace(/'/g, "''")}'`);
        const c = count[0]?.values[0][0] || 0;
        info.push({ table: t, rowCount: c });
      }
      const stats = fs.statSync(absPath);
      return {
        content: [{ type: 'text', text: JSON.stringify({
          database: path.basename(absPath),
          sizeBytes: stats.size,
          tables: info
        }, null, 2) }]
      };
    }
    default:
      return { content: [{ type: 'text', text: JSON.stringify({ error: `Unknown tool: ${name}` }) }], isError: true };
  }
}

// Handle incoming JSON-RPC messages
let buffer = '';
let expectedLength = null;

rl.on('line', async (line) => {
  try {
    if (expectedLength === null) {
      // First line is content length
      const match = line.match(/^Content-Length:\s*(\d+)/i);
      if (match) {
        expectedLength = parseInt(match[1], 10);
      }
      return;
    }

    // Empty line after headers — next line(s) are content
    if (line === '') return;

    // This is the content
    const msg = JSON.parse(line);
    expectedLength = null;

    const id = msg.id;
    const method = msg.method;
    const params = msg.params || {};

    switch (method) {
      case 'initialize': {
        sendMessage({
          jsonrpc: '2.0',
          id,
          result: {
            protocolVersion: '2024-11-05',
            capabilities: {
              tools: {}
            },
            serverInfo: { name: 'harmony-sqlite-mcp', version: '1.0.0' }
          }
        });
        break;
      }
      case 'tools/list': {
        sendMessage({
          jsonrpc: '2.0',
          id,
          result: { tools: TOOLS }
        });
        break;
      }
      case 'tools/call': {
        const result = await handleCallTool(params.name, params.arguments || {});
        sendMessage({
          jsonrpc: '2.0',
          id,
          result
        });
        break;
      }
      case 'notifications/initialized': {
        // No response needed
        break;
      }
      default: {
        sendMessage({
          jsonrpc: '2.0',
          id: id || null,
          error: { code: -32601, message: `Method not found: ${method}` }
        });
      }
    }
  } catch (err) {
    console.error('MCP Error:', err);
  }
});

// Handle raw stdin for stdio MCP transport
process.stdin.on('data', (chunk) => {
  // stdio MCP uses newline-delimited JSON
  const text = chunk.toString();
  const lines = text.split('\n').filter(l => l.trim());
  for (const line of lines) {
    try {
      const msg = JSON.parse(line);
      handleMessage(msg);
    } catch (e) {
      // Not JSON, might be part of stream protocol
    }
  }
});

async function handleMessage(msg) {
  const id = msg.id;
  const method = msg.method;
  const params = msg.params || {};

  switch (method) {
    case 'initialize':
      sendMessage({
        jsonrpc: '2.0',
        id,
        result: {
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'harmony-sqlite-mcp', version: '1.0.0' }
        }
      });
      break;
    case 'tools/list':
      sendMessage({
        jsonrpc: '2.0',
        id,
        result: { tools: TOOLS }
      });
      break;
    case 'tools/call': {
      const result = await handleCallTool(params.name, params.arguments || {});
      sendMessage({ jsonrpc: '2.0', id, result });
      break;
    }
    default:
      if (id) {
        sendMessage({ jsonrpc: '2.0', id, error: { code: -32601, message: `Method not found: ${method}` } });
      }
  }
}

// Signal ready
console.error('MCP SQLite server ready');
