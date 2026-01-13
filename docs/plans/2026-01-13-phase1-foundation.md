# Phase 1: Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the monorepo structure with Node.js server skeleton and iOS app shell with basic navigation.

**Architecture:** Monorepo with `/server` (Node.js + Express + TypeScript + SQLite) and `/ios` (SwiftUI iOS 26 app). Server provides REST API endpoints; iOS app has tab-based navigation with placeholder views.

**Tech Stack:**
- Server: Node.js 20+, Express, TypeScript, SQLite (better-sqlite3), dotenv
- iOS: Swift 6, SwiftUI, iOS 26, @Observable pattern

---

## Prerequisites

Before starting, ensure:
- Node.js 20+ installed (`node --version`)
- Xcode 16+ installed with iOS 26 SDK
- Current directory is `/Users/samduncan/Documents/PrinterActivityMonitor`

---

## Task 1: Create Monorepo Directory Structure

**Files:**
- Create: `server/` directory
- Create: `ios/` directory
- Move: existing iOS files to archive (preserve for reference)

**Step 1: Create the new directory structure**

```bash
mkdir -p server/src/{config,routes,services,models,utils}
mkdir -p ios
```

**Step 2: Verify structure exists**

Run: `ls -la server/src/`
Expected: config, routes, services, models, utils directories

**Step 3: Commit structure**

```bash
git add server/
git commit -m "chore: create monorepo server directory structure"
```

---

## Task 2: Initialize Node.js Server Package

**Files:**
- Create: `server/package.json`
- Create: `server/tsconfig.json`
- Create: `server/.env.example`
- Create: `server/.gitignore`

**Step 1: Create package.json**

Create file `server/package.json`:

```json
{
  "name": "printer-monitor-server",
  "version": "1.0.0",
  "description": "Backend server for Printer Activity Monitor",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint src/",
    "test": "vitest",
    "test:run": "vitest run"
  },
  "keywords": ["home-assistant", "3d-printer", "bambulab"],
  "author": "Sam Duncan",
  "license": "MIT",
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^20.11.0",
    "@types/better-sqlite3": "^7.6.8",
    "@types/uuid": "^9.0.7",
    "eslint": "^8.56.0",
    "@typescript-eslint/eslint-plugin": "^6.19.0",
    "@typescript-eslint/parser": "^6.19.0",
    "tsx": "^4.7.0",
    "typescript": "^5.3.3",
    "vitest": "^1.2.0"
  },
  "dependencies": {
    "better-sqlite3": "^9.3.0",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "uuid": "^9.0.1",
    "ws": "^8.16.0",
    "zod": "^3.22.4"
  }
}
```

**Step 2: Create tsconfig.json**

Create file `server/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**Step 3: Create .env.example**

Create file `server/.env.example`:

```bash
# Server Configuration
PORT=3000
NODE_ENV=development

# Database
DATABASE_PATH=./data/printer-monitor.db

# Security
ENCRYPTION_KEY=your-32-character-encryption-key

# APNs (required for push notifications - leave empty for dev)
APNS_KEY_ID=
APNS_TEAM_ID=
APNS_KEY_PATH=
APNS_BUNDLE_ID=
```

**Step 4: Create .gitignore for server**

Create file `server/.gitignore`:

```
node_modules/
dist/
.env
*.db
*.db-journal
data/
.DS_Store
```

**Step 5: Verify files exist**

Run: `ls server/`
Expected: package.json, tsconfig.json, .env.example, .gitignore

**Step 6: Commit**

```bash
git add server/package.json server/tsconfig.json server/.env.example server/.gitignore
git commit -m "chore: initialize Node.js server package configuration"
```

---

## Task 3: Create Server Entry Point and Config

**Files:**
- Create: `server/src/index.ts`
- Create: `server/src/config/index.ts`
- Create: `server/src/config/database.ts`

**Step 1: Create config/index.ts**

Create file `server/src/config/index.ts`:

```typescript
import { config } from 'dotenv';
import { z } from 'zod';

config();

