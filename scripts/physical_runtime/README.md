# Physical iPhone runtime capture

This is an isolated fixture build, not the distributed production app. It uses
real native Firebase Auth against the demo emulator and the populated local
`flixie_runtime_fixture` PostgreSQL API. No real accounts or messages.

1. Start the existing API/Auth/Firestore services described in `docs/testing.md`.
2. Run `python3 scripts/physical_runtime/prepare.py --team <development-team>`.
   It copies current sources under `/private/tmp/flixie-physical-*`, configures
   `com.flixie.flixieBenchmark`, removes app-group/associated-domain/push
   entitlements, disables APNs and analytics, and changes the widget group name.
   It preserves the original checkout and installed Flixie application.
The copied release configuration removes the production entrypoint/API pins and
uses a benchmark-only signing guard; the original release guard is unchanged.

3. Discover the connected device with `xcrun devicectl list devices` and inspect
   its private tunnel using `devicectl device info details` and `ifconfig`.
   Prefer stable shared Wi-Fi: find the Mac address with `ipconfig getifaddr en0`
   and the phone address in its Wi-Fi network details. Run
   `bridge.py --bind <Mac-private-address> --peer <phone-private-address>`.
   RFC1918 Wi-Fi IPv4 and paired ULA IPv6 addresses are accepted. It forwards
   only ports 3007, 9099 and 8185, only for that peer, after verifying the manifest.
4. In the copied workspace, run Patrol with `--release --no-uninstall`, the
   benchmark bundle ID, the approved physical device, and
   `-t patrol_test/runtime_lifecycle_baseline_test.dart`. Set `API_BASE_URL` to
   `http://<Mac-IPv4-address>:3007` (or `http://[<Mac-fd-address>]:3007` for USB),
   `RUNTIME_FIXTURE_HOST` to the bare address and
   a fresh `RUNTIME_CAPTURE_ID`. Shell-quote the IPv6 URL. Installed Patrol 4.8.0
   rejects profile mode on physical iOS. If new signing profiles are needed,
   run its logged `xcodebuild build-for-testing` command with the specific device
   and `-allowProvisioningUpdates`; do not change production project signing.
5. Summarize with `summarize_lifecycle.py --capture-id <same-id> --output <folder>`.
   It rejects incomplete, stale, non-release and transport-failed captures.
6. Build the same isolated app in release mode with `-t tool/runtime_startup.dart`
   and the same endpoint defines, then install only its separate bundle. Run
   `capture_startup.py --device <device> --output <fresh-folder>` for 15 actual
   fresh-process samples. Each launch uses `devicectl --terminate-existing`.
7. Stop the bridge after capture. Keep raw logs, source hashes, fixture manifest,
   OS/device/build mode and limitations beside the summary. Never relabel debug
   simulator results as physical-device results.

The physical app must stay unlocked and available to automation. Local network or
trust prompts must be resolved before timed runs. First-run compilation, install,
signing and fixture preparation are outside measurements. Lifecycle root startup
is not OS process startup. Host startup timing includes devicectl and result polling;
Dart startup timing excludes native bootstrap. APNs/App Check/external analytics and
production-service latency are excluded. Five observations per condition make p95
the maximum observation, not a stable tail-latency estimate.

## Connection failure found during physical setup

On 9 October, the paired USB tunnel changed its IPv6 prefix twice between builds
and capture. A release binary with the previous address remains on the splash
while waiting for the fixture server. An installed app or successful launch is
therefore not evidence of a valid benchmark. Recheck both tunnel endpoints after
installation and before capture; do not reuse an old bridge or compiled endpoint.
The initial Patrol attempt also exited successfully with zero discovered tests;
that result is invalid. Only complete, matching capture IDs count as measurements.
A stable device-to-fixture connection remains required before recording baselines.

## Home watch-plan timing trace

Add `--dart-define=HOME_TIMING_TRACE=true` to the isolated release build above.
Capture with `capture_startup.py --device <device> --output <fresh-folder>
--home-trace`, then run `summarize_home_trace.py <folder>/results.json --output
<folder>/home-summary.json`. This mode prepares the populated 20-title fixture
account and captures five fresh processes. The fixture itself has 24 direct and
12 group plans, plus the larger shared catalogue and fictional social data.

The first plan post-frame marker is stored independently of capture completion.
Capture waits for both plan sources and requires successful responses containing
server timing. It records profile loading, Home mounting, parallel plan requests,
visibility preferences, JSON decode and first plan frame. The frame marker does
not prove poster downloads or GPU raster completion. Server `data` is repository
and service wall time, including database work; it is not summed SQL time.
Client transport includes network and scheduling; subtracting server time does
not isolate pure network latency. Parallel durations must not be summed.

Home trace mode changes the capture completion boundary. Its generic
`dart_entry_to_content_us` must not be compared with older startup captures;
use the dedicated first-frame timestamps in `home-summary.json`. These are
current local baselines, not a before/after or production performance result.
