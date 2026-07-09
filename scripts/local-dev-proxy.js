#!/usr/bin/env node

const http = require('http');
const https = require('https');
const tls = require('tls');

const PORT = Number(process.env.PORT || 3000);
const TARGET_HOST = process.env.TARGET_HOST || 'secertbase.kro.kr';
const TARGET_ORIGIN = `https://${TARGET_HOST}`;
const LOCAL_PLACE_SEARCH_ORIGIN = process.env.LOCAL_PLACE_SEARCH_ORIGIN || '';
const PROXY_PREFIXES = ['/api', '/socket.io', '/uploads', '/health'];

function shouldProxy(url) {
  return PROXY_PREFIXES.some((prefix) => url === prefix || url.startsWith(`${prefix}/`) || url.startsWith(`${prefix}?`));
}

function writeCors(res, origin) {
  if (!origin) return;
  res.setHeader('access-control-allow-origin', origin);
  res.setHeader('access-control-allow-credentials', 'true');
  res.setHeader('access-control-allow-methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('access-control-allow-headers', 'content-type,authorization,x-requested-with');
}

const server = http.createServer((req, res) => {
  const origin = req.headers.origin;
  writeCors(res, origin);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (!shouldProxy(req.url || '/')) {
    res.writeHead(404, {'content-type': 'text/plain; charset=utf-8'});
    res.end('Local proxy only handles /api, /socket.io, /uploads, and /health.\nRun Flutter on port 5050.');
    return;
  }

  if (LOCAL_PLACE_SEARCH_ORIGIN && (req.url || '').startsWith('/api/places/search')) {
    proxyToOrigin(req, res, LOCAL_PLACE_SEARCH_ORIGIN, origin);
    return;
  }

  const headers = {...req.headers, host: TARGET_HOST, origin: TARGET_ORIGIN};
  delete headers['accept-encoding'];

  const proxyReq = https.request(
    {
      hostname: TARGET_HOST,
      port: 443,
      method: req.method,
      path: req.url,
      headers,
    },
    (proxyRes) => {
      const responseHeaders = {...proxyRes.headers};
      responseHeaders['access-control-allow-origin'] = origin || '*';
      responseHeaders['access-control-allow-credentials'] = 'true';
      res.writeHead(proxyRes.statusCode || 502, responseHeaders);
      proxyRes.pipe(res);
    },
  );

  proxyReq.on('error', (err) => {
    res.writeHead(502, {'content-type': 'application/json'});
    res.end(JSON.stringify({ok: false, error: 'proxy_failed', message: err.message}));
  });

  req.pipe(proxyReq);
});

function proxyToOrigin(req, res, targetOrigin, origin) {
  const target = new URL(targetOrigin);
  const isHttps = target.protocol === 'https:';
  const requestModule = isHttps ? https : http;
  const headers = {...req.headers, host: target.host, origin: targetOrigin};
  delete headers['accept-encoding'];

  const proxyReq = requestModule.request(
    {
      hostname: target.hostname,
      port: target.port || (isHttps ? 443 : 80),
      method: req.method,
      path: req.url,
      headers,
    },
    (proxyRes) => {
      const responseHeaders = {...proxyRes.headers};
      responseHeaders['access-control-allow-origin'] = origin || '*';
      responseHeaders['access-control-allow-credentials'] = 'true';
      res.writeHead(proxyRes.statusCode || 502, responseHeaders);
      proxyRes.pipe(res);
    },
  );

  proxyReq.on('error', (err) => {
    res.writeHead(502, {'content-type': 'application/json'});
    res.end(JSON.stringify({ok: false, error: 'local_proxy_failed', message: err.message}));
  });

  req.pipe(proxyReq);
}

server.on('upgrade', (req, socket, head) => {
  if (!shouldProxy(req.url || '/')) {
    socket.destroy();
    return;
  }

  const upstream = tls.connect(443, TARGET_HOST, {servername: TARGET_HOST}, () => {
    const headers = {...req.headers, host: TARGET_HOST, origin: TARGET_ORIGIN};
    const lines = [`${req.method} ${req.url} HTTP/${req.httpVersion}`];
    for (const [key, value] of Object.entries(headers)) {
      if (Array.isArray(value)) {
        value.forEach((item) => lines.push(`${key}: ${item}`));
      } else if (value != null) {
        lines.push(`${key}: ${value}`);
      }
    }
    upstream.write(`${lines.join('\r\n')}\r\n\r\n`);
    if (head.length > 0) upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });

  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
});

server.listen(PORT, () => {
  console.log(`Local dev proxy listening on http://localhost:${PORT}`);
  console.log(`Proxying ${PROXY_PREFIXES.join(', ')} -> ${TARGET_ORIGIN}`);
  if (LOCAL_PLACE_SEARCH_ORIGIN) {
    console.log(`Proxying /api/places/search -> ${LOCAL_PLACE_SEARCH_ORIGIN}`);
  }
});
