import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class WatchPlanScheduleSheet extends StatefulWidget {
  const WatchPlanScheduleSheet({
    super.key,
    this.initial,
    this.initialLocation,
    this.showLocation = false,
  });

  final DateTime? initial;
  final String? initialLocation;
  final bool showLocation;

  @override
  State<WatchPlanScheduleSheet> createState() => _WatchPlanScheduleSheetState();
}

class _WatchPlanScheduleSheetState extends State<WatchPlanScheduleSheet> {
  late DateTime _selected;
  late _ScheduleEntryMode _mode;
  bool _leaveTimeUndecided = false;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial?.toLocal() ??
        DateTime.now().add(const Duration(hours: 2));
    _mode = _ScheduleEntryMode.dateAndTime;
    _locationController = TextEditingController(
      text: widget.initialLocation?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height * .88,
      child: Material(
        color: context.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: MediaQuery(
          // Keep the device text scale. The scrollable sheet and flexible
          // controls must make room for larger labels instead of suppressing
          // the user's accessibility preference.
          data: MediaQuery.of(context),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 54,
                      height: 6,
                      decoration: BoxDecoration(
                          color: context.colors.medium,
                          borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: Text('Date & time',
                        style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: context.colors.light, size: 28)),
              ]),
              const SizedBox(height: 8),
              Text(
                  'Set when this plan should happen. You can change it again later.',
                  style: TextStyle(color: context.colors.light, fontSize: 13)),
              const SizedBox(height: 24),
              _ScheduleModeSelector(
                  mode: _mode,
                  onChanged: (mode) => setState(() {
                        _mode = mode;
                        if (mode == _ScheduleEntryMode.dateOnly) {
                          _leaveTimeUndecided = true;
                        }
                      })),
              const SizedBox(height: 24),
              Text('Quick pick',
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                for (final quickPick in <({String label, DateTime value})>[
                  (label: 'Tonight', value: _tonight()),
                  (label: 'Tomorrow', value: _tomorrow()),
                  (label: 'Weekend', value: _thisWeekend()),
                ])
                  Expanded(
                      child: Padding(
                          padding: EdgeInsets.only(
                              right: quickPick.label == 'Weekend' ? 0 : 8),
                          child: _QuickScheduleButton(
                              label: quickPick.label,
                              onTap: () => setState(
                                  () => _selected = quickPick.value)))),
              ]),
              const SizedBox(height: 20),
              _ScheduleDetailCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'DATE',
                  value: MaterialLocalizations.of(context)
                      .formatFullDate(_selected),
                  onTap: _pickDate),
              if (_mode == _ScheduleEntryMode.dateAndTime) ...[
                const SizedBox(height: 10),
                _ScheduleDetailCard(
                    icon: Icons.access_time_rounded,
                    label: 'TIME',
                    value: TimeOfDay.fromDateTime(_selected).format(context),
                    onTap: _pickTime),
                const SizedBox(height: 10),
                Row(children: [
                  Switch(
                      value: _leaveTimeUndecided,
                      onChanged: (value) =>
                          setState(() => _leaveTimeUndecided = value)),
                  const SizedBox(width: 10),
                  Text('Leave the time undecided',
                      style:
                          TextStyle(color: context.colors.light, fontSize: 13)),
                ]),
              ],
              if (widget.showLocation) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _locationController,
                  style: TextStyle(color: context.colors.light),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                    labelText: 'Location (optional)',
                    hintText: 'e.g. My place or local cinema',
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(18)),
                  child: Text(
                      'Everyone in this plan will be notified that the schedule changed.',
                      style: TextStyle(
                          color: context.colors.light, fontSize: 11))),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save schedule',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)))),
            ]),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.warning,
          content: const Text('Choose a date and time in the future.'),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }
    Navigator.pop(context, (
      proposedFor: _selected,
      message: _leaveTimeUndecided || _mode == _ScheduleEntryMode.dateOnly
          ? 'Time to be decided'
          : null,
      location: widget.showLocation
          ? _locationController.text.trim()
          : widget.initialLocation?.trim(),
    ));
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleDatePickerSheet(initialDate: _selected),
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
      builder: (_) => _ScheduleTimePickerSheet(
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

enum _ScheduleEntryMode { dateOnly, dateAndTime }

class _ScheduleModeSelector extends StatelessWidget {
  const _ScheduleModeSelector({required this.mode, required this.onChanged});

  final _ScheduleEntryMode mode;
  final ValueChanged<_ScheduleEntryMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.tabBarBorder),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          _modeButton(context, 'Date only', _ScheduleEntryMode.dateOnly),
          _modeButton(context, 'Date & time', _ScheduleEntryMode.dateAndTime),
        ]),
      );

  Widget _modeButton(
      BuildContext context, String label, _ScheduleEntryMode value) {
    final selected = mode == value;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: selected ? FlixieColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? context.colors.white : context.colors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ),
      ),
    );
  }
}

class _QuickScheduleButton extends StatelessWidget {
  const _QuickScheduleButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          foregroundColor: context.colors.light,
          side: BorderSide(color: context.colors.tabBarBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

class _ScheduleDetailCard extends StatelessWidget {
  const _ScheduleDetailCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.tabBarBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: FlixieColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 5),
                    Text(value,
                        style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ])),
              const Text('Change',
                  style: TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

class _ScheduleTimePickerSheet extends StatefulWidget {
  const _ScheduleTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_ScheduleTimePickerSheet> createState() =>
      _ScheduleTimePickerSheetState();
}

class _ScheduleTimePickerSheetState extends State<_ScheduleTimePickerSheet> {
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
        color: context.colors.background,
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
                  color: context.colors.medium,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a time',
                  style: TextStyle(
                    color: context.colors.textPrimary,
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
                    onDateTimeChanged: (value) {
                      _selected = TimeOfDay.fromDateTime(value);
                    },
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

class _ScheduleDatePickerSheet extends StatefulWidget {
  const _ScheduleDatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_ScheduleDatePickerSheet> createState() =>
      _ScheduleDatePickerSheetState();
}

class _ScheduleDatePickerSheetState extends State<_ScheduleDatePickerSheet> {
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
          color: context.colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.medium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose a date',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
