'use strict';

const assert = require('assert');
const request = require('supertest');
const createApp = require('../../src/app');

describe('application', () => {
  afterEach(() => {
    delete process.env.NAME;
  });

  it('greets the name from the NAME environment variable', async () => {
    process.env.NAME = 'Ahmad';
    const res = await request(createApp()).get('/');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.text, 'Hello Ahmad!');
  });

  it('falls back to "guest" when NAME is not set', async () => {
    const res = await request(createApp()).get('/');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.text, 'Hello guest!');
  });

  it('exposes a health endpoint', async () => {
    const res = await request(createApp()).get('/healthz');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'ok');
  });
});
