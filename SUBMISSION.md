# Submission — Naapbooks Visitor Kiosk

Flutter 3.47.7 / Dart 3.13.5. One codebase for Android tablet and Flutter web.

> **Status note.** Everything below marked ✅ was run and verified. Items marked ⏳ need an Android device or SDK that was not
> available where this was built; the exact steps to produce them are given. I have not invented numbers for them.

## 1. How to run

The full, step-by-step guide (prerequisites, scripts, troubleshooting) is in [README.md](README.md). Short version:

Start the mock API (an unchanged copy of `mock-api.zip` is in `./mock-api`; Node 18+):

```bash
node mock-api/server.js     # -> http://localhost:4000
```

```bash
flutter pub get

# Web
flutter run -d chrome

# Android device or emulator: reaches the API on your PC over USB
adb reverse tcp:4000 tcp:4000
flutter run -d <device-id> --dart-define=API_BASE_URL=http://localhost:4000
#   (or scripts/run-android.ps1 | .sh;  emulator-only shortcut: it already reaches 10.0.2.2:4000)

# Physical device over Wi-Fi instead: use your computer's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000
```

Admin PIN: **1234**.

One command to test the whole flow automatically in Chrome at phone, tablet and web sizes (details in §5):
`scripts/e2e-web.ps1` (Windows) or `scripts/e2e-web.sh`.

Build commands:

```bash
flutter build web --release                         # → build/web
flutter build apk --release                         # → build/app/outputs/flutter-apk/app-release.apk
flutter run --profile -d <device>                   # for DevTools numbers
```

IIS hosting of the web build: see `DIAGNOSTICS.md` B6 (MIME types, compression, SPA rewrite).

## 2. State management: Riverpod 3 (Notifier / AsyncNotifier), clean architecture

Layout is feature-first with `domain` / `data` / `presentation` per feature:

```
lib/
  core/        config, network (dio), error (ApiException), l10n, theme, shared widgets
  features/
    hosts/     domain: Host + HostRepository       data: HostModel, impl     presentation: providers, directory
    visitors/  domain: Visitor, use cases, repo    data: VisitorModel, impl  presentation: paged controller, list
    checkin/   domain: CheckinDraft, DraftRepo     data: prefs impl          presentation: controller, form, page
    badge/     presentation: BadgeContent (pure), BadgePage (timer)
    settings/  domain: AppSettings                 data: prefs impl          presentation: controller, admin screen
    home/      responsive shell (bottom bar / rail, 1200dp max width)
```

Domain has no Flutter or Dio imports apart from the entities' Dart types; data models extend the entities and own JSON parsing;
presentation depends on repository *interfaces* through providers, which is how the tests swap in fakes.

**Why Riverpod:** providers are testable without a widget tree, `select` gives per-row rebuilds (B3), and `ref.listen` plus
`mounted` checks cover the post-await cases in B4. Settings and the form draft are read synchronously from a pre-loaded
`SharedPreferences` (injected in `main()`), so the first frame is already in the right language and brand colour.

**What it cost me:**
- Riverpod 3 **auto-retries failed providers** by default. That would hide the error/retry states the brief asks for, so
  `ProviderScope(retry: (_, _) => null)` turns it off (see `lib/main.dart`).
- More files than `setState` + a repository would need. For a 3-hour build the boilerplate is real; it pays off for the
  four-app family in Section C.
- `AsyncNotifier.build` re-runs when the filter provider changes, which is neat for the visitors filter but means the previous
  list is dropped on filter change (loading state is shown instead of stale rows).

## 3. Performance evidence

| Item | Value |
|---|---|
| Web build size | ✅ `build/web` = 40.8 MB total, of which `canvaskit/` = 37 MB (variants fetched on demand, not all downloaded); `main.dart.js` = **3.30 MB** (release, tree-shaken icons: Material 1.6 MB → 10 KB) |
| Web renderer | ✅ **CanvasKit** (the default for `flutter build web` on 3.47; the HTML renderer no longer exists). A Wasm dry-run succeeded, so `--wasm` (skwasm) is an option. |
| Release APK size | ✅ `build/app/outputs/flutter-apk/app-release.apk` = **54.8 MB** (fat APK, all ABIs; `--split-per-abi` would be smaller). Built with Android Studio's JDK because `JAVA_HOME` pointed at JDK 8; `android/gradle.properties` sets `kotlin.incremental=false` because the project (F:) and pub cache (C:) are on different drive roots. |
| DevTools frame chart, visitors list scroll | ⏳ Needs a profile-mode run on a named device. Procedure: `flutter run --profile -d <device>`, open DevTools → Performance, fling the Today's visitors list, screenshot the frame chart into `evidence/`, and write the device name here. **Debug-mode numbers are not accepted by the brief and I have not supplied any.** |

What I expect to see and why (hypothesis to confirm, not a measurement): rows are plain `Column`/`Row`/`Text` widgets with no
`saveLayer`-triggering effects (no opacity layers, shadows or clipping per row), pages are 50 items, and rows have stable keys.

## 4. Golden tests ✅

`test/badge_golden_test.dart` — badge screen, **phone (390×844) and tablet (1280×800), light and dark, 1× and 2× font**
= 8 images in `test/goldens/`. Each case also asserts no layout exception was thrown.
The test environment draws text with the Ahem font (solid blocks), which is deliberate and makes goldens stable across machines.

Regenerate: `flutter test --update-goldens test/badge_golden_test.dart`.