const envSchema = z.object({
  PORT: z.string().default('3000'),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  DATABASE_PATH: z.string().default('./data/printer-monitor.db'),
  ENCRYPTION_KEY: z.string().optional(),
  APNS_KEY_ID: z.string().optional(),
  APNS_TEAM_ID: z.string().optional(),
  APNS_KEY_PATH: z.string().optional(),
  APNS_BUNDLE_ID: z.string().optional(),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment variables:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;

export const isDev = env.NODE_ENV === 'development';
export const isProd = env.NODE_ENV === 'production';
export const isTest = env.NODE_ENV === 'test';
```

**Step 2: Create config/database.ts**

Create file `server/src/config/database.ts`:

```typescript
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
```

**Step 3: Create index.ts entry point**

Create file `server/src/index.ts`:

```typescript
import express from 'express';
import { env, isDev } from './config/index.js';
import { getDatabase } from './config/database.js';

const app = express();

// Middleware
app.use(express.json());

// Initialize database
const db = getDatabase();
console.log('Database initialized');

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: env.NODE_ENV,
  });
});

// API routes placeholder
app.get('/api', (req, res) => {
  res.json({
    message: 'Printer Monitor API',
    version: '1.0.0',
    endpoints: [
      'GET /health',
      'POST /api/auth/validate',
      'POST /api/devices/register',
      'POST /api/discovery/scan',
      'GET /api/history',
      'GET /api/printers/state',
    ],
  });
});

// Start server
const PORT = parseInt(env.PORT, 10);

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  if (isDev) {
    console.log('Running in development mode');
  }
});

export { app };
```

**Step 4: Verify files exist**

Run: `ls server/src/ && ls server/src/config/`
Expected: index.ts in src/, index.ts and database.ts in config/

**Step 5: Commit**

```bash
git add server/src/
git commit -m "feat(server): add entry point and database configuration"
```

---

## Task 4: Install Server Dependencies and Test

**Files:**
- Modify: `server/node_modules/` (created by npm)

**Step 1: Install dependencies**

Run from server directory:
```bash
cd server && npm install
```

Expected: Dependencies installed, node_modules created

**Step 2: Create .env file for local development**

```bash
cp server/.env.example server/.env
```

**Step 3: Start development server**

Run: `cd server && npm run dev`

Expected output (partial):
```
Database initialized
Server running on http://localhost:3000
Running in development mode
```

**Step 4: Test health endpoint (in new terminal)**

Run: `curl http://localhost:3000/health`

Expected:
```json
{"status":"ok","timestamp":"...","environment":"development"}
```

**Step 5: Stop server (Ctrl+C) and commit**

```bash
git add server/package-lock.json
git commit -m "chore(server): install dependencies"
```

---

## Task 5: Add Server Health and Auth Route Tests

**Files:**
- Create: `server/src/routes/auth.ts`
- Create: `server/tests/health.test.ts`
- Create: `server/tests/auth.test.ts`
- Create: `server/vitest.config.ts`

**Step 1: Create vitest config**

Create file `server/vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
});
```

**Step 2: Create health endpoint test**

Create file `server/tests/health.test.ts`:

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { app } from '../src/index.js';

describe('Health Endpoint', () => {
  it('returns status ok', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(response.body.timestamp).toBeDefined();
  });
});
```

**Step 3: Add supertest to devDependencies**

Run: `cd server && npm install --save-dev supertest @types/supertest`

**Step 4: Run test to verify it passes**

Run: `cd server && npm run test:run`

Expected: Test passes

**Step 5: Create auth route skeleton**

Create file `server/src/routes/auth.ts`:

```typescript
import { Router } from 'express';
import { z } from 'zod';

const router = Router();

const validateSchema = z.object({
  haUrl: z.string().url(),
  haToken: z.string().min(1),
});

router.post('/validate', async (req, res) => {
  const parsed = validateSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      error: 'Invalid request',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { haUrl, haToken } = parsed.data;

  try {
    // Test connection to Home Assistant
    const response = await fetch(`${haUrl}/api/`, {
      headers: {
        Authorization: `Bearer ${haToken}`,
        'Content-Type': 'application/json',
      },
    });

    if (response.ok) {
      return res.json({ valid: true, message: 'Home Assistant connection successful' });
    } else {
      return res.status(401).json({ valid: false, message: 'Invalid token or URL' });
    }
  } catch (error) {
    return res.status(500).json({ valid: false, message: 'Connection failed', error: String(error) });
  }
});

