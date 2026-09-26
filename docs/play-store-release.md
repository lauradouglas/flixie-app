# Google Play release

See [Fastlane deployment setup](fastlane.md) for prerequisites, credentials and
all iOS/Android lanes. Install the pinned dependencies with `bundle install`.

The existing entry point remains supported:

```bash
BUILD_NUMBER=123 bash scripts/play-store-release.sh
```

Replace 123 with a version code above every version already uploaded to Play.
The script loads the Git-ignored `.play-store.env` and defaults to creating both
internal and production drafts. Set `PLAY_STORE_TRACK=internal` or `production`
to upload only one draft. Direct Fastlane lanes default to internal only.

If internal upload succeeds but production promotion fails, retry without
rebuilding or re-uploading:

```bash
bundle exec fastlane android promote build_number:123
```

Direct lanes read credentials from `fastlane/.env` or exported environment
variables, so configure `PLAY_STORE_KEY_FILE` there when using this retry.
Drafts require review and rollout in Play Console before distribution.
