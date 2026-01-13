import { mkdirSync, existsSync, readFileSync, writeFileSync } from 'fs';
import { dirname } from 'path';
import { env } from './index.js';

// Simple JSON file-based store for Phase 1
// TODO: Replace with SQLite or PostgreSQL for production

interface Database {
  devices: Device[];
  printers: Printer[];
  printJobs: PrintJob[];
  notificationSettings: NotificationSettings[];
}

interface Device {
  id: string;
  apnsToken: string | null;
  activityToken: string | null;
  haUrl: string;
  haToken: string;
  entityPrefix: string | null;
  createdAt: string;
  lastSeen: string;
}

interface Printer {
  id: string;
  deviceId: string;
  entityPrefix: string;
  displayName: string | null;
  model: string | null;
  isPrimary: boolean;
  discoveredAt: string;
}

interface PrintJob {
  id: string;
  deviceId: string;
  printerPrefix: string | null;
  filename: string;
  startedAt: string | null;
  completedAt: string | null;
  durationSeconds: number | null;
  status: string | null;
  finalLayer: number | null;
  totalLayers: number | null;
  filamentUsedMm: number | null;
}

interface NotificationSettings {
  deviceId: string;
  onStart: boolean;
  onComplete: boolean;
  onFailed: boolean;
  onPaused: boolean;
  onMilestone: boolean;
}

const emptyDatabase: Database = {
  devices: [],
  printers: [],
  printJobs: [],
  notificationSettings: [],
};

let db: Database | null = null;

function getDbPath(): string {
  return env.DATABASE_PATH.replace('.db', '.json');
}

export function getDatabase(): Database {
  if (db) return db;

  const dbPath = getDbPath();
  const dbDir = dirname(dbPath);

  if (!existsSync(dbDir)) {
    mkdirSync(dbDir, { recursive: true });
  }

  if (existsSync(dbPath)) {
    try {
      const content = readFileSync(dbPath, 'utf-8');
      db = JSON.parse(content);
    } catch {
      db = { ...emptyDatabase };
    }
  } else {
    db = { ...emptyDatabase };
    saveDatabase();
  }

  return db!;
}

export function saveDatabase(): void {
  if (!db) return;

  const dbPath = getDbPath();
  writeFileSync(dbPath, JSON.stringify(db, null, 2), 'utf-8');
}

export function closeDatabase(): void {
  if (db) {
    saveDatabase();
    db = null;
  }
}

// Export types for use in other modules
export type { Database, Device, Printer, PrintJob, NotificationSettings };
