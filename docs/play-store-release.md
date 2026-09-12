# Google Play release

`scripts/play-store-release.sh` builds a signed production AAB and uploads a draft to internal testing, then promotes that version to a production draft. It does not roll out a public release.

Prerequisites:
- Flutter, Android SDK and Fastlane installed.
- Existing `android/key.properties`, upload keystore, `.firebase.json` and `android/app/google-services.json` configured locally.
- Google Play Android Developer API enabled in Google Cloud.
- A service account granted Flixie app access in Play Console, including testing and production release permissions. Store its JSON key outside this repository.

```bash
BUILD_NUMBER=59 \
bash scripts/play-store-release.sh
```

Choose a build number greater than all versions already uploaded to Play Console. `PLAY_STORE_TRACK` defaults to `both`; set it to `internal` or `production` to create only that draft. If internal upload succeeds but production promotion fails, promote the existing internal build in Play Console rather than uploading the same version again.

Fastlane is installed locally. The credential path is saved in Git-ignored `.play-store.env`; the private key stays outside the repository. On another machine, create that local file with `PLAY_STORE_KEY_FILE=/absolute/path/to/key.json`.

Build 58 was uploaded successfully to internal testing and promoted to a production draft on 12 September 2026. The script syntax and command sequence were also tested with mocked commands.

Google setup: https://developers.google.com/android-publisher/getting_started
Fastlane upload: https://docs.fastlane.tools/actions/supply/
