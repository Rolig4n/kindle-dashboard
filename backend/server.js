const express = require('express');
const axios = require('axios');
const Parser = require('rss-parser');
const Docker = require('dockerode');
const path = require('path');

const app = express();
const parser = new Parser();
const docker = new Docker({ socketPath: '/var/run/docker.sock' });

// FRONTEND_PATH pode ser sobrescrito via env; padrão cobre tanto o container
// (/app/frontend/public) quanto execução local a partir de backend/ (../frontend/public)
const fs = require('fs');
const containerPath = path.join(__dirname, 'frontend', 'public');
const localDevPath  = path.join(__dirname, '..', 'frontend', 'public');
const staticPath    = process.env.FRONTEND_PATH ||
                      (fs.existsSync(containerPath) ? containerPath : localDevPath);
app.use(express.static(staticPath));
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  next();
});


// ── Clima externo ─────────────────────────────────────────────────────────────
app.get('/api/weather', async (req, res) => {
  try {
    const { OWM_API_KEY, OWM_CITY, OWM_UNITS } = process.env;
    const units = OWM_UNITS || 'metric';
    const url = `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(OWM_CITY)}&appid=${OWM_API_KEY}&units=${units}&lang=pt_br`;
    const { data } = await axios.get(url, { timeout: 8000 });
    res.json({
      city: data.name,
      temp: Math.round(data.main.temp),
      feels_like: Math.round(data.main.feels_like),
      humidity: data.main.humidity,
      description: data.weather[0].description,
      icon: data.weather[0].icon,
    });
  } catch (e) {
    res.status(502).json({ error: 'Falha ao obter clima externo', detail: e.message });
  }
});

// ── Clima interno (proxy para o container de sensores) ────────────────────────
app.get('/api/home-climate', async (req, res) => {
  try {
    const { HOME_CLIMATE_URL } = process.env;
    if (!HOME_CLIMATE_URL) return res.json({ available: false });
    const { data } = await axios.get(HOME_CLIMATE_URL, { timeout: 5000 });
    res.json({ available: true, ...data });
  } catch (e) {
    res.status(502).json({ error: 'Falha ao obter clima interno', detail: e.message });
  }
});

// ── Containers Docker ─────────────────────────────────────────────────────────
app.get('/api/containers', async (req, res) => {
  try {
    const all = await docker.listContainers({ all: true });
    const list = all.map(c => {
      let statusLevel = 'stopped';
      const s = (c.State || '').toLowerCase();
      if (s === 'running') statusLevel = 'running';
      else if (['restarting', 'exited', 'dead', 'oomkilled'].includes(s)) statusLevel = 'error';
      return {
        id: c.Id.slice(0, 12),
        name: c.Names[0].replace(/^\//, ''),
        state: c.State,
        status: c.Status,
        level: statusLevel,
      };
    });
    res.json(list);
  } catch (e) {
    res.status(502).json({ error: 'Falha ao listar containers', detail: e.message });
  }
});

// ── RSS de notícias ───────────────────────────────────────────────────────────
app.get('/api/news', async (req, res) => {
  const feeds = (process.env.RSS_FEEDS || 'https://g1.globo.com/rss/g1/').split(',').map(f => f.trim());
  const MAX = parseInt(process.env.RSS_MAX_ITEMS || '20', 10);
  try {
    const results = await Promise.allSettled(feeds.map(url => parser.parseURL(url)));
    const items = [];
    for (const r of results) {
      if (r.status === 'fulfilled') {
        for (const item of r.value.items) {
          items.push({ title: item.title, link: item.link, pub: item.pubDate });
        }
      }
    }
    items.sort((a, b) => new Date(b.pub) - new Date(a.pub));
    res.json(items.slice(0, MAX));
  } catch (e) {
    res.status(502).json({ error: 'Falha ao obter notícias', detail: e.message });
  }
});

// ── Galeria de imagens ────────────────────────────────────────────────────────
app.get('/api/gallery', (req, res) => {
  const raw = process.env.GALLERY_URLS || '';
  const urls = raw.split(',').map(u => u.trim()).filter(Boolean);
  res.json(urls);
});

// ── Healthcheck ───────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => res.json({ ok: true, ts: new Date().toISOString() }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`kindle-dashboard running on :${PORT}`));
