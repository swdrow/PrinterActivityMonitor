# Bambu Lab Filament Tracking System Documentation

## Table of Contents
1. [Overview](#overview)
2. [Core Features](#core-features)
3. [Technical Architecture](#technical-architecture)
    - 3.1 [Database Schema](#database-schema)
    - 3.2 [API Endpoints](#api-endpoints)
    - 3.3 [Home Assistant Integration](#home-assistant-integration)
    - 3.4 [Mobile App Integration](#mobile-app-integration)
4. [Data Flow](#data-flow)
5. [Future Enhancements](#future-enhancements)
6. [Usage Examples](#usage-examples)
7. [API Reference](#api-reference)
8. [Important Notes](#important-notes)

---

## 1. Overview

This document outlines a server-side system designed to provide comprehensive tracking and management of 3D printer filament usage and inventory, specifically for Bambu Lab 3D printers equipped with an Automatic Material System (AMS). This system is built to operate independently of RFID technology, making it compatible with any brand of filament. It integrates seamlessly with Home Assistant for printer state monitoring and offers a dedicated mobile application for intuitive inventory management and manual interventions. The core goal is to provide accurate, real-time insights into filament stock, automate usage tracking, and prevent print failures due to insufficient material.

## 2. Core Features

### 2.1 Print Job Tracking
- Track all print jobs from Home Assistant:
    - Start time and end time of the print.
    - Current status of the print job (e.g., printing, completed, failed, cancelled).
- Record filament usage per print:
    - Estimated usage in grams derived from gcode analysis prior to printing.
    - Actual usage reported by the printer (if available and integrated).
- Link each print job to the specific filament spool(s) used.

### 2.2 Filament Inventory Management
- Store comprehensive metadata for each filament spool:
    - **Brand and Product Name:** Manufacturer and specific product line (e.g., "Prusament PLA", "Bambu Lab PETG Basic").
    - **Material Type:** (e.g., PLA, PETG, ABS, TPU, ASA, Nylon, PC).
    - **Color:** Hexadecimal code (e.g., `#FF0000` for red) for consistent color representation.
    - **Initial Weight:** The weight of the filament spool when new (typically 1kg, but can be customized).
    - **Current Estimated Remaining Weight:** Dynamically updated based on usage.
    - **Purchase Date & Cost:** Date of purchase and cost per spool for financial tracking.
    - **Nozzle Temperature Range:** Recommended printing temperature range for the nozzle.
    - **Bed Temperature Range:** Recommended printing temperature range for the print bed.
    - **Drying Requirements (Optional):** Notes or specific instructions for drying the filament.

### 2.3 AMS Slot Tracking
- Track which specific filament spool is currently loaded in each AMS slot (1-4 per AMS unit).
- Detect and manage spool swaps by monitoring changes reported by Home Assistant:
    - **Color Changes:** When the printer reports a different color in a slot.
    - **Material Type Changes:** When the printer reports a different material type.
    - **Manual "I loaded a new spool" Events:** User-initiated confirmation via the mobile application.
- Maintain a historical log of filament spool assignments for each AMS slot over time, enabling auditing and correction.

### 2.4 Usage Estimation
- Estimate remaining filament for each spool based on:
    - **Initial Spool Weight:** The original weight minus the cumulative usage from all associated print jobs.
    - **Gcode Analysis:** Weight estimates extracted directly from gcode files before printing (if gcode parsing is implemented).
    - **Printer Sensors (Future):** Integration with actual weight sensors on the printer (if available via API) for more accurate readings.
- Generate alerts when filament spools are running low, based on a configurable weight threshold per spool or material type.

### 2.5 Integration Points
- **Home Assistant REST API:** Primary interface for receiving real-time printer state, print job notifications, and potential AMS slot changes.
- **Mobile Application (iOS):**
    - **Viewing Inventory:** Browse and search all filament spools and their status.
    - **Recording New Spool Additions:** Add new filament spools to inventory, inputting all metadata.
    - **Marking Spools as Loaded/Unloaded:** Manually assign/de-assign spools to AMS slots.
    - **Manual Adjustments:** Correct remaining weight, update metadata, or confirm usage.

## 3. Technical Architecture

### 3.1 Database Schema

#### PostgreSQL / SQLite

The system will utilize either PostgreSQL or SQLite for its database, offering flexibility in deployment (PostgreSQL for robust, scalable server deployments; SQLite for lightweight, self-contained single-server instances).

**`spools` table - Filament Inventory**
| Column | Type | Constraints |
|--------|------|-------------|
| `spool_id` | UUID/INT | PK |
| `brand` | TEXT | NOT NULL |
| `product_name` | TEXT | NOT NULL |
| `material_type` | TEXT | NOT NULL (e.g., 'PLA', 'PETG') |
| `color_hex` | TEXT | NOT NULL (e.g., '#FF0000') |
| `initial_weight_grams` | NUMERIC | NOT NULL |
| `current_weight_grams` | NUMERIC | NOT NULL |
| `purchase_date` | DATE | |
| `cost_usd` | NUMERIC | |
| `nozzle_temp_min_c` | INT | |
| `nozzle_temp_max_c` | INT | |
| `bed_temp_min_c` | INT | |
| `bed_temp_max_c` | INT | |
| `drying_requirements` | TEXT | NULL |
| `notes` | TEXT | NULL |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |

**`ams_slots` table - Current AMS Configuration**
| Column | Type | Constraints |
|--------|------|-------------|
| `ams_slot_id` | UUID/INT | PK |
| `printer_id` | TEXT | NOT NULL (e.g., serial number or HA entity ID) |
| `ams_unit_number` | INT | NOT NULL (e.g., 1, 2) |
| `slot_number` | INT | NOT NULL (e.g., 1, 2, 3, 4) |
| `spool_id` | UUID/INT | FK to `spools.spool_id`, NULLABLE if empty |
| `current_ha_color` | TEXT | NULL (color reported by HA) |
| `current_ha_material` | TEXT | NULL (material reported by HA) |
| `last_updated` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |
| | | UNIQUE (printer_id, ams_unit_number, slot_number) |

**`slot_history` table - Historical Slot Assignments**
| Column | Type | Constraints |
|--------|------|-------------|
| `history_id` | UUID/INT | PK |
| `ams_slot_id` | UUID/INT | FK to `ams_slots.ams_slot_id` |
| `spool_id` | UUID/INT | FK to `spools.spool_id`, NULLABLE if slot emptied |
| `assigned_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |
| `unassigned_at` | TIMESTAMP | NULL |
| `event_type` | TEXT | NOT NULL (e.g., 'manual', 'ha_color_change', 'ha_material_change') |

**`print_jobs` table - Print History with Filament Usage**
| Column | Type | Constraints |
|--------|------|-------------|
| `job_id` | UUID/INT | PK |
| `printer_id` | TEXT | NOT NULL |
| `gcode_file_name` | TEXT | NULL |
| `start_time` | TIMESTAMP | NOT NULL |
| `end_time` | TIMESTAMP | NULL |
| `status` | TEXT | NOT NULL (e.g., 'printing', 'completed', 'failed', 'cancelled') |
| `total_estimated_grams` | NUMERIC | NULL (from gcode analysis) |
| `total_actual_grams` | NUMERIC | NULL (from printer telemetry) |
| `cost_usd` | NUMERIC | NULL (calculated) |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |

**`usage_events` table - Filament Consumption Log**
| Column | Type | Constraints |
|--------|------|-------------|
| `event_id` | UUID/INT | PK |
| `job_id` | UUID/INT | FK to `print_jobs.job_id`, NULLABLE for manual usage |
| `spool_id` | UUID/INT | FK to `spools.spool_id`, NOT NULL |
| `ams_slot_id` | UUID/INT | FK to `ams_slots.ams_slot_id`, NULLABLE for manual usage |
| `grams_used` | NUMERIC | NOT NULL |
| `timestamp` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |
| `event_type` | TEXT | NOT NULL (e.g., 'print', 'manual_adjustment', 'waste') |

### 3.2 API Endpoints

A RESTful API will serve as the primary interface for the mobile app and other integrations. It will adhere to standard HTTP methods (GET, POST, PUT, DELETE) and return JSON payloads.

**Spool Management (`/api/spools`)**
- `GET /api/spools`: Retrieve all filament spools.
- `GET /api/spools/{spool_id}`: Retrieve details for a specific spool.
- `POST /api/spools`: Add a new filament spool to inventory.
- `PUT /api/spools/{spool_id}`: Update an existing filament spool's metadata.
- `DELETE /api/spools/{spool_id}`: Remove a filament spool.
- `POST /api/spools/{spool_id}/adjust_weight`: Manually adjust `current_weight_grams`.

**AMS Slot Management (`/api/ams_slots`)**
- `GET /api/ams_slots`: Retrieve current status of all AMS slots for all printers.
- `GET /api/ams_slots/{printer_id}`: Retrieve current status of AMS slots for a specific printer.
- `POST /api/ams_slots/{printer_id}/{ams_unit_number}/{slot_number}/assign`: Assign a spool to a specific AMS slot.
- `POST /api/ams_slots/{printer_id}/{ams_unit_number}/{slot_number}/unassign`: Unassign a spool from an AMS slot.

**Print Job Logging (`/api/print_jobs`)**
- `POST /api/print_jobs/start`: Record the start of a new print job.
- `PUT /api/print_jobs/{job_id}/end`: Mark a print job as complete/failed/cancelled.
- `GET /api/print_jobs`: Retrieve all print jobs.
- `GET /api/print_jobs/{job_id}`: Retrieve details for a specific print job.

**Usage Statistics (`/api/stats`)**
- `GET /api/stats/spools/low_inventory`: Get a list of spools below a configured threshold.
- `GET /api/stats/spools/usage_history/{spool_id}`: Get usage history for a specific spool.

**Webhooks (Internal/HA facing)**
- `POST /webhook/homeassistant/print_event`: Endpoint for Home Assistant to push print start/end/status updates.
- `POST /webhook/homeassistant/ams_update`: Endpoint for Home Assistant to push AMS slot changes (color/material).

### 3.3 Home Assistant Integration

The system will integrate with Home Assistant to monitor Bambu Lab 3D printers.

- **Polling or Webhook-based Sync:**
    - **Polling (Initial):** The server-side system will periodically poll Home Assistant's REST API for printer state and AMS information.
    - **Webhooks (Preferred):** Home Assistant will be configured to push real-time updates to the filament tracking system's webhook endpoints whenever printer state or AMS slots change. This reduces latency and server load.
- **Entity Mapping:** A configuration will allow mapping Home Assistant printer entities (e.g., `sensor.bambu_printer_x1c_filament_color_ams_1_slot_1`) to internal printer and AMS slot identifiers.
- **Change Detection for Slot Swaps:**
    - The Home Assistant integration will monitor attributes related to filament color and material type in each AMS slot.
    - When a change is detected, the system will record the event in `slot_history` and potentially prompt the user (via mobile app notification) to confirm which physical spool was loaded.

### 3.4 Mobile App Integration

A native iOS application (and potentially Android in the future) will provide a rich user interface for interaction.

- **API Client:** The mobile app will consume the RESTful API endpoints described above.
- **Push Notifications:** The server will send push notifications to the mobile app for critical events:
    - Low filament alerts.
    - Detected AMS slot changes requiring user confirmation.
    - Print job status updates (optional).
- **Barcode/QR Scanning (Future):** Implement functionality to scan barcodes or QR codes to quickly register new spools or identify existing ones for loading/unloading.

## 4. Data Flow

### 4.1 Print Job Starts (Home Assistant -> Server)
1. Home Assistant detects a new print job starting on the Bambu Lab printer.
2. HA triggers a webhook to `/webhook/homeassistant/print_event` with printer ID, start time, and currently active AMS slot(s).
3. Server creates a new entry in `print_jobs` with initial status 'printing'.
4. Server identifies the `spool_id` currently in the active AMS slot(s) and links it to the `print_job`.
5. If gcode parsing is enabled, estimated usage is added to `print_jobs`.

### 4.2 Print Job Completes (Home Assistant -> Server)
1. Home Assistant detects the print job has completed, failed, or been cancelled.
2. HA triggers a webhook to `/webhook/homeassistant/print_event` with updated status and end time.
3. Server updates the `print_jobs` entry.
4. Server calculates filament used for the print (based on gcode estimate or reported actual usage).
5. Server creates `usage_events` entries for each spool used, decrementing `current_weight_grams` in the `spools` table.
6. If `current_weight_grams` falls below a threshold, a low filament alert notification is queued for the mobile app.

### 4.3 AMS Slot Change Detected (Home Assistant -> Server -> Mobile App)
1. Home Assistant detects a change in `filament_color` or `filament_material` for an AMS slot.
2. HA triggers a webhook to `/webhook/homeassistant/ams_update` for the specific printer and slot.
3. Server updates `current_ha_color` and `current_ha_material` in the `ams_slots` table.
4. System checks if the detected filament attributes align with the `spool_id` currently assigned to that slot.
5. If a mismatch or an unassigned slot is detected (implying a physical spool change), a push notification is sent to the mobile app, prompting the user to confirm the new spool.
6. User confirms the spool via the mobile app, which calls `/api/ams_slots/{...}/assign`.
7. Server updates `ams_slots` and creates a new `slot_history` entry for the confirmed assignment.

### 4.4 Mobile App Displays Inventory with Real-time Updates
1. Mobile app fetches data from `/api/spools` and `/api/ams_slots` on launch and periodically.
2. Displays current filament inventory, remaining weights, and which spools are in which AMS slots.
3. User can add new spools (`POST /api/spools`), manually assign/unassign spools (`POST /api/ams_slots/{...}/assign`), or adjust spool weights (`POST /api/spools/{spool_id}/adjust_weight`).

## 5. Future Enhancements

- **Multi-printer Support:** Extend the database schema and API to gracefully handle multiple Bambu Lab printers connected to the same Home Assistant instance.
- **Filament Cost Tracking per Print:** Calculate and display the exact monetary cost of filament used for each print job.
- **Spool Expiration Warnings:** For hygroscopic materials (e.g., Nylon, PC), track purchase date and provide warnings when spools are approaching a recommended "dry before use" date.
- **Suggested Spool for Next Print:** Based on print job requirements (material, color, remaining weight), suggest the most suitable available spool from inventory.
- **Integration with Filament Vendors:** Potentially integrate with filament vendor APIs for automatic reordering when stock is low.
- **Gcode Analysis Service:** A dedicated microservice to parse gcode files and extract estimated filament usage (material, length, weight) before a print starts.

## 6. Usage Examples

### 6.1 Home Assistant Configuration

```yaml
# Example: Home Assistant Automation for Print Start/End
automation:
  - alias: 'Send Bambu Printer Print Event to Filament Tracker'
    trigger:
      - platform: state
        entity_id: sensor.bambu_lab_p1s_print_status
        to: 'PRINTING'
      - platform: state
        entity_id: sensor.bambu_lab_p1s_print_status
        not_to: 'PRINTING'
        from: 'PRINTING'
    action:
      - service: rest_command.send_filament_tracker_print_event
        data:
          printer_id: "BambuP1S_001"
          status: "{{ states('sensor.bambu_lab_p1s_print_status') }}"
          gcode_file_name: "{{ state_attr('sensor.bambu_lab_p1s_print_status', 'gcode_file') }}"

# Example: Home Assistant Automation for AMS Slot Change
  - alias: 'Send Bambu AMS Slot Update to Filament Tracker'
    trigger:
      - platform: state
        entity_id:
          - sensor.bambu_lab_p1s_ams_1_slot_1_color
          - sensor.bambu_lab_p1s_ams_1_slot_1_material
    action:
      - service: rest_command.send_filament_tracker_ams_update
        data_template:
          printer_id: "BambuP1S_001"
          ams_unit_number: "{{ trigger.entity_id.split('_')[-3] }}"
          slot_number: "{{ trigger.entity_id.split('_')[-2] }}"
          color: "{{ state_attr(trigger.entity_id, 'rgb_color') if 'color' in trigger.entity_id else none }}"
          material: "{{ states(trigger.entity_id) if 'material' in trigger.entity_id else none }}"

rest_command:
  send_filament_tracker_print_event:
    url: "http://your_filament_tracker_ip:port/webhook/homeassistant/print_event"
    method: "POST"
    headers:
      Content-Type: "application/json"
    payload: "{{ (data | tojson) }}"
  send_filament_tracker_ams_update:
    url: "http://your_filament_tracker_ip:port/webhook/homeassistant/ams_update"
    method: "POST"
    headers:
      Content-Type: "application/json"
    payload: "{{ (data | tojson) }}"
```

### 6.2 Mobile App Interaction (Conceptual)

#### Adding a New Spool
A user opens the mobile app and taps "Add New Spool". They fill out a form:
- Brand: `Prusament`
- Product Name: `PLA Galaxy Black`
- Material Type: `PLA`
- Color: `#333333`
- Initial Weight (grams): `1000`
- Purchase Date: `2025-10-26`
- Cost: `29.99`
- Nozzle Temp Range: `210-230`
- Bed Temp Range: `50-60`

Upon saving, the app sends a `POST` request to `/api/spools`.

#### Assigning a Spool to AMS Slot
A user gets a notification: "AMS 1, Slot 3 changed. What spool did you load?"
They tap the notification, see a list of their inventory, select `Prusament PLA Galaxy Black`.
The app sends a `POST` request:
```
POST /api/ams_slots/BambuP1S_001/1/3/assign
Payload: { "spool_id": "UUID_GALAXY_BLACK", "event_type": "manual" }
```

## 7. API Reference

### Spool Endpoints (`/api/spools`)

| Method | Path | Description | Request Body | Response |
|--------|------|-------------|--------------|----------|
| `GET` | `/` | Retrieve all spools | None | `[{"spool_id": "...", "brand": "..."}, ...]` |
| `GET` | `/{spool_id}` | Retrieve specific spool | None | `{"spool_id": "...", "brand": "..."}` |
| `POST` | `/` | Add new spool | `{"brand": "...", "material_type": "...", ...}` | `{"spool_id": "...", "status": "created"}` |
| `PUT` | `/{spool_id}` | Update spool metadata | `{"current_weight_grams": 500, ...}` | `{"spool_id": "...", "status": "updated"}` |
| `DELETE` | `/{spool_id}` | Delete spool | None | `{"spool_id": "...", "status": "deleted"}` |
| `POST` | `/{spool_id}/adjust_weight` | Manually adjust weight | `{"adjustment_grams": -50}` | `{"spool_id": "...", "new_weight": 950}` |

### AMS Slot Endpoints (`/api/ams_slots`)

| Method | Path | Description | Request Body | Response |
|--------|------|-------------|--------------|----------|
| `GET` | `/` | Retrieve all AMS slot statuses | None | `[{"printer_id": "...", "slot_number": 1, ...}, ...]` |
| `GET` | `/{printer_id}` | Retrieve AMS slots for a printer | None | `[{"slot_number": 1, "spool_id": "..."}, ...]` |
| `POST` | `/{printer_id}/{ams_unit}/{slot_num}/assign` | Assign spool to slot | `{"spool_id": "uuid", "event_type": "manual"}` | `{"ams_slot_id": "...", "spool_id": "..."}` |
| `POST` | `/{printer_id}/{ams_unit}/{slot_num}/unassign` | Unassign spool from slot | `{"event_type": "manual"}` | `{"ams_slot_id": "...", "spool_id": null}` |

### Print Job Endpoints (`/api/print_jobs`)

| Method | Path | Description | Request Body | Response |
|--------|------|-------------|--------------|----------|
| `POST` | `/start` | Record print job start | `{"printer_id": "...", "gcode_file_name": "...", ...}` | `{"job_id": "...", "status": "printing"}` |
| `PUT` | `/{job_id}/end` | Update print job status/usage | `{"status": "completed", "actual_grams_used": 150.5}` | `{"job_id": "...", "status": "completed"}` |
| `GET` | `/` | Retrieve all print jobs | None | `[{"job_id": "...", "status": "completed"}, ...]` |
| `GET` | `/{job_id}` | Retrieve specific print job | None | `{"job_id": "...", "status": "completed", ...}` |

### Statistics Endpoints (`/api/stats`)

| Method | Path | Description | Response |
|--------|------|-------------|----------|
| `GET` | `/spools/low_inventory` | List spools below threshold | `[{"spool_id": "...", "remaining_grams": 50}, ...]` |
| `GET` | `/spools/usage_history/{spool_id}` | Get usage events for a spool | `[{"event_id": "...", "grams_used": 25, ...}, ...]` |

## 8. Important Notes

- **Security:** API endpoints should be secured with appropriate authentication (e.g., API keys, OAuth2) to prevent unauthorized access. Webhook endpoints should also be secured (e.g., shared secrets) to ensure requests originate from Home Assistant.
- **Error Handling:** All API endpoints should return meaningful HTTP status codes and JSON error messages for invalid requests or server errors.
- **Scalability:** The choice between SQLite and PostgreSQL should be made based on expected load. For single-user, local deployments, SQLite is sufficient. For multi-user or high-volume environments, PostgreSQL is recommended.
- **Configuration:** Key parameters (e.g., low filament thresholds, Home Assistant API URL, webhook secrets) should be configurable via environment variables or a dedicated configuration file.
- **Gcode Parsing:** Implementing robust gcode parsing to accurately estimate filament usage is complex and should be considered a significant development effort. Initial versions may rely solely on printer-reported usage or user input.
- **Privacy:** Consider data privacy if personal print history or sensitive information is stored.