export default router;
```

**Step 6: Wire auth route into main app**

Update `server/src/index.ts` - add after the middleware section:

```typescript
// Add this import at the top
import authRoutes from './routes/auth.js';

// Add this after app.use(express.json())
app.use('/api/auth', authRoutes);
```

**Step 7: Create auth route test**

Create file `server/tests/auth.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../src/index.js';

describe('Auth Endpoint', () => {
  it('returns 400 for missing fields', async () => {
    const response = await request(app)
      .post('/api/auth/validate')
      .send({});

    expect(response.status).toBe(400);
    expect(response.body.error).toBe('Invalid request');
  });

  it('returns 400 for invalid URL', async () => {
    const response = await request(app)
      .post('/api/auth/validate')
      .send({ haUrl: 'not-a-url', haToken: 'token123' });

    expect(response.status).toBe(400);
  });
});
```

**Step 8: Run all tests**

Run: `cd server && npm run test:run`

Expected: All tests pass

**Step 9: Commit**

```bash
git add server/
git commit -m "feat(server): add auth validation endpoint with tests"
```

---

## Task 6: Create iOS Project Structure

**Files:**
- Create: `ios/PrinterMonitor/` Xcode project
- Create: App entry point, tab navigation, placeholder views

**Step 1: Create iOS project directory structure**

```bash
mkdir -p ios/PrinterMonitor/PrinterMonitor/{App,Core/{Models,Services,Storage},Features/{Dashboard,History,Settings,Setup,Debug},Components,DesignSystem}
mkdir -p ios/PrinterMonitor/PrinterMonitorWidget
```

**Step 2: Create App entry point**

Create file `ios/PrinterMonitor/PrinterMonitor/App/PrinterMonitorApp.swift`:

```swift
import SwiftUI

@main
struct PrinterMonitorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Step 3: Create ContentView with tab navigation**

Create file `ios/PrinterMonitor/PrinterMonitor/App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
```

**Step 4: Create placeholder Dashboard view**

Create file `ios/PrinterMonitor/PrinterMonitor/Features/Dashboard/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("No Printer Connected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Configure your Home Assistant connection in Settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
```

**Step 5: Create placeholder History view**

Create file `ios/PrinterMonitor/PrinterMonitor/Features/History/HistoryView.swift`:

```swift
import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("No print history yet")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
```

**Step 6: Create placeholder Settings view**

Create file `ios/PrinterMonitor/PrinterMonitor/Features/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    NavigationLink("Home Assistant") {
                        Text("Connection Setup")
                    }
                }

                Section("Notifications") {
                    NavigationLink("Notification Settings") {
                        Text("Notification Settings")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
```

**Step 7: Verify files exist**

Run: `find ios/PrinterMonitor -name "*.swift" | head -10`

Expected: App entry point and view files listed

**Step 8: Commit Swift files**

```bash
git add ios/
git commit -m "feat(ios): create SwiftUI app structure with tab navigation"
```

---

## Task 7: Create Xcode Project File

**Note:** This task requires Xcode. We'll create a minimal project.pbxproj or use `xcodegen`.

**Step 1: Create project.yml for XcodeGen**

Create file `ios/PrinterMonitor/project.yml`:

```yaml
name: PrinterMonitor
options:
  bundleIdPrefix: com.samduncan
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "6.0"
    TARGETED_DEVICE_FAMILY: "1"
    DEVELOPMENT_TEAM: ""

targets:
  PrinterMonitor:
    type: application
    platform: iOS
    sources:
      - PrinterMonitor
    settings:
      base:
        INFOPLIST_FILE: PrinterMonitor/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.samduncan.PrinterMonitor
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    info:
      path: PrinterMonitor/Info.plist
      properties:
        CFBundleDisplayName: Printer Monitor
        CFBundleShortVersionString: "1.0.0"
        CFBundleVersion: "1"
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        NSSupportsLiveActivities: true

  PrinterMonitorWidget:
    type: app-extension
    platform: iOS
    sources:
      - PrinterMonitorWidget
    settings:
      base:
        INFOPLIST_FILE: PrinterMonitorWidget/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.samduncan.PrinterMonitor.widget
    info:
      path: PrinterMonitorWidget/Info.plist
      properties:
        CFBundleDisplayName: Printer Widget
        CFBundleShortVersionString: "1.0.0"
        CFBundleVersion: "1"
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
```

