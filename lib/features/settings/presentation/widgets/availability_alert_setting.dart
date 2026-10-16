import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/settings/data/availability_alert_service.dart';
import 'package:flixie_app/core/widgets/notification_opt_in.dart';

class AvailabilityAlertSetting extends StatefulWidget {
  const AvailabilityAlertSetting(
      {super.key,
      required this.userId,
      this.isCurrentUser,
      this.load,
      this.save,
      this.showPushChoice = true});
  final String userId;
  final bool Function()? isCurrentUser;
  final Future<AvailabilityAlertSettings> Function()? load;
  final Future<AvailabilityAlertSettings> Function(bool)? save;
  final bool showPushChoice;
  @override
  State<AvailabilityAlertSetting> createState() =>
      _AvailabilityAlertSettingState();
}

class _AvailabilityAlertSettingState extends State<AvailabilityAlertSetting> {
  AvailabilityAlertSettings? _settings;
  bool _busy = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AvailabilityAlertSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _generation++;
      _settings = null;
      _load();
    }
  }

  bool _current(int generation) =>
      mounted &&
      generation == _generation &&
      (widget.isCurrentUser?.call() ?? true);

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings =
          await (widget.load ?? const AvailabilityAlertService().load)();
      if (_current(generation)) setState(() => _settings = settings);
    } catch (_) {
      if (_current(generation)) {
        setState(
            () => _error = 'Couldn’t load availability alerts. Try again.');
      }
    } finally {
      if (_current(generation)) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool enabled) async {
    if (_busy || !(widget.isCurrentUser?.call() ?? true)) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings =
          await (widget.save ?? const AvailabilityAlertService().save)(enabled);
      if (_current(generation)) setState(() => _settings = settings);
    } catch (_) {
      if (_current(generation)) {
        setState(() => _error =
            'Alerts weren’t changed. Check your country and Watch Providers, then try again.');
      }
    } finally {
      if (_current(generation)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Now on your services'),
            subtitle: Text(_settings == null
                ? 'Watchlist availability alerts'
                : 'Films and shows on your watchlist · ${_settings!.countryName ?? 'Choose your country'}'),
            value: _settings?.enabled ?? false,
            onChanged: _busy ||
                    _settings == null ||
                    (!_settings!.ready && !_settings!.enabled)
                ? null
                : _save,
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
              'Get an update when a saved title is newly listed with one of your subscriptions. Checked daily; rentals and purchases aren’t included.',
              style: TextStyle(color: context.colors.light, height: 1.45)),
          if (_settings != null) ...[
            const SizedBox(height: 8),
            Text(
                _settings!.ready
                    ? 'Your services: ${_settings!.services.join(', ')}.'
                    : 'Choose your country in Account details and your services in Watch Providers first.',
                style: TextStyle(color: context.colors.light, height: 1.45)),
          ],
          if (_settings != null && !_settings!.ready)
            TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Refresh country & services')),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: context.colors.danger)),
            if (_settings == null)
              TextButton(
                  onPressed: _busy ? null : _load, child: const Text('Retry')),
          ],
          if (_settings?.enabled == true && widget.showPushChoice)
            const NotificationOptIn(
                message:
                    'Alerts will appear in your Flixie inbox. Enable phone notifications to receive them outside the app too.'),
        ]),
      );
}
