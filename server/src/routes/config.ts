import { Router } from 'express';
import { apnsService } from '../services/APNsService.js';
import { env } from '../config/index.js';

const router = Router();

// Initialize APNs on server startup
router.post('/apns/init', (req, res) => {
  if (!env.APNS_TEAM_ID || !env.APNS_KEY_ID || !env.APNS_KEY_PATH) {
    return res.status(400).json({
      success: false,
      error: 'APNs not configured. Set APNS_TEAM_ID, APNS_KEY_ID, APNS_KEY_PATH in .env',
    });
  }

  try {
    apnsService.configure({
      teamId: env.APNS_TEAM_ID,
      keyId: env.APNS_KEY_ID,
      keyPath: env.APNS_KEY_PATH,
      bundleId: env.APNS_BUNDLE_ID,
      production: env.APNS_PRODUCTION === 'true',
    });

    return res.json({
      success: true,
      message: 'APNs configured',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to configure APNs',
    });
  }
});

// Check APNs status
router.get('/apns/status', (req, res) => {
  return res.json({
    configured: apnsService.isReady(),
    bundleId: env.APNS_BUNDLE_ID,
    production: env.APNS_PRODUCTION === 'true',
  });
});

export default router;
