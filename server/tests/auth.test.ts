import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../src/index.js';

describe('Auth Endpoint', () => {
  describe('POST /api/auth/validate', () => {
    it('returns 400 for missing fields', async () => {
      const response = await request(app)
        .post('/api/auth/validate')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid request');
    });

    it('returns 400 for missing haToken', async () => {
      const response = await request(app)
        .post('/api/auth/validate')
        .send({ haUrl: 'http://localhost:8123' });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid request');
    });

    it('returns 400 for invalid URL format', async () => {
      const response = await request(app)
        .post('/api/auth/validate')
        .send({ haUrl: 'not-a-url', haToken: 'token123' });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid request');
    });

    // Note: Integration test would verify actual HA connection behavior
    // Skipping network test in unit tests to avoid timeout issues
    it.skip('returns 500 for unreachable server', async () => {
      const response = await request(app)
        .post('/api/auth/validate')
        .send({ haUrl: 'http://192.0.2.1:8123', haToken: 'token123' });

      expect(response.status).toBe(500);
      expect(response.body.valid).toBe(false);
    });
  });
});
