import 'package:flutter/material.dart';
import 'diary_selection.dart';

const diaryPaper = Color(0xfff4edf9),
    diaryInk = Color(0xff302044),
    diaryMuted = Color(0xff67547d);
String diaryWeekLabel(BuildContext context, DateTime start) {
  final end = DateTime(start.year, start.month, start.day + 6),
      l = MaterialLocalizations.of(context);
  return start.month == end.month
      ? '${start.day}–${end.day} ${l.formatMonthYear(end)}'
      : '${l.formatShortDate(start)} – ${l.formatShortDate(end)}';
}

class DiaryCalendarSheet extends StatefulWidget {
  const DiaryCalendarSheet(
      {super.key, required this.week, required this.selection});
  final DateTime week;
  final DiarySelection selection;
  @override
  State<DiaryCalendarSheet> createState() => _DiaryCalendarSheetState();
}

class _DiaryCalendarSheetState extends State<DiaryCalendarSheet> {
  late DateTime selected = widget.week;
  late DateTime month = DateTime(selected.year, selected.month);
  bool years = false;
  Text text(String s, double size, {FontWeight weight = FontWeight.w500}) =>
      Text(s,
          style:
              TextStyle(color: diaryInk, fontSize: size, fontWeight: weight));
  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context),
        scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: Material(
            color: diaryPaper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: diaryMuted.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(3))),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: text('Find a week', 26,
                                      weight: FontWeight.w800)),
                              IconButton(
                                  tooltip: 'Close calendar',
                                  onPressed: () => Navigator.pop(context),
                                  icon:
                                      const Icon(Icons.close, color: diaryInk))
                            ]),
                            const SizedBox(height: 8),
                            text('A little dot, a movie memory.', 13),
                            Row(children: [
                              IconButton(
                                  tooltip: 'Previous month',
                                  onPressed: () => setState(() => month =
                                      DateTime(month.year, month.month - 1)),
                                  icon: const Icon(Icons.chevron_left,
                                      color: diaryInk)),
                              Expanded(
                                  child: TextButton(
                                      onPressed: () =>
                                          setState(() => years = !years),
                                      child: text(l.formatMonthYear(month), 17,
                                          weight: FontWeight.w800))),
                              IconButton(
                                  tooltip: 'Next month',
                                  onPressed: () => setState(() => month =
                                      DateTime(month.year, month.month + 1)),
                                  icon: const Icon(Icons.chevron_right,
                                      color: diaryInk))
                            ]),
                            if (years)
                              SizedBox(
                                  height: 220,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                          primary: diaryInk,
                                          onPrimary: Colors.white,
                                          surface: diaryPaper,
                                          onSurface: diaryInk),
                                      textTheme: Theme.of(context)
                                          .textTheme
                                          .apply(
                                              bodyColor: diaryInk,
                                              displayColor: diaryInk),
                                    ),
                                    child: YearPicker(
                                      firstDate: DateTime(month.year < 1900
                                          ? month.year
                                          : 1900),
                                      lastDate: DateTime(
                                          month.year > DateTime.now().year + 1
                                              ? month.year
                                              : DateTime.now().year + 1),
                                      selectedDate: month,
                                      onChanged: (date) => setState(() {
                                        month =
                                            DateTime(date.year, month.month);
                                        years = false;
                                      }),
                                    ),
                                  ))
                            else ...[
                              Row(children: [
                                for (int day = 0; day < 7; day++)
                                  Expanded(
                                      child: Center(
                                          child: text(
                                              l.narrowWeekdays[(day + 1) % 7],
                                              12)))
                              ]),
                              const SizedBox(height: 10),
                              for (int row = 0;
                                  row <
                                      ((month.weekday -
                                                  1 +
                                                  DateUtils.getDaysInMonth(
                                                      month.year,
                                                      month.month)) /
                                              7)
                                          .ceil();
                                  row++)
                                Row(children: [
                                  for (int col = 0; col < 7; col++)
                                    Expanded(
                                        child: cell(
                                            row * 7 + col - month.weekday + 2,
                                            scale))
                                ]),
                            ],
                            const SizedBox(height: 18),
                            Row(children: [
                              const Icon(Icons.circle,
                                  size: 6, color: Color(0xff8247ce)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: text(
                                      'Film logged · Tap a day to choose its week',
                                      12))
                            ]),
                            const SizedBox(height: 20),
                            text(diaryWeekLabel(context, selected), 16,
                                weight: FontWeight.w800),
                            const SizedBox(height: 6),
                            text(
                                '${widget.selection.week(selected).length} watches this week',
                                13),
                          ]))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () => Navigator.pop(context, selected),
                          style: FilledButton.styleFrom(
                              backgroundColor: diaryInk,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50)),
                          child: const Text('Show this week')))),
            ])));
  }

  Widget cell(int day, double scale) {
    final height = 48.0 + (scale - 1).clamp(0, 2) * 12;
    if (day < 1 || day > DateUtils.getDaysInMonth(month.year, month.month)) {
      return SizedBox(height: height);
    }
    final date = DateTime(month.year, month.month, day),
        count = widget.selection.days[DateTime(month.year, month.month, day)]
                ?.length ??
            0;
    final active = diaryMonday(date) == selected;
    return Semantics(
        label:
            '${MaterialLocalizations.of(context).formatFullDate(date)}, $count watches',
        selected: active,
        button: true,
        child: InkWell(
            key: ValueKey('diary-day-${date.year}-${date.month}-$day'),
            onTap: () => setState(() => selected = diaryMonday(date)),
            child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color:
                        active ? const Color(0xffe2cff5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      text('$day', 13,
                          weight: active ? FontWeight.w800 : FontWeight.w500),
                      const SizedBox(height: 4),
                      Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: count > 0
                                  ? const Color(0xff8247ce)
                                  : Colors.transparent))
                    ]))));
  }
}
