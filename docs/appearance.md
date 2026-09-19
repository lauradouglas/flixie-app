# Appearance

Settings → Appearance offers System, Light and Dark. The preference is saved on this device before the UI changes, loaded before the first app frame, and independent of authentication/network requests. The existing dark appearance remains the default until the user chooses a mode. System mode tracks platform brightness changes live.

Light mode uses the approved lavender background (`#F3EDFC`), white surfaces, dark plum text and purple controls. `AppTheme.lightTheme` copies the existing dark component geometry, changing colours only. Layouts, content, routes, typography sizes, button padding and sheet shapes are preserved.

Use `context.colors` from `app_theme.dart` for semantic screen colours. It derives brightness from the local Flutter theme, so routes, sheets and already-mounted widgets react to a mode change without global mutable palette state. Brand colours, poster artwork, provider logos and users' avatar badge borders retain their identities. White text/icons over intentionally dark artwork overlays remain white. Static genre pills keep the shared six-colour light/dark palette.

`FlixieColors` remains the immutable dark/brand token source. Avoid using its dark surface/text tokens directly in new widgets. For semantic colours carried in view models, resolve them through `context.colors.adapt`. Theme-neutral export artwork and fixed dark overlays may intentionally use fixed colours.

Verification includes saved preference reloads, live system-mode changes, component geometry parity, semantic contrast, real watchlist filtering at 320/430/834/844 widths with 1× and 2× text scaling, and the existing regression suite. Run `LIGHT_CAPTURE=1 flutter test test/appearance_test.dart` to capture light watchlist previews in `/tmp`.
