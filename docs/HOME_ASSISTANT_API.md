# Home Assistant Integration API Documentation

## Overview

The Printer Activity Monitor app integrates with Home Assistant using the REST API to monitor Bambu Lab 3D printers via the ha-bambulab integration.

**Key Features**:
- Fetches real-time printer state from 20+ sensor entities
- Displays live activity on iPhone Lock Screen and Dynamic Island
- Allows manual control via service calls
- Auto-discovers printers and AMS units

---

## Authentication

### Long-Lived Access Token

All API requests require authentication via Bearer token:

```
Authorization: Bearer YOUR_LONG_LIVED_TOKEN
Content-Type: application/json
```

**Getting a Token**:
1. Home Assistant → Settings → Developer Tools → Long-Lived Access Tokens
2. Create new token
3. Copy immediately (cannot retrieve later)
4. Paste into app settings

---

## Base URL Configuration

### URL Formats Supported

```
https://home-assistant.example.com
https://192.168.1.100:8123
http://tailscale-host.example.ts.net
http://192.168.1.100:8123  (local network)
```

### Tailscale Integration

For remote access via Tailscale:
```
http://your-home-server.example.ts.net:8123
```
- Traffic encrypted by Tailscale
- No ATS exception needed for HTTPS

---

## Entity Naming Convention

All Bambu Lab sensors follow a prefix-based pattern:

```
sensor.{PREFIX}_{SENSOR_NAME}
button.{PREFIX}_{ACTION}
light.{PREFIX}_chamber_light
number.{PREFIX}_nozzle_temperature
image.{PREFIX}_cover_image
```

**Examples**:
- `h2s` - Common default
- `bambu_x1c` - X1 Carbon
- `ams_2_pro` - AMS unit

---

## Core Sensor Entities

The app fetches these sensors on each poll cycle:

### Print Progress & Status

| Suffix | Type | Notes |
|--------|------|-------|
| `print_progress` | sensor | 0-100% |
| `print_status` | sensor | idle, running, pause, finish, failed |
| `current_layer` | sensor | Current layer number |
| `total_layer_count` | sensor | Total layers |
| `remaining_time` | sensor | Minutes remaining |
| `subtask_name` | sensor | Filename |
| `current_stage` | sensor | Current stage |

### Temperature Sensors

| Suffix | Type | Notes |
|--------|------|-------|
| `nozzle_temperature` | sensor | °C |
| `target_nozzle_temperature` | sensor | °C setpoint |
| `bed_temperature` | sensor | °C |
| `target_bed_temperature` | sensor | °C setpoint |
| `chamber_temperature` | sensor | °C |

### Fan Speeds

| Suffix | Type | Notes |
|--------|------|-------|
| `aux_fan` | sensor | 0-100% |
| `chamber_fan` | sensor | 0-100% |
| `cooling_fan` | sensor | 0-100% |

### Print Material

| Suffix | Type | Notes |
|--------|------|-------|
| `speed_profile` | sensor | Speed % |
| `filament_used` | sensor | Grams |
| `print_weight` | sensor | Estimated weight |

---

## AMS Entities

### Tray Patterns

```
sensor.{PREFIX}_ams_{UNIT}_tray_{TRAY}   # With unit number
sensor.{PREFIX}_ams_tray_{TRAY}          # Without unit number
```

**Tray Attributes**:
```json
{
  "state": "active",
  "attributes": {
    "active": true,
    "empty": false,
    "color": "#FF5733",
    "name": "Bambu ABS",
    "type": "ABS",
    "nozzle_temp_min": 240,
    "nozzle_temp_max": 270,
    "remaining": 85.5
  }
}
```

### Environmental Sensors

```
sensor.{PREFIX}_ams_{UNIT}_humidity
sensor.{PREFIX}_ams_humidity
sensor.{PREFIX}_active_tray
```

---

## API Endpoints

### GET /api/ - Connection Test

