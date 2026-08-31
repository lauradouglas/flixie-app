import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

/// Flixie's shared schedule-time picker. Kept as a sheet to avoid falling
/// back to the platform clock dialog in any Watch Plan flow.
class FlixieTimePickerSheet extends StatefulWidget {
  const FlixieTimePickerSheet({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<FlixieTimePickerSheet> createState() => _FlixieTimePickerSheetState();
}

class _FlixieTimePickerSheetState extends State<FlixieTimePickerSheet> {
  late TimeOfDay _selected = widget.initialTime;

  @override
  Widget build(BuildContext context) {
    final initialDateTime = DateTime(
      2020,
      1,
      1,
      _selected.hour,
      _selected.minute,
    );
    return SafeArea(
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a time',
                  style: TextStyle(
                    color: FlixieColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 170,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    primaryColor: FlixieColors.primary,
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (value) =>
                        _selected = TimeOfDay.fromDateTime(value),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text('Use this time'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
