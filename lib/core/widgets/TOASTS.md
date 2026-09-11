# Flixie toasts

Use `FlixieToast` with `ScaffoldMessenger.of(context).showFlixieToast(...)` for all transient bottom feedback. Do not create feature-specific SnackBars.

- `success`: an operation completed (saved, sent, added, removed).
- `info`: neutral state or guidance, including waiting for another person.
- `warning`: input, membership or limits require attention before proceeding.
- `error`: an operation failed.

Every variant uses the same opaque aubergine surface, white Manrope text, 14px corners and 1.5px outline. Only the icon and accent change. Floating positioning follows the Scaffold's navigation and keyboard insets. Actions use accessible text buttons and move below the message on narrow screens or with large text.

Pass a real `SnackBarAction` for Retry, Undo, Share or Manage. Do not put buttons or extra status icons inside the content. Retry must reuse retained input and respect in-flight guards. Undo must restore the previous value and must not overwrite a newer edit. Do not offer Undo for irreversible operations, or for first-time ratings until the API supports deleting a rating. Existing-rating edits can restore the previous rating and recommendation.

Actionable toasts remain until dismissed or acted on by default, so assistive-technology users have time to reach the action. Existing explicit nonpersistent calls retain an eight-second action window. Errors last six seconds by default; other messages last four. Avoid raw exception details in user-facing copy. Log technical details separately.

```dart
ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
  type: FlixieToastType.error,
  content: const Text('Couldn’t save your picks'),
  action: SnackBarAction(label: 'Retry', onPressed: retrySave),
));
```
