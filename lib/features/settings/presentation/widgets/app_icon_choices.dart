import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/app_icon/app_icon_service.dart';

class AppIconChoices extends StatefulWidget {
  const AppIconChoices({super.key});
  @override
  State<AppIconChoices> createState() => _AppIconChoicesState();
}

class _AppIconChoicesState extends State<AppIconChoices> {
  String? _selected;
  bool _supported = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await AppIconService.instance.status();
      if (mounted) {
        setState(() {
          _supported = status['supported'] == true;
          _selected = status['selected'] as String?;
        });
      }
    } catch (_) {
      // Web and older native builds have no launcher-icon channel.
    }
  }

  Future<void> _select(String icon) async {
    setState(() => _busy = true);
    try {
      final service = AppIconService.instance;
      service.updateUser(context.read<AuthProvider>().dbUser);
      await service.select(icon);
      if (mounted) setState(() => _selected = icon);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn’t change the app icon. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().dbUser;
    if (!_supported || !AppIconService.eligible(user)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text('App icon', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('A little thank-you for our First 100 and Founder members.'),
        const SizedBox(height: 12),
        for (final choice in [
          ('default', 'Flixie', 'assets/icon/flixie_icon_1024.png'),
          ('pipGlasses', 'Pip in 3D', 'assets/icon/pip_glasses.png'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(choice.$3, width: 48, height: 48),
            ),
            title: Text(choice.$2),
            selected: _selected == choice.$1,
            trailing: Icon(_selected == choice.$1
                ? Icons.radio_button_checked
                : Icons.radio_button_off),
            onTap: _busy ? null : () => _select(choice.$1),
          ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}
