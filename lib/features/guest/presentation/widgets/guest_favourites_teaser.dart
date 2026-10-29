import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

/// Fictional profile examples; never the visitor's saved favourites.
class GuestFavouritesTeaser extends StatefulWidget {
  const GuestFavouritesTeaser({super.key});
  @override
  State<GuestFavouritesTeaser> createState() => _GuestFavouritesTeaserState();
}

class _GuestFavouritesTeaserState extends State<GuestFavouritesTeaser> {
  int _selected = 0;
  static const _examples = [
    [
      ('Interstellar', 'interstellar', ''),
      ('Se7en', 'se7en', ''),
      ('Project Hail Mary', 'hail-mary', '')
    ],
    [
      ('Attack on Titan', 'attack-on-titan', ''),
      ('Hunter x Hunter', 'hunter', ''),
      ('Jujutsu Kaisen', 'jujutsu', '')
    ],
    [
      ('Christopher Nolan', 'nolan', 'Director'),
      ('Denzel Washington', 'denzel', 'Actor'),
      ('Florence Pugh', 'florence', 'Actress')
    ],
  ];
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your favourites, your order.',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Rank your favourite films and shows. Put your favourite people on your profile, too.',
            style: TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Padding(
                    padding: EdgeInsets.all(4),
                    child: ProfileAvatarView(
                        avatar: null,
                        fallbackText: 'M',
                        fallbackColor: FlixieColors.primary,
                        size: 28,
                        profileBadges: ['EARLY_ADOPTER'],
                        imageProvider:
                            AssetImage('assets/icon/pip_emote_thumbs_up.png'))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Maya’s profile',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.white))),
                const SizedBox(width: 8),
                Text('Example',
                    style:
                        TextStyle(fontSize: 12, color: context.colors.light)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                for (final (index, label) in ['Films', 'Shows', 'People'].indexed)
                  Expanded(
                      child: Semantics(
                          selected: _selected == index,
                          child: TextButton(
                              onPressed: () =>
                                  setState(() => _selected = index),
                              style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  foregroundColor: _selected == index
                                      ? context.colors.primaryText
                                      : context.colors.light,
                                  shape: const RoundedRectangleBorder()),
                              child: Container(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              width: 2,
                                              color: _selected == index
                                                  ? context.colors.primaryText
                                                  : Colors.transparent))),
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: _selected == index ? FontWeight.w700 : FontWeight.w400)))))),
              ]),
              const SizedBox(height: 12),
              Text(
                  [
                    'Favourite films',
                    'Favourite shows',
                    'Favourite people'
                  ][_selected],
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.white)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, box) {
                final minWidth = MediaQuery.textScalerOf(context).scale(1) > 1.4
                    ? 120.0
                    : 0.0;
                final width = ((box.maxWidth - 16) / 3).clamp(minWidth, 250.0);
                return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (index, item)
                              in _examples[_selected].indexed) ...[
                            if (index > 0) const SizedBox(width: 8),
                            SizedBox(
                                width: width,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.asset(
                                              'assets/images/guest-favourites/${item.$2}.jpg',
                                              width: width,
                                              height: width * 1.5,
                                              fit: BoxFit.contain,
                                              semanticLabel: item.$1)),
                                      const SizedBox(height: 6),
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_selected != 2) ...[
                                              Text('${index + 1}',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: context
                                                          .colors.primaryText)),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                                child: Text(item.$1,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: context
                                                            .colors.white))),
                                          ]),
                                      if (item.$3.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(item.$3,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: context.colors.light)),
                                      ],
                                    ])),
                          ],
                        ]));
              }),
            ])),
        const SizedBox(height: 8),
        Text('A profile full of your kind of favourites.',
            style: TextStyle(fontSize: 12, color: context.colors.light)),
      ]);
}
