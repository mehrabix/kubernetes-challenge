'use strict';

const express = require('express');

/**
 * Build the Express application.
 *
 * The greeting is intentionally driven by the NAME environment variable so it
 * can be supplied by a Kubernetes ConfigMap (the core of the challenge).
 */
function createApp() {
  const app = express();

  app.get('/', (req, res) => {
    const name = process.env.NAME || 'guest';
    res.type('text/plain').send(`Hello ${name}!`);
  });

  app.get('/healthz', (req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/readyz', (req, res) => {
    res.status(200).json({ status: 'ready', name: process.env.NAME || 'guest' });
  });

  return app;
}

module.exports = createApp;
