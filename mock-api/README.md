# Mock Visitor API — Naapbooks Flutter Assessment

A small local API for the visitor check-in kiosk. **Use it unchanged.** You do not need to write any backend.

## Run

Needs Node.js 18 or later. No `npm install` — there are no dependencies.

```bash
node server.js        # http://localhost:4000
```

From an **Android emulator**, the host machine is `http://10.0.2.2:4000`.
From a **physical device**, use your computer's LAN IP (e.g. `http://192.168.1.20:4000`) and make sure both are on the same network.
**Flutter web** works directly — CORS is enabled.

## Deliberate behaviour

Every endpoint except `/health`:
- waits **300–1500 ms** before responding
- returns **500** about **5%** of the time

This is on purpose. Your app should show loading, error and retry states. Grading is done with these defaults on.

For local development only, you can turn them off:

```bash
MOCK_LATENCY=off MOCK_FAILURE_RATE=0 node server.js     # or: npm run dev
```

Data is generated from a fixed seed, so hosts and visitors are the same every run. Anything you create is held in memory and lost when the server restarts.

## Endpoints

### `GET /health`
No latency, never fails.
```json
{ "ok": true, "latency": true, "failureRate": 0.05 }
```

### `GET /purposes`
```json
{ "items": [ { "id": "meeting", "label": "Meeting" }, ... ] }
```

### `GET /hosts?q=`
All 500 hosts. `q` (optional) filters by name or department, case-insensitive. You may search on the client or the server — your choice.
```json
{
  "items": [
    { "id": "h_0001", "name": "Aarav Shah", "designation": "Manager",
      "department": "Finance", "floor": "2nd",
      "email": "aarav.shah0@example.in", "available": true }
  ],
  "total": 500
}
```

### `GET /visitors?date=&status=&limit=&cursor=`
Today's visitors (2,000 seeded), newest first, cursor-paged.

| Param | Default | Notes |
|---|---|---|
| `date` | today | `YYYY-MM-DD` |
| `status` | all | `checked_in`, `checked_out`, `expected` |
| `limit` | 50 | 1–100 |
| `cursor` | — | pass `nextCursor` from the previous page |

```json
{
  "items": [
    { "id": "v_000123", "name": "Riya Patel", "mobile": "9876543210",
      "company": "Infosys", "purpose": "meeting",
      "hostId": "h_0042", "hostName": "Kunal Mehta",
      "status": "checked_in",
      "checkInAt": "2026-10-22T05:12:44.000Z", "checkOutAt": null,
      "expectedAt": "2026-10-22T05:12:44.000Z",
      "hasPhoto": false, "badgeCode": "NBV-4K9Q2X", "consent": true }
  ],
  "nextCursor": "MjAyNi0xMC0yMlQwNTox..."
}
```
`nextCursor` is `null` on the last page. Treat it as opaque.

### `GET /visitors/:id`
One visitor, or `404`.

### `GET /visitors/:id/photo`
The photo bytes (`image/jpeg`, `image/png` or `image/webp`), or `404` if none.

### `POST /visitors`
Creates a visitor and checks them in.

```json
{
  "name": "Riya Patel",
  "mobile": "9876543210",
  "company": "Infosys",
  "purpose": "meeting",
  "hostId": "h_0042",
  "consent": true,
  "photo": "data:image/jpeg;base64,/9j/4AAQ..."
}
```
- `company` and `photo` are optional. Everything else is required.
- `photo` must be a base64 **data URL** (jpeg, png or webp). Max request size **3 MB** — compress before sending.

**201** — the created visitor (same shape as above).
**422** — validation failed:
```json
{ "error": "validation_failed",
  "fields": { "mobile": "Enter a valid 10-digit Indian mobile number.",
              "consent": "Consent is required." } }
```
**413** — request too large.

### `POST /visitors/:id/checkout`
**200** — the updated visitor.
**404** — not found.
**409** — `already_checked_out` or `not_checked_in` (the current visitor is included in the body).

## Things the API does *not* do

These are deliberate — decide how your app handles them and say so in `SUBMISSION.md`:
- **There is no undo endpoint.** "Swipe to check out with undo" has to be designed in the app.
- **There is no idempotency key.** A `POST /visitors` that fails with 500 did *not* create anything, but a request that times out on your side might have.
- **There is no authentication**, and no push or socket channel.
