import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'settings_tile.dart';

class AppearanceSetting extends StatelessWidget {
  const AppearanceSetting({super.key});

  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    return SettingsTile(
      icon: Icons.palette_outlined,
      label: 'Appearance',
      trailing: Text(label(appearance.mode)),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
        builder: (sheetContext) => AnimatedBuilder(
          animation: appearance,
          builder: (context, _) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    for (final mode in [
                      ThemeMode.system,
                      ThemeMode.light,
                      ThemeMode.dark
                    ])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(label(mode)),
                        subtitle: mode == ThemeMode.system
                            ? const Text('Follow your device setting')
                            : null,
                        leading: Icon(switch (mode) {
                          ThemeMode.system => Icons.brightness_auto_outlined,
                          ThemeMode.light => Icons.light_mode_outlined,
                          ThemeMode.dark => Icons.dark_mode_outlined
                        }),
                        trailing: Icon(appearance.mode == mode
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off),
                        selected: appearance.mode == mode,
                        onTap: () async {
                          try {
                            await appearance.setMode(mode);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          } catch (_) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Couldn’t save appearance. Please try again.')));
                            }
                          }
                        },
                      ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
