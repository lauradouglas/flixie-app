# Launch campaign capture

The launch video uses production Flutter screens driven by Patrol, with isolated
fictional users and mocked API writes. Movie reviews are sample movie opinions,
not testimonials about Flixie. The edit labels the demo content.

Run from the app repository on macOS with Xcode and the pinned Patrol runner.
`capture-launch-video.py` selects the dedicated screenshot iPhone simulator from
`fastlane/ScreenshotConfig.json`; Patrol reinstalls the app on that device.
Do not run another screenshot/Patrol capture concurrently.

```sh
python3 scripts/capture-launch-video.py
cp build/launch-campaign/patrol.log build/launch-campaign/patrol-main.log
FLIXIE_VIDEO_SCENES='06-interstellar|07-the-newsroom|09-reviews' \
FLIXIE_VIDEO_TEST=patrol_test/launch_video_details_test.dart \
python3 scripts/capture-launch-video.py
```

The host starts native simulator recording after each screen and its artwork have
loaded. The TV scene taps **Mark watched** and checks the mocked write and success
message. Source `.mov` clips and screenshots are in `build/launch-campaign/`.

Install Pillow and imageio-ffmpeg in an isolated Python environment, then run:

```sh
python scripts/render-launch-video.py
```

The output is `build/launch-campaign/flixie-launch.mp4`: 1080 × 1920, 30 fps,
H.264/AAC, approximately 33 seconds. It uses an original synthesized instrumental
bed and the website CTA. Run `python scripts/check-launch-video.py` to decode-check the file and generate
a contact sheet. Inspect representative frames and the complete action before publishing; this workflow does not publish anything.

## Delivered on 3 October 2026

The final MP4 is 33.00 seconds at 1080 × 1920 / 30 fps with AAC audio. The
final capture pass and focused `test/launch_video_fixture_test.dart` passed;
Dart analysis found no issues. The MP4 decoded without errors and its contact
sheet was inspected. Earlier review captures exposed a missing `/safety/blocks`
fixture response, now included in the isolated launch fixture.

## Second edit

`flixie-launch-v2.mp4` replaces the low sustained soundtrack with brighter major-key
plucks and a soft rhythm. The end card uses official App Store and Google Play
badges instead of the corporate website. `flixie-launch-v2-silent.mp4` is the same
edit without audio for adding music in a social editor. Run the render script
with `--reuse-scenes` when only changing the end card or soundtrack.

## Selected soundtrack and attribution

`build/launch-campaign/flixie-launch-all-that.mp4` uses the user-supplied
All That track by Benjamin Tissot, with an end-card credit and a fade-out.
The exact user-supplied download attribution is saved in
`build/launch-campaign/all-that-attribution.txt` and included in
`build/launch-campaign/launch-post-caption.txt`. Include it in the published
video description; the on-screen credit is supplementary. Attribution code
PTEAQDZQGELFV4R5 is associated with this video, not a blanket licence for new edits.
