import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../controllers/profile_diary_controller.dart';
import '../diary/diary_calendar_sheet.dart';
import '../diary/diary_selection.dart';
import '../diary/diary_watch_entry.dart';

class ProfileDiaryScreen extends StatefulWidget {
  const ProfileDiaryScreen(
      {super.key, this.controller, this.today, this.embedded = false});
  final ProfileDiaryController? controller;
  final DateTime? today;
  final bool embedded;
  @override
  State<ProfileDiaryScreen> createState() => _ProfileDiaryScreenState();
}

class _ProfileDiaryScreenState extends State<ProfileDiaryScreen> {
  late final ProfileDiaryController data;
  late final DateTime anchor = diaryMonday(widget.today ?? DateTime.now());
  final pages = PageController(initialPage: 10000);
  int index = 10000;
  DateTime at(int index) =>
      DateTime(anchor.year, anchor.month, anchor.day + (index - 10000) * 7);
  @override
  void initState() {
    super.initState();
    data = widget.controller ??
        ProfileDiaryController(auth: context.read<AuthProvider>());
    data.addListener(changed);
    if (!data.loaded) unawaited(data.load());
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    data.removeListener(changed);
    if (widget.controller == null) data.dispose();
    pages.dispose();
    super.dispose();
  }

  void jump(DateTime week) {
    final target =
        (10000 + diaryDaysBetween(week, anchor) ~/ 7).clamp(0, 20000);
    if (widget.embedded) {
      setState(() => index = target);
    } else {
      pages.jumpToPage(target);
    }
  }

