import { Router } from 'express';
import { z } from 'zod';
import { PrinterMonitor } from '../services/PrinterMonitor.js';
import { setPrinterMonitor } from './printers.js';

const router = Router();

let currentMonitor: PrinterMonitor | null = null;

const startSchema = z.object({
  haUrl: z.string().url(),
  haToken: z.string().min(1),
  printerPrefixes: z.array(z.string()).min(1),
});

router.post('/start', async (req, res) => {
  const parsed = startSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      success: false,
      error: 'Invalid request',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { haUrl, haToken, printerPrefixes } = parsed.data;

  // Stop existing monitor if running
  if (currentMonitor) {
    currentMonitor.stop();
  }

  try {
    currentMonitor = new PrinterMonitor();
    await currentMonitor.start({ haUrl, haToken, printerPrefixes });

    // Share with printers route
    setPrinterMonitor(currentMonitor);

    return res.json({
      success: true,
      message: 'Monitor started',
      monitoringPrefixes: printerPrefixes,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Failed to start monitor',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

router.post('/stop', (req, res) => {
  if (currentMonitor) {
    currentMonitor.stop();
    currentMonitor = null;
  }

  return res.json({
    success: true,
    message: 'Monitor stopped',
  });
});

router.get('/status', (req, res) => {
  return res.json({
    running: currentMonitor?.isConnected() ?? false,
    states: currentMonitor?.getAllStates() ?? [],
  });
});

export default router;
