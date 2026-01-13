import { Router } from 'express';
import { z } from 'zod';
import { HomeAssistantService } from '../services/HomeAssistant.js';
import { EntityDiscoveryService } from '../services/EntityDiscovery.js';

const router = Router();

const scanSchema = z.object({
  haUrl: z.string().url(),
  haToken: z.string().min(1),
});

router.post('/scan', async (req, res) => {
  const parsed = scanSchema.safeParse(req.body);

  if (!parsed.success) {
    return res.status(400).json({
      error: 'Invalid request',
      details: parsed.error.flatten().fieldErrors,
    });
  }

  const { haUrl, haToken } = parsed.data;

  const ha = new HomeAssistantService();

  try {
    // Connect to Home Assistant
    await ha.connect({ url: haUrl, token: haToken });

    // Fetch all entities
    const entities = await ha.getStates();

    // Discover printers and AMS units
    const printers = EntityDiscoveryService.discoverPrinters(entities);
    const amsUnits = EntityDiscoveryService.discoverAMS(entities);

    // Disconnect after discovery
    ha.disconnect();

    return res.json({
      success: true,
      printers,
      amsUnits,
      totalEntities: entities.length,
    });
  } catch (error) {
    ha.disconnect();

    return res.status(500).json({
      success: false,
      error: 'Discovery failed',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

export default router;