  Future<void> calendar() async {
    final value = await showModalBottomSheet<DateTime>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => ListenableBuilder(
            listenable: data,
            builder: (_, __) => DiaryCalendarSheet(
                week: at(index), selection: data.selection)));
    if (mounted && value != null) jump(value);
  }

  Future<void> undated() async {
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: diaryPaper,
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (sheet) => ListenableBuilder(
            listenable: data,
            builder: (_, __) => SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .8,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                      child: Row(children: [
                        const Expanded(
                            child: Text('Watches without a date',
                                style: TextStyle(
                                    color: diaryInk,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800))),
                        IconButton(
                            tooltip: 'Close undated watches',
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close, color: diaryInk))
                      ])),
                  Expanded(
                      child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: data.selection.undated.length,
                          itemBuilder: (_, i) =>
                              DiaryWatchEntry(entry: data.selection.undated[i]),
                          separatorBuilder: (_, __) =>
                              const Divider(color: Color(0xffddd0e8))))
                ]))));
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _body(context)
      : Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(title: const Text('Your film diary'), actions: [
            IconButton(
                tooltip: 'Refresh diary',
                onPressed: data.loading ? null : () => data.load(refresh: true),
                icon: const Icon(Icons.refresh))
          ]),
          body: SafeArea(top: false, child: _body(context)));

  Widget _body(BuildContext context) => Column(children: [
        if (data.loading && !data.loaded)
          _expand(child: const Center(child: CircularProgressIndicator()))
        else if (data.failed && !data.loaded)
          _expand(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Couldn’t load your film diary.'),
                        TextButton(
                            onPressed: () => data.load(),
                            child: const Text('Try again'))
                      ]))))
        else ...[
          if (data.failed)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Expanded(
                      child: Text(
                          'Couldn’t refresh. Showing your last loaded watches.')),
                  TextButton(
                      onPressed: () => data.load(), child: const Text('Retry'))
                ])),
          if (widget.embedded)
            GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() > 100) move(velocity < 0 ? 1 : -1);
                },
                child: weekPage(at(index)))
          else
            Expanded(
                child: PageView.builder(
                    controller: pages,
                    itemCount: 20001,
                    onPageChanged: (i) => setState(() => index = i),
                    itemBuilder: (_, i) => weekPage(at(i)))),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                        onPressed: () => jump(anchor),
                        child: const Text('This week')),
                    if (data.selection.undated.isNotEmpty)
                      TextButton(
                          onPressed: undated,
                          child: Text(
                              'No date (${data.selection.undated.length})')),
                    Text('Swipe weeks · Tap the date to jump',
                        style: TextStyle(
                            color: context.colors.medium, fontSize: 12))
                  ])),
        ],
      ]);
  Widget weekPage(DateTime week) {
    final entries = data.selection.week(week),
        l = MaterialLocalizations.of(context);
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                decoration: BoxDecoration(
                    color: diaryPaper, borderRadius: BorderRadius.circular(14)),
                child: _weekScroll(
                    key: ValueKey('diary-week-${week.toIso8601String()}'),
                    padding: const EdgeInsets.all(16),
                    child: DefaultTextStyle(
                        style: const TextStyle(
                            color: diaryInk,
                            fontSize: 14,
                            fontFamily: 'Manrope'),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dear film diary,',
                                  style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontFamilyFallback: ['serif'],
                                      fontSize: 29,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              const Text(
                                  'The films. The people. The little memories.',
                                  style: TextStyle(
                                      color: diaryMuted, fontSize: 13)),
                              const SizedBox(height: 12),
                              Row(children: [
                                IconButton(
                                    tooltip: 'Previous week',
                                    onPressed:
                                        index == 0 ? null : () => move(-1),
                                    icon: const Icon(Icons.chevron_left,
                                        color: diaryInk)),
                                Expanded(
                                    child: TextButton(
                                        onPressed: calendar,
                                        style: TextButton.styleFrom(
                                            foregroundColor: diaryInk),
                                        child: Wrap(
                                            alignment: WrapAlignment.center,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 6,
                                            children: [
                                              const Icon(
                                                  Icons.calendar_month_outlined,
                                                  size: 18),
                                              Text(
                                                  diaryWeekLabel(context, week),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              const Icon(Icons.expand_more,
                                                  size: 18)
                                            ]))),
                                IconButton(
                                    tooltip: 'Next week',
                                    onPressed:
                                        index == 20000 ? null : () => move(1),
                                    icon: const Icon(Icons.chevron_right,
                                        color: diaryInk))
                              ]),
                              Center(
                                  child: Text(
                                      '${entries.length} ${entries.length == 1 ? 'watch' : 'watches'}${entries.any((e) => data.selection.rewatches.contains(e.id)) ? ' · ${entries.where((e) => data.selection.rewatches.contains(e.id)).length} rewatches' : ''}',
                                      style: const TextStyle(
                                          color: diaryMuted, fontSize: 12))),
                              const SizedBox(height: 16),
                              Row(children: [
                                for (int day = 0; day < 7; day++)
                                  Expanded(
                                      child: Column(children: [
                                    Text(l.narrowWeekdays[(day + 1) % 7],
                                        style: const TextStyle(
                                            fontSize: 11, color: diaryMuted)),
                                    const SizedBox(height: 8),
                                    Container(
                                        constraints:
                                            const BoxConstraints(minHeight: 32),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: data.selection.days
                                                    .containsKey(DateTime(
                                                        week.year,
                                                        week.month,
                                                        week.day + day))
                                                ? diaryInk
                                                : const Color(0xffe7ddf0)),
                                        child: Text(
                                            '${DateTime(week.year, week.month, week.day + day).day}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: data.selection.days
                                                        .containsKey(DateTime(
                                                            week.year,
                                                            week.month,
                                                            week.day + day))
                                                    ? Colors.white
                                                    : diaryMuted)))
                                  ]))
                              ]),
                              const SizedBox(height: 16),
                              if (entries.isEmpty)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('A quiet page.',
                                              style: TextStyle(
                                                  fontSize: 24,
                                                  fontFamily: 'Georgia',
                                                  fontFamilyFallback: [
                                                    'serif'
                                                  ])),
                                          const SizedBox(height: 10),
                                          const Text(
                                              'No films logged this week. Every movie night will find a home here.',
                                              style:
                                                  TextStyle(color: diaryMuted)),
                                          TextButton(
                                              onPressed: calendar,
                                              style: TextButton.styleFrom(
                                                  foregroundColor: diaryInk),
                                              child: const Text(
                                                  'Find another week'))
                                        ])),
                              for (int i = 0; i < entries.length; i++) ...[
                                DiaryWatchEntry(
                                    entry: entries[i],
                                    rewatch: data.selection.rewatches
                                        .contains(entries[i].id)),
                                if (i < entries.length - 1)
                                  const Divider(
                                      height: 1, color: Color(0xffddd0e8))
                              ],
                            ]))))));
  }

  Widget _expand({required Widget child}) =>
      widget.embedded ? child : Expanded(child: child);

  Widget _weekScroll(
          {required Key key,
          required EdgeInsets padding,
          required Widget child}) =>
      widget.embedded
          ? Padding(key: key, padding: padding, child: child)
          : SingleChildScrollView(key: key, padding: padding, child: child);

  void move(int delta) {
    final target = (index + delta).clamp(0, 20000);
    if (widget.embedded) {
      setState(() => index = target);
    } else if (MediaQuery.disableAnimationsOf(context)) {
      pages.jumpToPage(index + delta);
    } else {
      pages.animateToPage(index + delta,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    }
  }
}
