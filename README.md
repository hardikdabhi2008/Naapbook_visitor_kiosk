# Naapbooks Visitor Kiosk

Visitor check-in kiosk for the Naapbooks Flutter practical assessment. One Flutter codebase for an
**Android tablet/phone** and **Flutter web**. Riverpod 3 + go_router + dio, feature-first clean architecture.

| Document | What it is |
|---|---|
| [SUBMISSION.md](SUBMISSION.md) | How to run, state-management choice, evidence, what was cut, AI usage |
| [DIAGNOSTICS.md](DIAGNOSTICS.md) | Section B — six diagnostic answers |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Section C — one codebase, four apps (+ diagram) |
| [evidence/](evidence/README.md) | Screenshots of the full flow at phone, tablet and web sizes |

## 1. Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Flutter | 3.47+ (Dart 3.13+) | everything |
| Node.js | 18+ | the mock API (no `npm install` needed) and the web end-to-end script |
| Google Chrome | any recent | web run + web end-to-end test |
| Android Studio / SDK + JDK 17+ | — | Android builds only. If `JAVA_HOME` points at an old JDK (e.g. 8), set it to Android Studio's `jbr` |

## 2. Quick start (3 steps)

```bash
# 1. Start the mock API (unchanged copy of mock-api.zip, in ./mock-api). http://localhost:4000
node mock-api/server.js            # or: scripts/start-api.ps1  |  scripts/start-api.sh

# 2. Install packages
flutter pub get

# 3. Run the app in Chrome
flutter run -d chrome
```

- **Admin PIN: `1234`**.
- The API deliberately has 300–1500 ms latency and ~5% HTTP 500s — you will see loading/error/Retry states. For quick
  manual poking only: `scripts/start-api.ps1 -Fast` (or `./scripts/start-api.sh --fast`) removes both.
- Data lives in the API's memory; restart `node` to reset it.
- Best viewed at ≥ 840 px wide for the two-pane tablet layout; narrow the window below that for the phone layout.

## 3. Test everything

```bash
flutter analyze                    # static analysis — clean
flutter test                       # 43 unit/widget/golden tests (fake repositories, no API needed)
```

**Automated full flow in a real browser, against the real mock API** (phone 390×844, tablet 1280×800, web 1440×900):

```powershell
.\scripts\e2e-web.ps1              # Windows. Add -Sizes '1280,800' for one size, -Visible to watch it
```
```bash
./scripts/e2e-web.sh               # macOS / Linux (not verified on those OSes)
```

It downloads a matching ChromeDriver on first use, starts the API if it is not running, drives
[integration_test/full_flow_test.dart](integration_test/full_flow_test.dart), and writes step screenshots to
`evidence/flow-<W>x<H>/`. The flow covers: half-filled form survives an app restart → host directory + debounced
search → validation blocks bad input → check-in → badge with QR + countdown → idle returns home (form cleared) →
Today's visitors (undo, check-out, refresh, paging) → admin (PIN, colour, dark mode, Gujarati).

The same test also runs on a device (below). Optional live API contract tests:
`LIVE_API=1 flutter test test/live_api_test.dart` (API must be running).

## 4. Android (tablet, phone or emulator)

```powershell
.\scripts\run-android.ps1                # run on the attached device      (./scripts/run-android.sh on macOS/Linux)
.\scripts\run-android.ps1 -Mode test     # run the automated full flow ON the device
.\scripts\run-android.ps1 -Mode profile  # profile mode, for DevTools frame charts
```

The script runs `adb reverse tcp:4000 tcp:4000` so the device reaches the API on your computer over USB — no Wi-Fi or
IP setup. Manual equivalent:

```bash
adb reverse tcp:4000 tcp:4000
flutter run -d <device-id> --dart-define=API_BASE_URL=http://localhost:4000
```

Without `adb reverse`: the emulator already reaches the host at `10.0.2.2:4000` (the default on Android); a physical device
needs `--dart-define=API_BASE_URL=http://<your-LAN-IP>:4000`.

**Tablet emulator in Android Studio:** Device Manager → Create Device → *Pixel Tablet* (or any 10″ tablet) → Android 14+ x86_64
image → Finish → Run. Landscape gives the side-by-side layout. Emulators need hardware acceleration (WHPX/AEHD on Windows,
HAXM is no longer supported); a USB device avoids this.

## 5. Release builds

```bash
flutter build web --release        # -> build/web  (CanvasKit renderer, the 3.47 default)
flutter build apk --release        # -> build/app/outputs/flutter-apk/app-release.apk
```

Serving the web build on IIS (MIME types, compression, SPA rewrite): see DIAGNOSTICS.md B6. The release APK is signed with
the debug key (no keystore is committed) — fine for the assessment, not for the store.

## 6. Project map

```
lib/
  core/        config, network (dio), error model, l10n (en/hi/gu), theme, shared state widgets
  features/    hosts · checkin · badge · visitors · settings · home (responsive shell)
               each: domain/ (entities, repo interfaces)  data/ (DTOs, impls)  presentation/ (providers, screens)
test/                    unit, widget, overflow @200% font (en/hi/gu), whole-app flow, badge goldens
integration_test/        full_flow_test.dart — end-to-end against the live API
test_driver/             flutter drive hook that saves screenshots
mock-api/                the supplied mock API, unchanged
scripts/                 start-api · e2e-web · run-android  (.ps1 and .sh)
evidence/                screenshots
```

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| App shows "Can't reach the server" | API not running, or on Android without `adb reverse` / `API_BASE_URL` |
| Gradle: `UnknownHostException` / Kotlin errors on first Android build | Use JDK 17+ (Android Studio's `jbr`); first build downloads the NDK (~1 GB) |
| Kotlin "different roots" incremental-cache error | Already handled: `kotlin.incremental=false` in `android/gradle.properties` |
| Emulator: "hypervisor ... not supported" | Enable Windows Hypervisor Platform / install AEHD, or use a USB device |
| `e2e-web` can't find Chrome | Install Chrome; ChromeDriver is fetched automatically |
| `e2e-web` fails once on a step that waits for data | The mock API fails ~5% of calls on purpose and the test auto-taps Retry, but an unlucky streak or a slow machine can still time out. Re-run that size (`-Sizes '1280,800'`). In my runs every size passed, but one tablet run failed once on the host list and passed on the immediate rerun |
