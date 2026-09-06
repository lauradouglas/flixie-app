import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class GroupWatchPlanScheduleSheet extends StatefulWidget {
  const GroupWatchPlanScheduleSheet({
    super.key,
    this.initial,
    this.initialLocation,
  });

  final DateTime? initial;
  final String? initialLocation;

  @override
  State<GroupWatchPlanScheduleSheet> createState() =>
      _GroupWatchPlanScheduleSheetState();
}

class _GroupWatchPlanScheduleSheetState
    extends State<GroupWatchPlanScheduleSheet> {
  late DateTime _selected;
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? DateTime.now().add(const Duration(hours: 2));
    _locationController.text = widget.initialLocation?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule watch',
                style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickScheduleChip(
                    label: 'Tonight',
                    onTap: () => setState(() => _selected = _tonight()),
                  ),
                  _QuickScheduleChip(
                    label: 'Tomorrow',
                    onTap: () => setState(() => _selected = _tomorrow()),
                  ),
                  _QuickScheduleChip(
                    label: 'This weekend',
                    onTap: () => setState(() => _selected = _thisWeekend()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined,
                    color: FlixieColors.primary),
                title: const Text('Date',
                    style: TextStyle(color: FlixieColors.light)),
                subtitle: Text(
                  '${_selected.day} ${_months[_selected.month - 1]} ${_selected.year}',
                  style: const TextStyle(color: FlixieColors.medium),
                ),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded,
                    color: FlixieColors.primary),
                title: const Text('Time',
                    style: TextStyle(color: FlixieColors.light)),
                subtitle: Text(
                  TimeOfDay.fromDateTime(_selected).format(context),
                  style: const TextStyle(color: FlixieColors.medium),
                ),
                onTap: _pickTime,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                style: const TextStyle(color: FlixieColors.light),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined),
                  labelText: 'Location (optional)',
                  hintText: 'e.g. My place or local cinema',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmSchedule,
                  child: const Text('Confirm schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _confirmSchedule() {
    if (!_selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a date and time in the future.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      (
        scheduledFor: _selected,
        location: _locationController.text.trim(),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupScheduleDatePickerSheet(initialDate: _selected),
    );
    if (picked == null) return;
    setState(() {
      _selected = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selected.hour,
        _selected.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupScheduleTimePickerSheet(
        initialTime: TimeOfDay.fromDateTime(_selected),
      ),
    );
    if (picked == null) return;
    setState(() {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  DateTime _tonight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 20);
  }

  DateTime _tomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30);
  }

  DateTime _thisWeekend() {
    final now = DateTime.now();
    final daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
    final saturday =
        now.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
    return DateTime(saturday.year, saturday.month, saturday.day, 20);
  }
}

class _GroupScheduleTimePickerSheet extends StatefulWidget {
  const _GroupScheduleTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_GroupScheduleTimePickerSheet> createState() =>
      _GroupScheduleTimePickerSheetState();
}

class _GroupScheduleTimePickerSheetState
    extends State<_GroupScheduleTimePickerSheet> {
  late TimeOfDay _selected = widget.initialTime;

  @override
  Widget build(BuildContext context) {
    final initial = DateTime(2020, 1, 1, _selected.hour, _selected.minute);
    return SafeArea(
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
              child: Text('Choose a time',
                  style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
            SizedBox(
              height: 170,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  primaryColor: FlixieColors.primary,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initial,
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
          ]),
        ),
      ),
    );
  }
}

class _GroupScheduleDatePickerSheet extends StatefulWidget {
  const _GroupScheduleDatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_GroupScheduleDatePickerSheet> createState() =>
      _GroupScheduleDatePickerSheetState();
}

class _GroupScheduleDatePickerSheetState
    extends State<_GroupScheduleDatePickerSheet> {
  late DateTime _selected = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
    widget.initialDate.day,
  );

  @override
  Widget build(BuildContext context) {
    final firstDate = DateTime.now();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .74,
        child: Material(
          color: FlixieColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(children: [
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
                child: Text('Choose a date',
                    style: TextStyle(
                        color: FlixieColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CalendarDatePicker(
                  initialDate:
                      _selected.isBefore(firstDate) ? firstDate : _selected,
                  firstDate: firstDate,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (date) => setState(() => _selected = date),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text('Use this date'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _QuickScheduleChip extends StatelessWidget {
  const _QuickScheduleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      labelStyle: const TextStyle(color: FlixieColors.light),
      side: BorderSide(color: FlixieColors.primary.withValues(alpha: 0.3)),
    );
  }
}
