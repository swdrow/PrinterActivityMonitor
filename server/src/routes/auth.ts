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
    return res.status(500).json({
      valid: false,
      message: 'Connection failed',
      error: error instanceof Error ? error.message : String(error),
    });
  }
});

export default router;
