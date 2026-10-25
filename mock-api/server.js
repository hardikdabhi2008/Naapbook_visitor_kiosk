#!/usr/bin/env node
/**
 * Naapbooks Flutter Assessment — Mock Visitor API
 *
 * Zero dependencies. Node 18+.  Run:  node server.js   (or: npm start)
 *
 * Use this file UNCHANGED. Latency and random failures are deliberate:
 * your app is expected to handle loading, error and retry states.
 *
 * Optional env vars for local development only (grading uses defaults):
 *   PORT=4000  MOCK_LATENCY=on|off  MOCK_FAILURE_RATE=0.05
 */
'use strict';

const http = require('http');
const { URL } = require('url');

const PORT = Number(process.env.PORT || 4000);
const LATENCY = (process.env.MOCK_LATENCY || 'on') !== 'off';
const FAILURE_RATE = process.env.MOCK_FAILURE_RATE !== undefined
  ? Number(process.env.MOCK_FAILURE_RATE) : 0.05;
const MAX_BODY_BYTES = 3 * 1024 * 1024; // 3MB — enough for a compressed photo

// ---------------------------------------------------------------------------
// Deterministic data — every candidate gets the same hosts and visitors.
// ---------------------------------------------------------------------------
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = rng(20261022);
const pick = (a) => a[Math.floor(rand() * a.length)];

const FIRST = ['Aarav','Vivaan','Aditya','Arjun','Reyansh','Krish','Ishaan','Rohan','Kunal','Harsh',
  'Ananya','Diya','Isha','Kavya','Riya','Saanvi','Nisha','Pooja','Meera','Tanvi','Rahul','Amit',
  'Neha','Priya','Sneha','Vikram','Manish','Deepak','Sunita','Jignesh','Hetal','Bhavesh','Dhruv',
  'Krupa','Nirali','Parth','Yash','Zeel','Mohammed','Fatima','Gurpreet','Simran','Thomas','Mary'];
const LAST = ['Patel','Shah','Mehta','Desai','Joshi','Trivedi','Sharma','Verma','Gupta','Singh',
  'Iyer','Nair','Reddy','Rao','Kulkarni','Deshpande','Chauhan','Parmar','Solanki','Bhatt',
  'Khan','Fernandes','Das','Banerjee','Mukherjee','Pillai','Menon','Agarwal','Jain','Thakkar'];
const DEPARTMENTS = ['Finance','Engineering','Sales','HR','Legal','Operations','Procurement',
  'Marketing','Admin','Quality','Security','IT Support'];
const FLOORS = ['Ground','1st','2nd','3rd','4th','5th'];
const COMPANIES = ['Tata Consultancy','Infosys','Reliance Retail','Adani Ports','Zydus','Torrent Power',
  'Amul','Arvind Ltd','Cadila','Nirma','Self','Freelance','HDFC Bank','ICICI Bank','L&T'];
const PURPOSES = [
  { id: 'meeting', label: 'Meeting' },
  { id: 'interview', label: 'Interview' },
  { id: 'delivery', label: 'Delivery' },
  { id: 'vendor', label: 'Vendor / Contractor' },
  { id: 'maintenance', label: 'Maintenance' },
  { id: 'personal', label: 'Personal' },
];

const mobile = () => String(6 + Math.floor(rand() * 4)) +
  String(Math.floor(rand() * 1e9)).padStart(9, '0');

const hosts = Array.from({ length: 500 }, (_, i) => {
  const first = pick(FIRST), last = pick(LAST);
  return {
    id: `h_${String(i + 1).padStart(4, '0')}`,
    name: `${first} ${last}`,
    designation: pick(['Manager','Sr. Manager','Executive','Lead','Director','Associate','VP']),
    department: pick(DEPARTMENTS),
    floor: pick(FLOORS),
    email: `${first}.${last}${i}@example.in`.toLowerCase(),
    available: rand() > 0.15,
  };
});
const hostById = new Map(hosts.map((h) => [h.id, h]));

