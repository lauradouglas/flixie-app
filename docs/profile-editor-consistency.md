# Profile editor consistency and recovery

Implemented 25 October 2026 following user approval.

- Shared editor actions: Close in the header, Save/Create then Cancel in the footer.
- Dirty drafts prompt Keep editing / Discard changes. Drag and barrier dismissal are disabled so they cannot bypass the guard; system Back uses the same guard.
- Required name/username and sharing-target validation appears beside the relevant control. Saving disables repeat submission and edits.
- Failed saves retain the draft and reveal a local Retry. Profile partial successes update their saved baselines, so Retry writes only remaining fields. Cache updates preserve unrelated user data and stop after account changes.
- Avatar failures retain the selection and catalogue. Successful changes offer Undo, guarded against later avatar changes or account switches. Avatar previews retain the user's earned border.
- List removal waits four seconds before writing and provides Undo during that window. A failed removal keeps the title and provides Retry. This avoids restoring someone else's title with new attribution.
- Lists clearly describe films and shows. Diary/calendar and badge icons are unchanged.

Draft retention applies while the editor is open, not after process termination. Already successful fields remain saved if a later field fails; the discard prompt explains this.

Validation: focused widget tests cover draft keep/discard, partial save recovery, duplicate saves, avatar retry/Undo, list removal Undo, account changes, and responsive layouts including enlarged text and keyboard insets. Dedicated simulator coverage is in `patrol_test/profile_editor_safety_test.dart`. Existing fictional local Casey data is reusable; all automated fixtures remain isolated from real accounts.

Results: 36 focused widget tests passed, followed by 13 editor/Settings checks after the final error-visibility adjustment; six native Patrol journeys passed on Flixie Profile Patrol. The first native removal assertion ran before the Undo window had completed; it now waits for the visible removal confirmation and still verifies that only the film was removed. Focused static analysis reports no issues. Hot reload succeeded on Flixie Tour iPhone and the runtime error check was clear.
