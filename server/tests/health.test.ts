import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../src/index.js';

describe('Health Endpoint', () => {
  it('returns status ok', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(response.body.timestamp).toBeDefined();
    expect(response.body.environment).toBeDefined();
  });

  it('returns JSON content type', async () => {
    const response = await request(app).get('/health');

    expect(response.headers['content-type']).toMatch(/application\/json/);
  });
});