function todayAt(hour, minute) {
  const d = new Date();
  d.setHours(hour, minute, Math.floor(rand() * 60), 0);
  return d;
}
const isoDate = (d) => {
  const y = d.getFullYear(), m = String(d.getMonth() + 1).padStart(2, '0'),
    day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

let seq = 0;
const nextId = () => `v_${String(++seq).padStart(6, '0')}`;
const visitors = [];
for (let i = 0; i < 2000; i++) {
  // Skewed: most arrivals between 09:30 and 12:30.
  const hour = rand() < 0.6 ? 9 + Math.floor(rand() * 4) : 8 + Math.floor(rand() * 11);
  const checkInAt = todayAt(hour, Math.floor(rand() * 60));
  const r = rand();
  const status = r < 0.55 ? 'checked_out' : r < 0.9 ? 'checked_in' : 'expected';
  const host = pick(hosts);
  visitors.push({
    id: nextId(),
    name: `${pick(FIRST)} ${pick(LAST)}`,
    mobile: mobile(),
    company: pick(COMPANIES),
    purpose: pick(PURPOSES).id,
    hostId: host.id,
    hostName: host.name,
    status,
    checkInAt: status === 'expected' ? null : checkInAt.toISOString(),
    checkOutAt: status === 'checked_out'
      ? new Date(checkInAt.getTime() + (20 + Math.floor(rand() * 200)) * 60000).toISOString()
      : null,
    expectedAt: checkInAt.toISOString(),
    hasPhoto: false,
    badgeCode: `NBV-${Math.floor(rand() * 36 ** 6).toString(36).toUpperCase().padStart(6, '0')}`,
    consent: true,
  });
}
const photos = new Map(); // visitorId -> { mime, buffer }

// Stable order for paging: newest first, id as tie-break.
const sortKey = (v) => v.checkInAt || v.expectedAt;
const compare = (a, b) =>
  sortKey(b).localeCompare(sortKey(a)) || b.id.localeCompare(a.id);

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Request-Id',
  'Access-Control-Expose-Headers': 'X-Request-Id',
};
function send(res, status, body, headers = {}) {
  const isBuffer = Buffer.isBuffer(body);
  res.writeHead(status, {
    ...CORS,
    'Content-Type': isBuffer ? headers['Content-Type'] : 'application/json; charset=utf-8',
    ...headers,
  });
  res.end(isBuffer ? body : JSON.stringify(body));
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
function readJson(req) {
  return new Promise((resolve, reject) => {
    let size = 0; const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY_BYTES) { reject(Object.assign(new Error('too_large'), { status: 413 })); req.destroy(); }
      else chunks.push(c);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch { reject(Object.assign(new Error('invalid_json'), { status: 400 })); }
    });
    req.on('error', reject);
  });
}
const encodeCursor = (v) => Buffer.from(`${sortKey(v)}|${v.id}`).toString('base64url');
function decodeCursor(c) {
  try {
    const [key, id] = Buffer.from(c, 'base64url').toString('utf8').split('|');
    if (!key || !id) return null;
    return { key, id };
  } catch { return null; }
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
async function route(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const m = req.method;

  if (m === 'OPTIONS') return send(res, 204, {});

  if (m === 'GET' && path === '/health') {
    return send(res, 200, { ok: true, latency: LATENCY, failureRate: FAILURE_RATE });
  }

  // Latency + random failure apply to every API route below.
  if (LATENCY) await sleep(300 + Math.floor(Math.random() * 1200));
  if (Math.random() < FAILURE_RATE) {
    return send(res, 500, { error: 'internal_error', message: 'Simulated server failure. Retry.' });
  }

  if (m === 'GET' && path === '/purposes') return send(res, 200, { items: PURPOSES });

  if (m === 'GET' && path === '/hosts') {
    const q = (url.searchParams.get('q') || '').trim().toLowerCase();
    const items = q
      ? hosts.filter((h) =>
          h.name.toLowerCase().includes(q) || h.department.toLowerCase().includes(q))
      : hosts;
    return send(res, 200, { items, total: items.length });
  }

  if (m === 'GET' && path === '/visitors') {
    const date = url.searchParams.get('date') || isoDate(new Date());
    const status = url.searchParams.get('status');
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit')) || 50, 1), 100);
    const cursorRaw = url.searchParams.get('cursor');
    const cursor = cursorRaw ? decodeCursor(cursorRaw) : null;
    if (cursorRaw && !cursor) return send(res, 400, { error: 'invalid_cursor' });
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return send(res, 400, { error: 'invalid_date', message: 'Use YYYY-MM-DD.' });

    let list = visitors
      .filter((v) => isoDate(new Date(sortKey(v))) === date)
      .filter((v) => !status || v.status === status)
      .sort(compare);
    if (cursor) {
      list = list.filter((v) => {
        const k = sortKey(v);
        return k < cursor.key || (k === cursor.key && v.id < cursor.id);
      });
    }
    const page = list.slice(0, limit);
    const nextCursor = list.length > limit ? encodeCursor(page[page.length - 1]) : null;
    return send(res, 200, { items: page, nextCursor });
  }

  if (m === 'POST' && path === '/visitors') {
    let body;
    try { body = await readJson(req); }
    catch (e) { return send(res, e.status || 400, { error: e.message }); }

    const errors = {};
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (name.length < 2 || name.length > 80) errors.name = 'Name must be 2–80 characters.';
    if (!/^[6-9]\d{9}$/.test(String(body.mobile || ''))) errors.mobile = 'Enter a valid 10-digit Indian mobile number.';
    if (!PURPOSES.some((p) => p.id === body.purpose)) errors.purpose = 'Choose a purpose.';
    const host = hostById.get(body.hostId);
    if (!host) errors.hostId = 'Choose a host.';
    if (body.consent !== true) errors.consent = 'Consent is required.';
    let photo = null;
    if (body.photo !== undefined && body.photo !== null) {
      const match = /^data:(image\/(jpeg|png|webp));base64,([A-Za-z0-9+/=]+)$/.exec(String(body.photo));
      if (!match) errors.photo = 'Photo must be a base64 data URL (jpeg, png or webp).';
      else photo = { mime: match[1], buffer: Buffer.from(match[3], 'base64') };
    }
    if (Object.keys(errors).length) {
      return send(res, 422, { error: 'validation_failed', fields: errors });
    }

    const now = new Date();
    const visitor = {
      id: nextId(),
      name,
      mobile: String(body.mobile),
      company: typeof body.company === 'string' ? body.company.trim().slice(0, 80) : null,
      purpose: body.purpose,
      hostId: host.id,
      hostName: host.name,
      status: 'checked_in',
      checkInAt: now.toISOString(),
      checkOutAt: null,
      expectedAt: now.toISOString(),
      hasPhoto: Boolean(photo),
      badgeCode: `NBV-${Math.floor(Math.random() * 36 ** 6).toString(36).toUpperCase().padStart(6, '0')}`,
      consent: true,
    };
    visitors.push(visitor);
    if (photo) photos.set(visitor.id, photo);
    return send(res, 201, visitor);
  }

  let match = /^\/visitors\/([^/]+)$/.exec(path);
  if (m === 'GET' && match) {
    const v = visitors.find((x) => x.id === match[1]);
    return v ? send(res, 200, v) : send(res, 404, { error: 'not_found' });
  }

  match = /^\/visitors\/([^/]+)\/photo$/.exec(path);
  if (m === 'GET' && match) {
    const p = photos.get(match[1]);
    return p ? send(res, 200, p.buffer, { 'Content-Type': p.mime, 'Cache-Control': 'max-age=3600' })
      : send(res, 404, { error: 'no_photo' });
  }

  match = /^\/visitors\/([^/]+)\/checkout$/.exec(path);
  if (m === 'POST' && match) {
    const v = visitors.find((x) => x.id === match[1]);
    if (!v) return send(res, 404, { error: 'not_found' });
    if (v.status === 'checked_out') return send(res, 409, { error: 'already_checked_out', visitor: v });
    if (v.status === 'expected') return send(res, 409, { error: 'not_checked_in', visitor: v });
    v.status = 'checked_out';
    v.checkOutAt = new Date().toISOString();
    return send(res, 200, v);
  }

  return send(res, 404, { error: 'route_not_found', path, method: m });
}

http.createServer((req, res) => {
  route(req, res).catch((err) => {
    console.error(err);
    if (!res.headersSent) send(res, 500, { error: 'unexpected', message: String(err.message || err) });
  });
}).listen(PORT, () => {
  console.log(`Mock Visitor API on http://localhost:${PORT}`);
  console.log(`  latency: ${LATENCY ? '300–1500ms' : 'off'} · failure rate: ${(FAILURE_RATE * 100).toFixed(1)}%`);
  console.log(`  ${hosts.length} hosts · ${visitors.length} visitors for ${isoDate(new Date())}`);
});
