# External movie and show links

Website app-first fix published on 12 October 2026; client available in TestFlight 2.0.2 (104).

Movie/Show Detail Share offers friend, group and external destinations for members.
Guests open native sharing directly. External sharing includes the title plus a
public HTTPS link:

- `https://www.flixie.co.uk/movies/348?source=shared_link`
- `https://www.flixie.co.uk/shows/1399?source=shared_link`

Internal chat share payloads keep their existing custom-scheme links. The shared
web link carries no account identifiers or private activity.

The existing website source is at
`/Users/lauradouglas/Development/FLIXIE/flixie-corp/flixie`.
Its Apple association maps `/movies/*` and `/shows/*` to the existing app identity.
Android manifest verified-link filters include these paths and retain the existing
website assetlinks identity and signing fingerprint. No new database/API is required.

## Download fallback

Azure routes these title paths to the shared-title page. A valid positive bounded
ID creates the Open in Flixie action (`flixie:///movies/:id` or `/shows/:id`). The
page uses generic movie/show copy rather than claiming a fetched title/poster preview.
There is no timed store redirect and no installed-app detection guess. iPhone/iPad
Open uses the registered custom scheme; App Store remains an explicit download choice.
Safari Smart App Banner metadata identifies Flixie. Android Open uses a package-scoped
custom-scheme intent with a browser-handled Google Play fallback. Other browsers keep
the registered scheme and both store buttons. The explicit opening action retains the
exact movie/show ID. The banner has the app ID without a per-title server argument.

OS universal/app links should open installed apps first. Embedded-browser restrictions,
user preferences and device association caches can still keep the visitor on the web.
After installation the recipient taps the original shared link again; no deferred-install
service or automatic restoration of title intent is claimed.

## Release and verification

Publish the website and association files, verify HTTPS association responses without
redirects, check the existing Android fingerprint against Google Play signing, then
ship an updated app. Android receivers need the new manifest paths; senders need the
new external share choice. Do not treat Flutter hot reload as an Android manifest
update or local web build as publication. Verify actual link handling on installed
and uninstalled iOS/Android devices from Messages and an embedded browser. Include
signed-out catalogue browsing, cold/warm app launches and cancellation on the web.

Local fixtures are existing fictional sharing friends/groups and movie/show entries;
no real accounts or messages are needed. The shared action tests intercept the native
share method and verify the exact HTTPS payload rather than sending messages.

## Published correction evidence

Website commit `c711c423bfc6b62f4ad3f48404f5b71e1eaa7f2f`, Azure run 38300940216.
Live movie/show pages return 200 and app-first copy; compiled browser code has no store
timeout. Origin/Apple CDN association responses are application/json with existing
invite/movie/show paths and no redirect. Website build, TypeScript, SEO/HTTP and link
checks pass. The redirect regression is included in `npm run check:seo` in CI.
Real-phone installed/uninstalled checks remain pending user/device verification.

## Cold-start title retention — 12 October 2026

Build 105 user testing exposed a lost title during restored-member startup.
Router now stores matched HTTPS destinations as internal path/query and retains
supported public title intent even with a cached complete profile during unknown
auth. Eight production-router startup regressions cover movie/show, HTTPS/relative
paths and cached/uncached profiles. Startup/sign-out/setup checks total 21 passes;
analysis clean. Signed iPhone 17 Pro simulator cold-launch checks render Alien and
Game of Thrones from the intended links. Fix is now deployed in TestFlight 2.0.2 (106); physical Messages/WhatsApp
retesting can proceed after updating from build 105.
