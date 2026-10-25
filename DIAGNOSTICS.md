# Section B — Diagnostics

## B1. UI thread 8 ms, raster thread 40 ms on a low-cost tablet

This is a **raster-bound (GPU) problem, not a Dart/build problem.** The UI thread finishes in 8 ms (budget 16.6 ms) but the
raster thread needs 40 ms to turn the layer tree into pixels, so frames drop (~25 fps): the weak tablet GPU is the bottleneck.
Likely causes: (1) `saveLayer` from `Opacity`, `ShaderMask`, `ClipRRect` with `antiAlias`, `BackdropFilter` or large blurred
shadows inside rows; (2) oversized images decoded at full size and scaled on the GPU (no `cacheWidth`/`cacheHeight`);
(3) shader-compilation jank on first use, or overdraw from stacked opaque backgrounds.
**First check:** profile mode on that tablet, DevTools → Performance with *Enhance Tracing* and "Highlight offscreen layers";
the `saveLayer` hot spots show up directly. Fix the worst one, then re-measure. I would not touch `build()` first — the UI
thread numbers say it is not the problem.

## B2. Overflow stripes in Gujarati at large font, English fine

Gujarati strings are longer and the glyphs taller, so any layout that assumed English widths/heights breaks. Proper fix, not a
patch: **remove the assumptions.** Replace fixed `height`/`width` on containers with `minHeight` constraints or let content size
itself; put label+value pairs in `Wrap` or give the text `Expanded`/`Flexible` inside `Row`; make the form a scrollable
(`ListView`/`SingleChildScrollView`) so extra height just scrolls; use `InputDecoration.labelText` rather than separate fixed-size
labels and avoid `Row`s of buttons (wrap them). Don't "fix" with `FittedBox`/shrinking text or by clamping the scale — that fails
the accessibility requirement. Then lock it in: a widget test that pumps the form at `textScaler: 2.0` for `en`, `hi`, `gu`
and asserts `tester.takeException()` is null (this repo has it: `test/overflow_test.dart`), plus test on a device with the real font.

## B3. Typing in search rebuilds the whole screen including 500 rows

Same state library, three fixes in the order I would try them: (1) **Narrow what each widget watches.** Keep the text field
in its own widget that does not watch the results, and make the results a separate `ConsumerWidget` watching a derived
provider; per-row widgets use `ref.watch(provider.select((s) => s.hostId == id))` so one selection change rebuilds two rows.
(2) **Debounce** the query commit (300 ms) so a fast typist triggers one filter + rebuild, not one per keystroke — the field's
own controller still updates instantly. (3) **Make the list lazy and cheap:** `ListView.builder` with stable `ValueKey`s, `const`
constructors for static subtrees, and filter once into a derived (memoised) provider instead of inside `build()`. If it is
still slow, move filtering of large data to `compute()`. Verify with DevTools "Track widget rebuilds" rather than guessing.
This repo does (1), (2) and the lazy list.

## B4. `setState() called after dispose()` / "deactivated widget's ancestor" after submit

The submit handler awaits a network call (300–1500 ms, longer on retries). While waiting, the user navigates away (or the route
is replaced), so the `State`/`BuildContext` is gone; when the future completes the code calls `setState`, `Navigator`, or
`ScaffoldMessenger.of(context)` on a disposed element. Fix: **after every `await`, check `if (!mounted) return;`** (or
`context.mounted` in a callback) before touching `setState`/`context`; capture what you need (`ScaffoldMessenger.of(context)`,
localised strings, the notifier) *before* the await; cancel timers/subscriptions in `dispose()`. Better, keep the request and its
result in a provider/controller that outlives the widget, so the widget only renders state and navigation happens only if still
mounted. In this app: `_submit` checks `mounted` after the await, `BadgePage` cancels its timer in `dispose`, and the visitors
undo flow captures the messenger and notifier up front.

## B5. Guard takes a phone call, comes back, the form is empty

Android can kill a backgrounded app to reclaim memory (and the camera/other apps make this likelier); on web a reload or tab
discard does the same. Widget state and in-memory providers die with the process, so the form comes back empty. Fix: **persist
the draft outside memory on every change**, and restore on start. Here the `CheckinDraft` is written through to
`SharedPreferences` (localStorage on web) from the controller, the photo under its own key so typing does not rewrite a large
blob, and `main()` loads prefs before `runApp` so restore is synchronous. For the camera specifically, Android may destroy the
Activity while the camera app is open, so on start I call `ImagePicker.retrieveLostData()`. Also clear the draft on successful
submit, and show "Your unfinished form was restored" plus a Clear button so staleness is visible. Note a privacy trade-off:
a kiosk draft contains personal data, so I'd add an expiry (e.g. discard drafts older than a few hours) — not built.

## B6. Admin web app 9 MB, 12 s on mid-range phone over 4G, on IIS

Measure first (Lighthouse / Network tab), then in order of payoff: (1) **Enable compression on IIS** — static gzip/Brotli
(`<urlCompression doStaticCompression="true" />`, include `application/wasm`, `.js`, `.json`, `.otf`); Flutter output compresses
~3–4×, which alone is most of the gain. (2) **MIME types and caching:** register `.wasm`, `.json`, `.otf` so IIS doesn't 404
them; long `Cache-Control` on static assets but no-cache on `index.html`, `flutter_bootstrap.js` and `flutter_service_worker.js`;
add the SPA URL-Rewrite rule so deep links work. (3) **Shrink the payload:** release build, tree-shaken icons (default), drop
unused packages/fonts/images, split rarely used admin screens into **deferred components** (`deferred as`), use the Wasm build
or self-host CanvasKit instead of the CDN. (4) Add an HTML splash and serve over HTTP/2. If the admin is mostly forms and
tables, ask whether Flutter web is the right tool at all — a bigger decision.
