const https = require('node:https');

const bodyLimit = 1024 * 1024;

function sendError(res, status, message, detail) {
  res.status(status).json({
    error: {
      message,
      detail,
    },
  });
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    if (req.body && typeof req.body === 'object') {
      resolve(req.body);
      return;
    }

    let raw = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > bodyLimit) {
        reject(new Error('Request body is too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!raw.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(new Error(`Invalid JSON: ${error.message}`));
      }
    });
    req.on('error', reject);
  });
}

function cleanInt(value, fallback, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, Math.round(number)));
}

function normalizeRequest(body) {
  const prompt = typeof body.prompt === 'string' ? body.prompt : '';
  if (!prompt.trim()) throw new Error('Missing required field: prompt');

  const size = typeof body.size === 'string' ? body.size.split('x') : [];
  return {
    prompt,
    model: typeof body.model === 'string' && body.model.trim() ? body.model.trim() : 'gpt-image-2',
    quality: typeof body.quality === 'string' && body.quality.trim() ? body.quality.trim() : 'low',
    width: cleanInt(body.width || size[0], 512, 128, 2048),
    height: cleanInt(body.height || size[1], 512, 128, 2048),
    responseFormat: body.response_format === 'url' ? 'url' : 'b64_json',
  };
}

function callPuterGenerate(params, token) {
  const body = JSON.stringify({
    interface: 'puter-image-generation',
    driver: 'ai-image',
    method: 'generate',
    args: {
      prompt: params.prompt,
      model: params.model,
      quality: params.quality,
      width: params.width,
      height: params.height,
    },
    auth_token: token,
  });

  const requestOptions = {
    method: 'POST',
    hostname: 'api.puter.com',
    path: '/drivers/call',
    headers: {
      'content-type': 'text/plain;actually=json',
      'content-length': Buffer.byteLength(body),
      'user-agent': 'puter-image-studio-vercel/1.0',
    },
    timeout: 120000,
  };

  return new Promise((resolve, reject) => {
    const request = https.request(requestOptions, (response) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let parsed;
        try {
          parsed = JSON.parse(raw);
        } catch (_error) {
          reject(new Error(`Puter returned non-JSON HTTP ${response.statusCode}: ${raw.slice(0, 300)}`));
          return;
        }

        if (response.statusCode < 200 || response.statusCode >= 300 || parsed.success !== true) {
          reject(new Error(`Puter HTTP ${response.statusCode}: ${JSON.stringify(parsed).slice(0, 500)}`));
          return;
        }

        resolve(parsed.result);
      });
    });

    request.on('timeout', () => request.destroy(new Error('Puter request timed out')));
    request.on('error', reject);
    request.write(body);
    request.end();
  });
}

function parseDataUrl(dataUrl) {
  const match = /^data:image\/png;base64,([A-Za-z0-9+/=]+)$/.exec(dataUrl || '');
  if (!match) throw new Error('Puter response was not a PNG data URL');
  return match[1];
}

module.exports = async function handler(req, res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-methods', 'POST,OPTIONS');
  res.setHeader('access-control-allow-headers', 'content-type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'POST') {
    sendError(res, 405, 'Method not allowed');
    return;
  }

  let params;
  try {
    params = normalizeRequest(await readJson(req));
  } catch (error) {
    sendError(res, 400, error.message);
    return;
  }

  const token = process.env.PUTER_AUTH_TOKEN;
  if (!token) {
    sendError(res, 500, 'Puter token is not configured');
    return;
  }

  try {
    const result = await callPuterGenerate(params, token.trim());
    const b64 = parseDataUrl(result);
    const item = { revised_prompt: params.prompt };

    if (params.responseFormat === 'url') {
      item.b64_json = b64;
    } else {
      item.b64_json = b64;
    }

    res.status(200).json({
      created: Math.floor(Date.now() / 1000),
      data: [item],
    });
  } catch (error) {
    sendError(res, 502, 'Image generation failed', error.message);
  }
};
