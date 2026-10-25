# Evidence

## Full-flow screenshots (automated, real Chrome, live mock API)

Produced by `scripts/e2e-web.ps1` / `.sh` (test: `integration_test/full_flow_test.dart`). 12 steps per size:
`01-home` · `02-hosts` · `03-host-search` · `04-validation` · `05-form-filled` · `06-badge` · `07-after-idle` ·
`08-visitors` · `09-undo-snackbar` · `10-visitors-scrolled` · `11-admin-dark` · `12-admin-gujarati`

| Folder | Window | Layout |
|---|---|---|
| `flow-390x844/` | 390×844 | single pane (phone portrait) |
| `flow-1280x800/` | 1280×800 | directory + form side by side (tablet landscape) |
| `flow-1440x900/` | 1440×900 | two panes with a sensible max width (web) |

These are debug-mode web builds: they show behaviour and layout, not performance.

## On a real Android phone

- `device-full-flow.txt` — the same automated full flow passing on a **Redmi Note 13 Pro+ 5G, Android 16** (live API over
  `adb reverse`). Android runs do not produce screenshots (the driver hook is web-only).
- `perf/visitors_scroll.timeline_summary.json` — **profile-mode** frame timings while scrolling Today's visitors on that phone
  (command: `flutter drive --profile --no-dds -d <device> --driver=test_driver/perf_driver.dart --target=integration_test/scroll_perf_test.dart --dart-define=API_BASE_URL=http://localhost:4000`, after `adb reverse tcp:4000 tcp:4000`).
  Interpreted in SUBMISSION.md §3. The 9 MB raw trace is git-ignored; open it in <https://ui.perfetto.dev> after re-running.

## Earlier manual web captures

`web-1280-*.png`, `web-390-*.png`, `web-test-log.txt`, `web-semantics-*.txt` — taken earlier while building the web version
(1280 px and 390 px wide, including Gujarati + dark mode and the restore-after-reload case).

## Still to add

- A DevTools **frame-chart screenshot** (the brief asks for one): `scripts/run-android -Mode profile`, then DevTools → Performance
  while flinging the visitors list. The numeric profile-mode summary above is already measured.
- A camera-photo capture on a device.

Golden images for the badge screen are in `test/goldens/`.