Other tests (38 run + 5 live-API tests that skip without the server; all pass with `flutter test`):
- `overflow_test.dart` — check-in form, two-pane check-in, visitors, admin PIN and badge at **text scale 2.0 in English, Hindi and
  Gujarati** (phone 360 px wide; two-pane at 1280 px). No overflow exceptions.
- `app_flow_test.dart` — whole app with fake repositories: host picker + debounced search → form → check-in → badge → touch resets countdown → idle returns home and the form is cleared; hosts error → Retry; undo sends nothing / lapse sends exactly one check-out; swipe to check out; admin PIN gate, brand colour, dark mode and language applied immediately and persisted; submit failures (500 → Retry, timeout → duplicate warning, then success); tablet two-pane; every tab at 200% font in en/hi/gu on phone and tablet widths.
- `flow_test.dart` — draft restore from storage, write-through while typing, submit blocked without consent/with bad mobile.
- `live_api_test.dart` — real repositories against the running mock API (hosts, purposes, paging without duplicates, status
  filter, check-in with photo → check-out → 409 handled, 422 field errors). Skipped unless `LIVE_API=1`:
  `node server.js` (mock-api folder from the brief) then `LIVE_API=1 flutter test test/live_api_test.dart`. Passed 5/5.
- `unit_test.dart` — every string key exists in all three languages with identical `{placeholders}`; mobile and name validators.

Caveat: the overflow tests use the test font, which is wider than nothing but not identical to real Devanagari/Gujarati glyph
metrics. Layouts use `Wrap`/`Expanded`/scrollable parents rather than fixed heights so they do not depend on exact metrics, but
please also check on a real device (Settings → Display → Font size → largest).

## 5. Screenshots ✅ (web) / ⏳ (Android device)

`integration_test/full_flow_test.dart` drives the whole kiosk in real Chrome against the **live mock API** (300–1500 ms latency,
5 % random 500s, with auto-Retry like a guard would): app start → half-filled form survives a simulated process kill → host
directory load + debounced search → validation blocks bad mobile → purpose, consent → check-in → badge with QR + countdown →
idle timeout (default 20 s) returns home with the form cleared → Today's visitors, undo, check-out lapse, pull-to-refresh and
paging → admin PIN (wrong, then 1234), brand colour, dark mode, Gujarati, back to English.

It passes at three window sizes; screenshots of every step are in `evidence/`:

| Size | Layout detected | Folder |
|---|---|---|
| 390×844 | single pane (phone) | `evidence/flow-390x844/` |
| 1280×800 | two panes (tablet landscape) | `evidence/flow-1280x800/` |
| 1440×900 | two panes, max-width (web) | `evidence/flow-1440x900/` |

Run: `node server.js` (mock API), start chromedriver on 4444, then
`flutter drive --driver=test_driver/integration_test.dart --target=integration_test/full_flow_test.dart -d web-server --browser-name=chrome --browser-dimension=390,844`.
These are **debug-mode web builds** (the DEBUG ribbon is hidden by `debugShowCheckedModeBanner: false`, but it is still a
debug build): they prove behaviour, not performance. `scripts/e2e-web.ps1` / `.sh` wraps all of the above in one command.

**Not verified on a real Android device or emulator.** The emulator on the build machine cannot start (no hypervisor driver; needs
Windows Hypervisor Platform and a reboot) and no phone was attached. The same test file runs on a device with
`flutter test integration_test/full_flow_test.dart -d <device>`; camera capture and `retrieveLostData()` stay untested until then.

## 6. Assumptions and what I deliberately did not build

**Assumptions**
- **Photo is optional.** The API treats it as optional and a kiosk shouldn't block a visitor on a broken camera.
- **Two-pane breakpoint is 840 dp width**, not "is a tablet". A phone in landscape stays single-pane.
- **Undo is client-side and two-phase.** Swiping (or tapping the check-out button) hides the row; a 5-second Undo snackbar shows;
  only when it closes is `POST /checkout` sent. Undo therefore never needs a server call. Trade-off: if the app is killed inside
  that 5 s window the check-out is not sent (the visitor is still `checked_in` on the server, which is the safe direction).
  If the POST fails the row is restored and an error shown. A `409 already_checked_out` is treated as success.
- **A timed-out check-in POST is shown as "may already be checked in — check Today's visitors"**, since the API has no
  idempotency key and a timeout may have created the visitor. A 500 means nothing was created, so plain Retry is safe.
  There is no automatic retry on POSTs for the same reason.
- Host search is client-side over the 500 hosts (fetched once), debounced 300 ms.
- Check-in photos are resized to ≤800 px / quality 75 by the picker, and rejected locally if the data URL would exceed ~2.8 MB.
- Admin PIN is a constant (`1234`) per the brief; no PIN change screen. The admin area re-locks when you leave it or reload.
- Badge QR encodes the `badgeCode` (e.g. `NBV-4K9Q2X`).

**Not built, and why**
- Brand colour is a palette of 8, not a free colour picker — fewer dependencies, easier to keep accessible contrast.
- No on-device (Android) integration run — no working emulator or phone was available; the web integration run is in section 5.
- No Android emulator verification of the camera / `retrieveLostData()` recovery path. It is implemented but **untested**.
- No iOS/desktop targets — not requested.
- Hindi/Gujarati strings are my own translations and should be reviewed by a native speaker.
- Web: Hindi/Gujarati glyphs come from the browser's fallback font download under CanvasKit; no bundled font. Offline first load would show boxes.

## 7. What I used AI for

Claude Code (Opus/Sonnet) wrote the first draft of this codebase and the three documents from the brief. I (the human) am
responsible for being able to explain every line in the technical round; the items above marked ⏳/untested are the places I
need to verify myself before submitting.
