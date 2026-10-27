// Responsive design proposal only; no application routes or API access.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

Widget adaptiveLogPreview(
        {bool omitPoster = false, double scale = 1, double keyboard = 0}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: child!),
      home: AdaptiveLog(omitPoster: omitPoster),
    );

class AdaptiveLog extends StatefulWidget {
  const AdaptiveLog({super.key, this.omitPoster = false});
  final bool omitPoster;
  @override
  State<AdaptiveLog> createState() => _AdaptiveLogState();
}

class _AdaptiveLogState extends State<AdaptiveLog> {
  int? rating;
  bool review = false, spoilers = false;
  String friend = 'Sophie';
  Widget hint(String text) => Text(text,
      style:
          TextStyle(fontSize: 12, color: context.colors.medium, height: 1.4));
  Widget title(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
  Future<void> pickFriend() async {
    final selected = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (c) => SizedBox(
            height: MediaQuery.sizeOf(c).height * .6,
            child: Material(
                color: context.colors.surface,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text('Watched with…',
                      style:
                          TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  for (final name in ['Sophie', 'Casey'])
                    ListTile(
                        leading: ProfileAvatarView(
                            avatar: null,
                            fallbackText: name[0],
                            fallbackColor: FlixieColors.primary,
                            profileBadges: name == 'Sophie'
                                ? const ['EARLY_ADOPTER']
                                : const ['FOUNDER'],
                            size: 40),
                        title: Text(name),
                        onTap: () => Navigator.pop(c, name)),
                  TextButton(
                      onPressed: () => Navigator.pop(c, ''),
                      child: const Text('Watched on my own'))
                ]))));
    if (mounted && selected != null) setState(() => friend = selected);
  }

  Widget form(bool poster, bool compact, bool landscape) =>
      LayoutBuilder(builder: (context, box) {
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (poster) ...[
            Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                      File('output/watch-together-mockups/alien.jpg'),
                      width: 42,
                      height: 62,
                      fit: BoxFit.cover)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Alien',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    hint('1979 · 1h 57m')
                  ]))
            ]),
            const SizedBox(height: 16)
          ],
          Row(children: [
            Icon(Icons.calendar_today_outlined,
                color: context.colors.primaryText, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title('Today'), hint('16 October 2026')])),
            TextButton(onPressed: () {}, child: const Text('Change'))
          ]),
          const SizedBox(height: 12),
          Divider(color: context.colors.tabBarBorder),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: title('Watched with')),
            TextButton(
                onPressed: pickFriend,
                child: Text(friend.isEmpty ? 'Add someone' : 'Change'))
          ]),
          if (friend.isNotEmpty)
            Row(children: [
              Padding(
                  padding: const EdgeInsets.all(3),
                  child: ProfileAvatarView(
                      avatar: null,
                      fallbackText: friend[0],
                      fallbackColor: const Color(0xff65418b),
                      profileBadges: friend == 'Sophie'
                          ? const ['EARLY_ADOPTER']
                          : const ['FOUNDER'],
                      size: 40)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title(friend), hint('Added to this watch')]))
            ])
          else
            hint('Just you for this watch.'),
        ]);
        final thoughts =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: title('Your rating')),
            if (rating != null)
              TextButton(
                  onPressed: () => setState(() => rating = null),
                  child: const Text('Clear'))
            else
              hint('Optional')
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, b) {
            final columns = b.maxWidth < 300 &&
                    MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 4
                : 5;
            final width = (b.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (var n = 1; n <= 10; n++)
                SizedBox(
                    width: width,
                    height: 48,
                    child: OutlinedButton(
                        onPressed: () =>
                            setState(() => rating = rating == n ? null : n),
                        style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: rating == n
                                ? FlixieColors.primary
                                : context.colors.surfaceElevated,
                            side: BorderSide(
                                color: rating == n
                                    ? FlixieColors.primary
                                    : context.colors.tabBarBorder),
                            foregroundColor: rating == n
                                ? Colors.white
                                : context.colors.primaryText,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: Text('$n',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700))))
            ]);
          }),
          const SizedBox(height: 8),
          hint(rating == null
              ? 'Out of 10 · You can rate it later.'
              : '$rating / 10'),
          const SizedBox(height: 12),
          ExpansionTile(
              initiallyExpanded: review,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: const Text('Recommendation & review',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              onExpansionChanged: (v) => setState(() => review = v),
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final value in ['Recommend', 'No opinion', 'Not for me'])
                    ActionChip(label: Text(value), onPressed: () {})
                ]),
                const SizedBox(height: 12),
                const TextField(
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        InputDecoration(hintText: 'What did you think?')),
                const SizedBox(height: 8),
                hint('Shared with friends, following your privacy settings.'),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Contains spoilers'),
                    value: spoilers,
                    onChanged: (v) => setState(() => spoilers = v!)),
              ]),
        ]);
        if (landscape)
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: details),
            const SizedBox(width: 32),
            Expanded(child: thoughts)
          ]);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [details, SizedBox(height: compact ? 20 : 28), thoughts]);
      });
  Widget sheet(bool poster, bool compact, bool landscape) => Material(
      color: context.colors.surface,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Log your watch',
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w800)),
                    if (!poster) ...[
                      const SizedBox(height: 4),
                      Text('Alien · 1979',
                          style: TextStyle(
                              fontSize: 14, color: context.colors.light))
                    ]
                  ])),
              IconButton(
                  tooltip: 'Close',
                  onPressed: () {},
                  icon: const Icon(Icons.close_rounded))
            ])),
        Divider(color: context.colors.tabBarBorder, height: 1),
        Expanded(
            child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 20),
                child: form(poster, compact, landscape))),
        Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, compact ? 10 : 16),
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: context.colors.tabBarBorder))),
            child: Column(children: [
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      child: const Text('Save watch',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)))),
              if (!landscape) ...[
                const SizedBox(height: 8),
                hint(friend.isEmpty
                    ? 'You can add more details later.'
                    : '$friend gets a prompt to log their own watch.')
              ],
            ])),
      ]));
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context),
        keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tablet = size.width >= 600 && size.height >= 600;
    final landscape = size.width > size.height;
    final compact = size.height - keyboard < 760 || textScale > 1.2;
    final poster = !widget.omitPoster &&
        !compact &&
        (!landscape || tablet) &&
        keyboard == 0 &&
        (tablet || size.height >= 900);
    return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: context.colors.background,
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('9:41',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    if (tablet) const FlixieWordmark(fontSize: 24),
                    Icon(Icons.battery_full,
                        size: 20, color: context.colors.light)
                  ])),
          Expanded(
              child: tablet
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: landscape ? 820 : 560,
                              maxHeight: landscape ? 640 : 760),
                          child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
                              child: sheet(poster, compact, landscape))))
                  : sheet(poster, compact, landscape)),
          Container(
              height: 4,
              width: 116,
              margin: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                  color: context.colors.white,
                  borderRadius: BorderRadius.circular(3))),
        ])));
  }
}