**Step 2: Create Info.plist**

Create file `ios/PrinterMonitor/PrinterMonitor/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Printer Monitor</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>NSSupportsLiveActivities</key>
    <true/>
</dict>
</plist>
```

**Step 3: Create widget Info.plist**

Create file `ios/PrinterMonitor/PrinterMonitorWidget/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Printer Widget</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

**Step 4: Create placeholder widget bundle**

Create file `ios/PrinterMonitor/PrinterMonitorWidget/PrinterMonitorWidgetBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct PrinterMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity will be added here
    }
}
```

**Step 5: Generate Xcode project (if xcodegen installed)**

Run: `cd ios/PrinterMonitor && xcodegen generate`

Or manually create project in Xcode if xcodegen not available.

**Step 6: Commit**

```bash
git add ios/
git commit -m "feat(ios): add Xcode project configuration and widget extension"
```

---

## Task 8: Copy Existing Assets to New Project

**Files:**
- Copy: App icons from existing project
- Copy: Printer images from existing project

**Step 1: Create Assets.xcassets structure**

```bash
mkdir -p ios/PrinterMonitor/PrinterMonitor/Assets.xcassets/{AppIcon.appiconset,PrinterImages}
```

**Step 2: Copy app icons**

```bash
cp -r PrinterActivityMonitor/Assets.xcassets/AppIcon.appiconset/* ios/PrinterMonitor/PrinterMonitor/Assets.xcassets/AppIcon.appiconset/ 2>/dev/null || cp -r PrinterActivityMonitor/PrinterActivityMonitor/Assets.xcassets/AppIcon.appiconset/* ios/PrinterMonitor/PrinterMonitor/Assets.xcassets/AppIcon.appiconset/
```

**Step 3: Copy printer images**

```bash
cp -r PrinterActivityMonitor/PrinterActivityMonitor/Assets.xcassets/PrinterImages/* ios/PrinterMonitor/PrinterMonitor/Assets.xcassets/PrinterImages/
```

**Step 4: Create Contents.json for Assets**

Create file `ios/PrinterMonitor/PrinterMonitor/Assets.xcassets/Contents.json`:

```json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Step 5: Verify assets copied**

Run: `ls ios/PrinterMonitor/PrinterMonitor/Assets.xcassets/`

Expected: AppIcon.appiconset, PrinterImages, Contents.json

**Step 6: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Assets.xcassets/
git commit -m "feat(ios): copy app icons and printer images from existing project"
```

---

## Task 9: Create Basic Design System

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/DesignSystem/Theme.swift`

**Step 1: Create Theme.swift**

Create file `ios/PrinterMonitor/PrinterMonitor/DesignSystem/Theme.swift`:

```swift
import SwiftUI

/// Design system tokens for Printer Monitor
/// Based on "Liquid Aurora" design language
enum Theme {
    // MARK: - Colors

    enum Colors {
        // Primary accent - Celestial Cyan
        static let accent = Color(red: 0.35, green: 0.78, blue: 0.98)

        // Aurora gradient colors
        static let auroraStart = Color(red: 0.35, green: 0.78, blue: 0.98)
        static let auroraMid = Color(red: 0.55, green: 0.6, blue: 0.95)
        static let auroraEnd = Color(red: 0.45, green: 0.85, blue: 0.75)

        // Semantic colors
        static let success = Color(red: 0.3, green: 0.75, blue: 0.55)
        static let warning = Color(red: 0.95, green: 0.7, blue: 0.35)
        static let error = Color(red: 0.9, green: 0.4, blue: 0.45)

        // Backgrounds (dark mode optimized)
        static let backgroundPrimary = Color(red: 0.04, green: 0.04, blue: 0.06)
        static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.10)
        static let backgroundCard = Color(red: 0.12, green: 0.12, blue: 0.14)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary = Color.white.opacity(0.5)
    }

    // MARK: - Typography

    enum Typography {
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let display = Font.system(size: 28, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 20, weight: .semibold)
        static let headlineSmall = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodySmall = Font.system(size: 13, weight: .regular)
        static let label = Font.system(size: 13, weight: .medium)
        static let labelSmall = Font.system(size: 11, weight: .medium)
        static let numericLarge = Font.system(size: 34, weight: .semibold, design: .rounded)
        static let numeric = Font.system(size: 28, weight: .semibold, design: .rounded)
    }

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Gradients

    enum Gradients {
        static let aurora = LinearGradient(
            colors: [Colors.auroraStart, Colors.auroraMid, Colors.auroraEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Extensions

extension View {
    func cardBackground() -> some View {
        self
            .background(Theme.Colors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
    }
}
```

**Step 2: Verify file exists**

Run: `cat ios/PrinterMonitor/PrinterMonitor/DesignSystem/Theme.swift | head -20`

Expected: Theme enum definition visible

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/DesignSystem/
git commit -m "feat(ios): add design system with Liquid Aurora theme tokens"
```

---

## Task 10: Create APIClient Skeleton

**Files:**
- Create: `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift`

**Step 1: Create APIClient.swift**

Create file `ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift`:

```swift
import Foundation

/// API client for communicating with the Printer Monitor server
@Observable
final class APIClient {
    // MARK: - Properties

    private(set) var isConnected = false
    private(set) var lastError: Error?

    private var baseURL: URL?
    private var session: URLSession

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    func configure(serverURL: String) throws {
        guard let url = URL(string: serverURL) else {
            throw APIError.invalidURL
        }
        self.baseURL = url
    }

    // MARK: - Health Check

    func checkHealth() async throws -> HealthResponse {
        let data = try await request(endpoint: "/health", method: .get)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    // MARK: - Auth

    func validateHAConnection(haURL: String, haToken: String) async throws -> ValidationResponse {
        let body = ValidateRequest(haUrl: haURL, haToken: haToken)
        let data = try await request(endpoint: "/api/auth/validate", method: .post, body: body)
        return try JSONDecoder().decode(ValidationResponse.self, from: data)
    }

    // MARK: - Private Helpers

    private func request<T: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: T? = nil as Empty?
    ) async throws -> Data {
        guard let baseURL else {
            throw APIError.notConfigured
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        isConnected = true
        return data
    }
}

// MARK: - Supporting Types

extension APIClient {
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    enum APIError: LocalizedError {
        case invalidURL
        case notConfigured
        case invalidResponse
        case httpError(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid server URL"
            case .notConfigured: return "API client not configured"
            case .invalidResponse: return "Invalid response from server"
            case .httpError(let code): return "HTTP error: \(code)"
            }
        }
    }

    struct Empty: Codable {}

    struct HealthResponse: Codable {
        let status: String
        let timestamp: String
        let environment: String
    }

    struct ValidateRequest: Codable {
        let haUrl: String
        let haToken: String
    }

    struct ValidationResponse: Codable {
        let valid: Bool
        let message: String
    }
}
```

**Step 2: Verify file exists**

Run: `cat ios/PrinterMonitor/PrinterMonitor/Core/Services/APIClient.swift | head -30`

Expected: APIClient class definition visible

**Step 3: Commit**

```bash
git add ios/PrinterMonitor/PrinterMonitor/Core/Services/
git commit -m "feat(ios): add APIClient service skeleton for server communication"
```

---

## Phase 1 Complete Checkpoint

At this point you should have:

**Server:**
- Express app running on port 3000
- SQLite database initialized
- `/health` endpoint working
- `/api/auth/validate` endpoint (skeleton)
- Basic test suite passing

**iOS:**
- SwiftUI app with 3-tab navigation
- Placeholder Dashboard, History, Settings views
- Design system tokens
- APIClient service skeleton
- Existing assets preserved

**Verify:**

Run server: `cd server && npm run dev`
Test health: `curl http://localhost:3000/health`

Open iOS project in Xcode and build to simulator.

---

## Next Steps

After Phase 1, proceed to:
- **Phase 2:** Home Assistant WebSocket integration
- **Phase 3:** Core Dashboard with real data
- **Phase 4:** Push Notifications (requires paid Apple account)

Create separate plan documents for each phase.