```bash
curl -H "Authorization: Bearer TOKEN" \
  https://ha.local/api/
```

**Response**:
```json
{"message": "API running.", "version": "2024.1.0"}
```

### GET /api/states/{entity_id} - Single Entity

```bash
curl -H "Authorization: Bearer TOKEN" \
  https://ha.local/api/states/sensor.h2s_print_progress
```

**Response**:
```json
{
  "entity_id": "sensor.h2s_print_progress",
  "state": "42",
  "attributes": {
    "unit_of_measurement": "%",
    "friendly_name": "H2S Print Progress"
  }
}
```

### GET /api/states - All Entities (Discovery)

```bash
curl -H "Authorization: Bearer TOKEN" \
  https://ha.local/api/states
```

Returns array of all entities for auto-discovery.

### POST /api/services/{domain}/{service} - Service Calls

```bash
curl -X POST \
  -H "Authorization: Bearer TOKEN" \
  -d '{"entity_id": "button.h2s_pause"}' \
  https://ha.local/api/services/button/press
```

---

## Error Handling

| Status | Error | App Behavior |
|--------|-------|--------------|
| 200 | Success | Parse response |
| 401 | Unauthorized | Show auth error |
| 404 | Not Found | Return empty, skip sensor |
| 5xx | Server Error | Show connection error |

---

## Polling Architecture

### Timer-Based Polling

```swift
func startPolling() {
    Task { await fetchAndUpdate() }

    refreshTimer = Timer.scheduledTimer(
        withTimeInterval: refreshInterval,  // Default: 30s
        repeats: true
    ) { _ in
        Task { await self?.fetchAndUpdate() }
    }
}
```

### Polling Cycle

1. **Concurrent Fetch** (20+ requests via async let)
2. **Wait for Results**
3. **Parse & Update State**
4. **Notify Subscribers** (Live Activity, UI)

---

## Auto-Discovery Algorithm

### Step 1: Fetch All Entities
```
GET /api/states → Array of 1000+ entities
```

### Step 2: Find Printers
```
Search for known suffixes:
  print_progress, nozzle_temperature, etc.
Extract prefix from entity_id
```

### Step 3: Find AMS Units
```
Search for tray patterns: _tray_\d+$
Extract AMS prefix
```

### Step 4: Build Objects
```swift
DiscoveredPrinter(prefix: "h2s", entityCount: 35, model: "H2S")
DiscoveredAMS(prefix: "ams_2_pro", trayCount: 4, trayEntities: [...])
```

---

## Service Calls

### Printer Control

```bash
# Pause
POST /api/services/button/press
{"entity_id": "button.h2s_pause"}

# Resume
POST /api/services/button/press
{"entity_id": "button.h2s_resume"}

# Stop
POST /api/services/button/press
{"entity_id": "button.h2s_stop"}
```

### Temperature Control

```bash
# Set nozzle temperature
POST /api/services/number/set_value
{"entity_id": "number.h2s_nozzle_temperature", "value": 210}
```

### AMS Control

```bash
# Load filament
POST /api/services/bambu_lab/load_filament
{"device_id": "h2s", "slot": 1}

# Unload filament
POST /api/services/bambu_lab/unload_filament
{"device_id": "h2s", "slot": 1}

# Start drying
POST /api/services/button/press
{"entity_id": "button.h2s_start_drying"}
```

---

## Testing Commands

### Test Connection
```bash
curl -H "Authorization: Bearer $TOKEN" "$HA_URL/api/"
```

### Test Sensor
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "$HA_URL/api/states/sensor.h2s_print_progress"
```

### Discover Entities
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "$HA_URL/api/states" | jq '.[] | select(.entity_id | contains("h2s"))'
```

---

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Connection failed | URL format | Include http:// or https:// |
| Unauthorized | Invalid token | Create new token in HA |
| Entity not found | Wrong prefix | Check HA Developer Tools |
| AMS not detected | Different prefix | Use auto-discovery |
