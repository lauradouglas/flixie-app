import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/preference_switch.dart';
import 'package:flixie_app/features/settings/presentation/widgets/around_flixie_sharing_setting.dart';
import '../../controllers/onboarding_controller.dart';

/// Explicit choices next to streaming services; availability is applied after services save.
class OnboardingAccountChoices extends StatefulWidget {
  const OnboardingAccountChoices({super.key, required this.controller});
  final OnboardingController controller;
  @override
  State<OnboardingAccountChoices> createState() => _AccountChoicesState();
}

class _AccountChoicesState extends State<OnboardingAccountChoices> {
  bool? _enabled;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final settings = await widget.controller.service.availabilityAlerts();
      if (mounted && widget.controller.active) {
        setState(() => _enabled =
            widget.controller.availabilityAlertsChoice ?? settings.enabled);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t load watchlist alerts. Retry, or continue without changing them.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.controller;
    final ready = owner.country != null && owner.selectedProviders.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 24),
      Text('Your watchlist updates',
          style: Theme.of(context).textTheme.titleLarge),
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Watchlist availability alerts'),
          subtitle: Text(ready
              ? 'New subscription availability for saved films and shows. Checked daily; rentals and purchases are excluded.'
              : 'Choose your country and at least one service above to enable alerts.'),
          trailing: PreferenceSwitch(
              loading: _error == null,
              value: _enabled,
              onChanged:
                  owner.busy || (!ready && _enabled != true) || _enabled == null
                      ? null
                      : (value) {
                          setState(() => _enabled = value);
                          owner.chooseAvailabilityAlerts(value);
                        })),
      const Text(
          'Turn this on to get updates in Flixie. When you save, we’ll ask for phone notification permission too.'),
      if (_error != null) ...[
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('Retry alerts'))
      ],
      const SizedBox(height: 24),
      Text('Around Flixie', style: Theme.of(context).textTheme.titleLarge),
      AroundFlixieSharingSetting(
          key: ValueKey('provider-sharing-${owner.userId}'),
          contentPadding: EdgeInsets.zero,
          compact: true,
          enabled: !owner.busy,
          load: owner.service.sharing,
          save: owner.service.setSharing,
          onBusyChanged: owner.setBusy),
    ]);
  }
}
