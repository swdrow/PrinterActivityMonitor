import express from 'express';
import { env, isDev } from './config/index.js';
import { getDatabase } from './config/database.js';
import authRoutes from './routes/auth.js';
import discoveryRoutes from './routes/discovery.js';
import printerRoutes from './routes/printers.js';

const app = express();

// Middleware
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/discovery', discoveryRoutes);
app.use('/api/printers', printerRoutes);

// Initialize database
const db = getDatabase();
console.log('Database initialized');

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: env.NODE_ENV,
  });
});

// API routes placeholder
app.get('/api', (req, res) => {
  res.json({
    message: 'Printer Monitor API',
    version: '1.0.0',
    endpoints: [
      'GET /health',
      'POST /api/auth/validate',
      'POST /api/devices/register',
      'POST /api/discovery/scan',
      'GET /api/history',
      'GET /api/printers/state',
    ],
  });
});

// Start server (only if not in test mode)
if (!process.env.VITEST) {
  const PORT = parseInt(env.PORT, 10);

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    if (isDev) {
      console.log('Running in development mode');
    }
  });
}

export { app };
