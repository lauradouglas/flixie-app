// Fictional design previews. No API calls, application edits or persistence.
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_composer/composer_components.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_composer/composer_recipient_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'log_sheet_mockup.dart';

Widget watchTogetherPreview(String screen) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Builder(
          builder: (context) => Scaffold(
                body: SafeArea(
                    child: Column(children: [
                  const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('9:41',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            Text('5G   100%')
                          ])),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(children: [
                        const FlixieWordmark(fontSize: 28),
                        const Spacer(),
                        Icon(
                            screen.contains('log')
                                ? Icons.close_rounded
                                : Icons.notifications_none_rounded,
                            color: context.colors.medium),
                      ])),
                  Expanded(
                      child: screen == 'current-log'
                          ? Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                  height: 800,
                                  child: RewatchLogSheet(
                                      showReviewOption: true,
                                      onSubmit: (
                                          {required watchedAt,
                                          required rating,
                                          required recommended,
                                          required notes}) async {})))
                          : screen == 'updated-log'
                              ? Align(
                                  alignment: Alignment.bottomCenter,
                                  child: WatchTogetherLogMockup(
                                      showReviewOption: true,
                                      onSubmit: (
                                          {required watchedAt,
                                          required rating,
                                          required recommended,
                                          required notes}) async {}))
                              : _ConceptScreen(screen: screen)),
                  const SizedBox(height: 8),
                  Container(
                      width: 125,
                      height: 5,
                      decoration: BoxDecoration(
                          color: context.colors.white,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 10),
                ])),
              )),
    );

class _ConceptScreen extends StatelessWidget {
  const _ConceptScreen({required this.screen});
  final String screen;
  Widget heading(BuildContext c, String text) => Text(text,
      style: Theme.of(c)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w800));
  Widget body(BuildContext c, String text) => Text(text,
      style: TextStyle(color: c.colors.medium, fontSize: 14, height: 1.5));
  Widget primary(String text) => SizedBox(
      width: double.infinity,
      child: ElevatedButton(
          onPressed: () {},
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: Text(text)));
  Widget secondary(String text) => SizedBox(
      width: double.infinity,
      child: OutlinedButton(
          onPressed: () {},
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(text)));
  Widget person(BuildContext c, String name, String detail,
          {bool selected = true}) =>
      RecipientOptionTile(
          title: name,
          subtitle: detail,
          selected: selected,
          profileBadges: const ['EARLY_ADOPTER'],
          onTap: () {});
  Widget film(BuildContext c) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
            width: 54,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xff141b15),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('ALIEN',
                style: TextStyle(
                    fontSize: 10, letterSpacing: 2, color: Color(0xffb8d694)))),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              heading(c, 'Alien'),
              const SizedBox(height: 4),
              body(c, '1979 · 1h 57m')
            ]))
      ]));
  @override
  Widget build(BuildContext context) {
    final c = context;
    final content = <Widget>[];
    if (screen == 'create-plan')
      content.addAll([
        heading(c, 'Create watch plan'),
        const SizedBox(height: 6),
        body(c, 'A film together, whenever it happens.'),
        const SizedBox(height: 24),
        const PlanStepHeading(number: '1', title: 'Who’s watching?'),
        const SizedBox(height: 12),
        person(c, 'Sophie', 'Your friend'),
        const SizedBox(height: 24),
        const PlanStepHeading(number: '2', title: 'Movie'),
        const SizedBox(height: 12),
        film(c),
        const SizedBox(height: 24),
        const PlanStepHeading(
            number: '3', title: 'When?', trailing: 'OPTIONAL'),
        const SizedBox(height: 12),
        SchedulePicker(label: 'DATE', value: 'Date to decide', onTap: () {}),
        const SizedBox(height: 12),
        body(c, 'Add a date now, or leave it for later.'),
        const SizedBox(height: 24),
        primary('Save watch plan'),
        const SizedBox(height: 12),
        body(c,
            'Saved straight away. Sophie can see the plan without needing to accept.'),
      ]);
    if (screen == 'saved-plan')
      content.addAll([
        heading(c, 'Watch Plans'),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.people_outline_rounded, color: FlixieColors.primary),
          const SizedBox(width: 8),
          body(c, 'Friends'),
          const SizedBox(width: 24),
          body(c, 'Groups')
        ]),
        const SizedBox(height: 20),
        film(c),
        const SizedBox(height: 16),
        person(c, 'Sophie', 'Watching with you · Added by you', selected: false),
        const SizedBox(height: 20),
        heading(c, 'Date to decide'),
        const SizedBox(height: 8),
        body(c, 'Your plan is saved. Add a date whenever you know.'),
        const SizedBox(height: 20),
        primary('We watched it'),
        const SizedBox(height: 10),
        secondary('Add a date'),
        const SizedBox(height: 18),
        body(c,
            'No invitation to accept. You each log your own watch afterwards.'),
      ]);
    if (screen == 'companion-prompt')
      content.addAll([
        heading(c, 'Notifications'),
        const SizedBox(height: 20),
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: c.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.colors.tabBarBorder)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const ProfileAvatarView(
                    avatar: null,
                    profileBadges: ['FOUNDER'],
                    fallbackText: 'L',
                    fallbackColor: FlixieColors.primary,
                    size: 44),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      heading(c, 'Watched together?'),
                      body(c, 'Laura · Just now')
                    ]))
              ]),
              const SizedBox(height: 20),
              body(c,
                  'Laura logged Alien and added you as someone she watched with.'),
              const SizedBox(height: 16),
              film(c),
              const SizedBox(height: 20),
              primary('Log my watch'),
              const SizedBox(height: 10),
              secondary('I wasn’t there'),
              const SizedBox(height: 16),
              body(c,
                  'Check the date and add your own rating. Nothing is added to your history until you save.'),
            ])),
        const SizedBox(height: 20),
        body(c, 'Sophie’s view · After Laura logs a watch'),
      ]);
    if (screen == 'rating-prompt')
      content.addAll([
        heading(c, 'Your watch plan'),
        const SizedBox(height: 18),
        film(c),
        const SizedBox(height: 20),
        person(c, 'Sophie has rated Alien', 'From your watch together',
            selected: false),
        const SizedBox(height: 26),
        heading(c, 'How was it?'),
        const SizedBox(height: 8),
        body(c, 'Watched it too? Log your watch and add your own rating.'),
        const SizedBox(height: 22),
        Wrap(
            spacing: 6,
            runSpacing: 8,
            children: List.generate(
                10,
                (i) => SizedBox(
                    width: 59,
                    child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Column(children: [
                          const Icon(Icons.star_border_rounded, size: 20),
                          Text('${i + 1}')
                        ]))))),
        const SizedBox(height: 14),
        body(c, 'Rating is optional · Your own score out of 10'),
        const SizedBox(height: 22),
        primary('Log my watch'),
        const SizedBox(height: 10),
        secondary('Haven’t watched it yet'),
      ]);
    return SingleChildScrollView(
        child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            decoration: BoxDecoration(
                color: c.colors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                          color: c.colors.medium,
                          borderRadius: BorderRadius.circular(3)))),
              ...content
            ])));
  }
}
