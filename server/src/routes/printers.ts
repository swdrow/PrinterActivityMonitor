import { Router } from 'express';
import { PrinterMonitor } from '../services/PrinterMonitor.js';

const router = Router();

// Global printer monitor instance (will be set by app startup)
let printerMonitor: PrinterMonitor | null = null;

export function setPrinterMonitor(monitor: PrinterMonitor): void {
  printerMonitor = monitor;
}

router.get('/state', (req, res) => {
  if (!printerMonitor || !printerMonitor.isConnected()) {
    return res.status(503).json({
      success: false,
      error: 'Printer monitor not connected',
    });
  }

  const states = printerMonitor.getAllStates();

  return res.json({
    success: true,
    connected: true,
    printers: states,
    timestamp: new Date().toISOString(),
  });
});

router.get('/state/:prefix', (req, res) => {
  if (!printerMonitor || !printerMonitor.isConnected()) {
    return res.status(503).json({
      success: false,
      error: 'Printer monitor not connected',
    });
  }

  const { prefix } = req.params;
  const state = printerMonitor.getState(prefix);

  if (!state) {
    return res.status(404).json({
      success: false,
      error: `Printer with prefix '${prefix}' not found`,
    });
  }

  return res.json({
    success: true,
    printer: state,
    timestamp: new Date().toISOString(),
  });
});

export default router;
