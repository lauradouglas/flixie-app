import 'package:flutter/material.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';

/// Permission is offered where notifications have a clear purpose, never during signup.
class NotificationOptIn extends StatefulWidget {
  const NotificationOptIn(
      {super.key,
      this.message = 'Get watch-plan reminders and updates from your friends.',
      this.check = PushNotificationService.needsPermissionChoice,
      this.enable = PushNotificationService.enableNotifications});
  final String message;
  final Future<bool> Function() check;
  final Future<bool> Function() enable;
  @override
  State<NotificationOptIn> createState() => _NotificationOptInState();
}

class _NotificationOptInState extends State<NotificationOptIn> {
  bool _visible = false, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.check().then((needed) {
      if (mounted) setState(() => _visible = needed);
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => !_visible
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_error ?? widget.message),
            Wrap(spacing: 12, children: [
              TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            final allowed = await widget.enable();
                            if (mounted) {
                              setState(() {
                                _visible = !allowed;
                                _error = allowed
                                    ? null
                                    : 'Notifications are off. You can enable them in your phone settings.';
                              });
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(() => _error =
                                  'Couldn’t enable notifications. Try again.');
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: Text(_busy ? 'Enabling…' : 'Enable notifications')),
              TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _visible = false),
                  child: const Text('Not now')),
            ]),
          ]));
}
