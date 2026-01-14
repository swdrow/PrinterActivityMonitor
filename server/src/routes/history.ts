import { Router } from 'express';
import { printHistoryService } from '../services/PrintHistoryService.js';

const router = Router();

// Get print history for a device
router.get('/', (req, res) => {
  const deviceId = req.query.deviceId as string;
  const limit = parseInt(req.query.limit as string) || 50;

  if (!deviceId) {
    return res.status(400).json({
      success: false,
      error: 'deviceId query parameter required',
    });
  }

  try {
    const history = printHistoryService.getHistory(deviceId, limit);
    return res.json({
      success: true,
      data: history,
    });
  } catch (error) {
    console.error('Error fetching history:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to fetch history',
    });
  }
});

// Get print statistics for a device
router.get('/stats', (req, res) => {
  const deviceId = req.query.deviceId as string;

  if (!deviceId) {
    return res.status(400).json({
      success: false,
      error: 'deviceId query parameter required',
    });
  }

  try {
    const stats = printHistoryService.getStats(deviceId);
    return res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to fetch stats',
    });
  }
});

// Get single print job details
router.get('/:jobId', (req, res) => {
  const { jobId } = req.params;

  try {
    const jobs = printHistoryService.getAllHistory(1000);
    const job = jobs.find(j => j.id === jobId);

    if (!job) {
      return res.status(404).json({
        success: false,
        error: 'Job not found',
      });
    }

    return res.json({
      success: true,
      data: job,
    });
  } catch (error) {
    console.error('Error fetching job:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to fetch job',
    });
  }
});

export default router;
