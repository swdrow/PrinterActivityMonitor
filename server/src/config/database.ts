import Database from 'better-sqlite3';
import { env } from './index.js';
import { mkdirSync, existsSync } from 'fs';
import { dirname } from 'path';

let db: Database.Database | null = null;

export function getDatabase(): Database.Database {
  if (db) return db;

  const dbPath = env.DATABASE_PATH;
  const dbDir = dirname(dbPath);

  if (!existsSync(dbDir)) {
    mkdirSync(dbDir, { recursive: true });
  }

  db = new Database(dbPath);
  db.pragma('journal_mode = WAL');

  initializeTables(db);

  return db;
}

function initializeTables(db: Database.Database): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      apns_token TEXT,
      activity_token TEXT,
      ha_url TEXT NOT NULL,
      ha_token TEXT NOT NULL,
      entity_prefix TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_seen TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS printers (
      id TEXT PRIMARY KEY,
      device_id TEXT REFERENCES devices(id),
      entity_prefix TEXT NOT NULL,
      display_name TEXT,
      model TEXT,
      is_primary INTEGER DEFAULT 0,
      discovered_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS print_jobs (
      id TEXT PRIMARY KEY,
      device_id TEXT REFERENCES devices(id),
      printer_prefix TEXT,
      filename TEXT NOT NULL,
      started_at TEXT,
      completed_at TEXT,
      duration_seconds INTEGER,
      status TEXT,
      final_layer INTEGER,
      total_layers INTEGER,
      filament_used_mm REAL
    );

    CREATE TABLE IF NOT EXISTS notification_settings (
      device_id TEXT PRIMARY KEY REFERENCES devices(id),
      on_start INTEGER DEFAULT 1,
      on_complete INTEGER DEFAULT 1,
      on_failed INTEGER DEFAULT 1,
      on_paused INTEGER DEFAULT 1,
      on_milestone INTEGER DEFAULT 1
    );
  `);
}

export function closeDatabase(): void {
  if (db) {
    db.close();
    db = null;
  }
}
