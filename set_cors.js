/**
 * Configura CORS en Firebase Storage via REST API.
 * No requiere gsutil ni paquetes extra.
 * Ejecutar: node set_cors.js
 */
const https  = require('https');
const crypto = require('crypto');
const fs     = require('fs');

const KEY    = require('./serviceAccountKey.json');
const BUCKET = 'mi-actividad-2i6jx7.firebasestorage.app';

// ── JWT para obtener access token ─────────────────────────────────────────────
function makeJwt() {
  const now = Math.floor(Date.now() / 1000);
  const header  = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    iss: KEY.client_email,
    scope: 'https://www.googleapis.com/auth/cloud-platform',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })).toString('base64url');

  const unsigned = `${header}.${payload}`;
  const sign     = crypto.createSign('RSA-SHA256');
  sign.update(unsigned);
  const sig = sign.sign(KEY.private_key, 'base64url');
  return `${unsigned}.${sig}`;
}

function getToken() {
  return new Promise((res, rej) => {
    const body = `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${makeJwt()}`;
    const req  = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token', method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': body.length },
    }, r => {
      let d = '';
      r.on('data', c => d += c);
      r.on('end', () => {
        const j = JSON.parse(d);
        if (j.access_token) res(j.access_token);
        else rej(new Error(d));
      });
    });
    req.on('error', rej);
    req.write(body);
    req.end();
  });
}

function listBuckets(token) {
  return new Promise((res, rej) => {
    const req = https.request({
      hostname: 'storage.googleapis.com',
      path: `/storage/v1/b?project=mi-actividad-2i6jx7`,
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    }, r => {
      let d = '';
      r.on('data', c => d += c);
      r.on('end', () => { console.log('Buckets del proyecto:\n', d); res(); });
    });
    req.on('error', rej);
    req.end();
  });
}

function setCors(token) {
  return new Promise((res, rej) => {
    const cors = JSON.stringify([{
      origin: ['*'],
      method: ['GET','POST','PUT','DELETE','HEAD','OPTIONS'],
      responseHeader: ['Content-Type','Authorization','Content-Length','User-Agent','x-goog-resumable'],
      maxAgeSeconds: 3600,
    }]);
    // PATCH solo el campo cors del bucket
    const path = `/storage/v1/b/${encodeURIComponent(BUCKET)}?fields=cors`;
    const req  = https.request({
      hostname: 'storage.googleapis.com',
      path, method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(cors),
      },
    }, r => {
      let d = '';
      r.on('data', c => d += c);
      r.on('end', () => {
        if (r.statusCode === 200) {
          console.log('✅ CORS configurado en', BUCKET);
          console.log(d);
        } else {
          console.error('❌ Status', r.statusCode, d);
        }
        res();
      });
    });
    req.on('error', rej);
    req.write(cors);
    req.end();
  });
}

(async () => {
  try {
    console.log('Obteniendo token...');
    const token = await getToken();
    console.log('Token OK. Listando buckets...');
    await listBuckets(token);
    console.log('\nConfigurando CORS...');
    await setCors(token);
  } catch (e) {
    console.error('❌', e.message);
  }
})();
