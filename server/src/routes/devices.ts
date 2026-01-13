import { Router } from 'express';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { getDatabase, saveDatabase } from '../config/database.js';
import type { Device, NotificationSettings } from '../config/database.js';

const router = Router();

const registerSchema = z.object({
  apnsToken: z.string().min(1),
  haUrl: z.string().url(),
  printerPrefix: z.string().optional(),
  printerName: z.string().optional(),
});

const updateSettingsSchema = z.object({
  notificationsEnabled: z.boolean().optional(),
  onStart: z.boolean().optional(),
  onComplete: z.boolean().optional(),
  onFailed: z.boolean().optional(),
  onPaused: z.boolean().optional(),
  onMilestone: z.boolean().optional(),
});

// Register or update device
router.post('/register', (req, res) => {
  const parsed = registerSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      success: false,
      error: 'Invalid request',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { apnsToken, haUrl, printerPrefix, printerName } = parsed.data;
  const db = getDatabase();

  // Check if device exists by apnsToken
  const existingIndex = db.devices.findIndex(d => d.apnsToken === apnsToken);

  if (existingIndex !== -1) {
    // Update existing device
    const device = db.devices[existingIndex];
    device.haUrl = haUrl;
    device.entityPrefix = printerPrefix ?? null;
    device.printerName = printerName ?? null;
    device.lastSeen = new Date().toISOString();
    saveDatabase();

    return res.json({
      success: true,
      deviceId: device.id,
      message: 'Device updated',
    });
  }

  // Create new device
  const deviceId = uuidv4();
  const newDevice: Device = {
    id: deviceId,
    apnsToken,
    activityToken: null,
    haUrl,
    haToken: '', // Will be set via monitor start
    entityPrefix: printerPrefix ?? null,
    printerName: printerName ?? null,
    createdAt: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
    notificationsEnabled: true,
  };

  db.devices.push(newDevice);

  // Create default notification settings
  const settings: NotificationSettings = {
    deviceId,
    onStart: true,
    onComplete: true,
    onFailed: true,
    onPaused: true,
    onMilestone: true,
  };
  db.notificationSettings.push(settings);

  saveDatabase();

  return res.json({
    success: true,
    deviceId,
    message: 'Device registered',
  });
});

// Update notification settings
router.patch('/:deviceId/settings', (req, res) => {
  const { deviceId } = req.params;
  const parsed = updateSettingsSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      success: false,
      error: 'Invalid request',
    });
  }

  const db = getDatabase();
  const device = db.devices.find(d => d.id === deviceId);

  if (!device) {
    return res.status(404).json({
      success: false,
      error: 'Device not found',
    });
  }

  const settingsData = parsed.data;

  // Update device-level notification toggle
  if (settingsData.notificationsEnabled !== undefined) {
    device.notificationsEnabled = settingsData.notificationsEnabled;
  }

  // Update notification type settings
  let settings = db.notificationSettings.find(s => s.deviceId === deviceId);
  if (!settings) {
    settings = {
      deviceId,
      onStart: true,
      onComplete: true,
      onFailed: true,
      onPaused: true,
      onMilestone: true,
    };
    db.notificationSettings.push(settings);
  }

  if (settingsData.onStart !== undefined) settings.onStart = settingsData.onStart;
  if (settingsData.onComplete !== undefined) settings.onComplete = settingsData.onComplete;
  if (settingsData.onFailed !== undefined) settings.onFailed = settingsData.onFailed;
  if (settingsData.onPaused !== undefined) settings.onPaused = settingsData.onPaused;
  if (settingsData.onMilestone !== undefined) settings.onMilestone = settingsData.onMilestone;

  saveDatabase();

  return res.json({
    success: true,
    message: 'Settings updated',
  });
});

// Get devices for a printer prefix (used by notification service)
router.get('/by-printer/:prefix', (req, res) => {
  const { prefix } = req.params;
  const db = getDatabase();

  const devices = db.devices.filter(
    d => d.entityPrefix === prefix && d.notificationsEnabled && d.apnsToken
  );

  const result = devices.map(d => {
    const settings = db.notificationSettings.find(s => s.deviceId === d.id) || {
      onStart: true,
      onComplete: true,
      onFailed: true,
      onPaused: true,
      onMilestone: true,
    };

    return {
      id: d.id,
      apnsToken: d.apnsToken,
      printerName: d.printerName,
      ...settings,
    };
  });

  return res.json({
    success: true,
    devices: result,
  });
});

// Unregister device
router.delete('/:deviceId', (req, res) => {
  const { deviceId } = req.params;
  const db = getDatabase();

  const deviceIndex = db.devices.findIndex(d => d.id === deviceId);
  if (deviceIndex !== -1) {
    db.devices.splice(deviceIndex, 1);
  }

  const settingsIndex = db.notificationSettings.findIndex(s => s.deviceId === deviceId);
  if (settingsIndex !== -1) {
    db.notificationSettings.splice(settingsIndex, 1);
  }

  saveDatabase();

  return res.json({
    success: true,
    message: 'Device unregistered',
  });
});

export default router;
