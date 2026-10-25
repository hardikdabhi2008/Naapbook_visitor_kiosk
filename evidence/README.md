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

## Earlier manual web captures

`web-1280-*.png`, `web-390-*.png`, `web-test-log.txt`, `web-semantics-*.txt` — taken earlier while building the web version
(1280 px and 390 px wide, including Gujarati + dark mode and the restore-after-reload case).

## Still to add from a real Android device

Not available where this was built (no hypervisor for the emulator, no phone attached):

- `visitors-scroll-profile.png` — DevTools frame chart for the visitors list, **profile mode**, device name written in
  `SUBMISSION.md` (`scripts/run-android.ps1 -Mode profile`)
- an on-device run of the full flow (`scripts/run-android.ps1 -Mode test`) and a camera-photo capture

Golden images for the badge screen are in `test/goldens/`.
