import { Router } from 'express';
import { notificationTrigger } from '../services/NotificationTrigger.js';
import { printHistoryService } from '../services/PrintHistoryService.js';
import { getDatabase, saveDatabase } from '../config/database.js';

const router = Router();

// Simulate print start
router.post('/simulate/start', async (req, res) => {
  const { printerPrefix, filename } = req.body;

  if (!printerPrefix) {
    return res.status(400).json({
      success: false,
      error: 'printerPrefix required',
    });
  }

  try {
    await notificationTrigger.handleStatusChange(
      printerPrefix,
      'idle',
      'running',
      filename ?? 'Test Print.gcode'
    );

    return res.json({
      success: true,
      message: `Simulated print start for ${printerPrefix}`,
    });
  } catch (error) {
    console.error('Simulate start failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to simulate print start',
    });
  }
});

// Simulate print complete
router.post('/simulate/complete', async (req, res) => {
  const { printerPrefix, status } = req.body;

  if (!printerPrefix) {
    return res.status(400).json({
      success: false,
      error: 'printerPrefix required',
    });
  }

  const finalStatus = status ?? 'complete';

  try {
    await notificationTrigger.handleStatusChange(
      printerPrefix,
      'running',
      finalStatus
    );

    return res.json({
      success: true,
      message: `Simulated print ${finalStatus} for ${printerPrefix}`,
    });
  } catch (error) {
    console.error('Simulate complete failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to simulate print complete',
    });
  }
});

// Simulate progress milestone
router.post('/simulate/progress', async (req, res) => {
  const { printerPrefix, progress, filename } = req.body;

  if (!printerPrefix || progress === undefined) {
    return res.status(400).json({
      success: false,
      error: 'printerPrefix and progress required',
    });
  }

  try {
    await notificationTrigger.handleProgressChange(
      printerPrefix,
      progress,
      filename ?? 'Test Print.gcode'
    );

    return res.json({
      success: true,
      message: `Simulated ${progress}% progress for ${printerPrefix}`,
    });
  } catch (error) {
    console.error('Simulate progress failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to simulate progress',
    });
  }
});

// Get database stats
router.get('/stats', (req, res) => {
  const db = getDatabase();

  return res.json({
    success: true,
    data: {
      devices: db.devices.length,
      printers: db.printers.length,
      printJobs: db.printJobs.length,
      notificationSettings: db.notificationSettings.length,
    },
  });
});

// Clear print history (for testing)
router.delete('/history', (req, res) => {
  const db = getDatabase();
  const count = db.printJobs.length;
  db.printJobs = [];
  saveDatabase();

  return res.json({
    success: true,
    message: `Cleared ${count} print jobs`,
  });
});

export default router;
