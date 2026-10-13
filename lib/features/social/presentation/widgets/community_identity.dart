import 'package:flutter/material.dart';
import 'community_pip.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Shared community character, keyed by the existing catalogue genre IDs.
class CommunityIdentity {
  const CommunityIdentity(this.blurb);
  final String blurb;

  static const all = <int, CommunityIdentity>{
    -2: CommunityIdentity(
        'Marvel, DC and beyond. Favourite heroes. Big theories.'),
    -3: CommunityIdentity(
        'Real cases. Thoughtful documentaries. Respectful discussion.'),
    -4: CommunityIdentity(
        'Korean dramas. Favourite characters. One more episode.'),
    -5: CommunityIdentity(
        'A galaxy of stories. Find your people across films and series.'),
    -6: CommunityIdentity(
        'Ghibli worlds. Quiet wonder. Stories that stay with you.'),
    -7: CommunityIdentity(
        'Cult favourites. Unusual discoveries. Worth another watch.'),
    -1: CommunityIdentity(
        'Big feelings. Different worlds. Your kind of people.'),
    28: CommunityIdentity(
        'Big stunts. Racing hearts. Films worth the adrenaline.'),
    12: CommunityIdentity(
        'New horizons. Wild journeys. Come along for the ride.'),
    16: CommunityIdentity('Imagination in every frame. Stories for every age.'),
    35: CommunityIdentity(
        'Big laughs. Dry wit. Find your sense of humour here.'),
    80: CommunityIdentity(
        'Crooked plans. Blurred lines. Everyone has a theory.'),
    99: CommunityIdentity(
        'Real stories. Fresh perspectives. Plenty to talk about.'),
    18: CommunityIdentity(
        'Messy lives. Honest moments. Stories that stay with you.'),
    10751: CommunityIdentity(
        'Shared laughs. A little wonder. Something to watch together.'),
    14: CommunityIdentity(
        'Strange lands. A little magic. Let your imagination wander.'),
    36: CommunityIdentity(
        'Other times. Human stories. A past worth talking about.'),
    27: CommunityIdentity(
        'Slow dread. Sudden scares. You don’t have to watch alone.'),
    10402: CommunityIdentity(
        'Big performances. Unforgettable soundtracks. Turn it up.'),
    9648: CommunityIdentity(
        'Small clues. Big questions. Put the pieces together.'),
    10749: CommunityIdentity(
        'First sparks. Missed chances. Love in all its messiness.'),
    878: CommunityIdentity(
        'Distant worlds. Big what-ifs. A future worth debating.'),
    10770: CommunityIdentity(
        'Small-screen stories. Sofa favourites. Find a hidden gem.'),
    53: CommunityIdentity(
        'Rising tension. Shifting loyalties. Just one more twist.'),
    10752: CommunityIdentity(
        'Conflict. Courage. Human stories behind the front lines.'),
    37: CommunityIdentity(
        'Wide horizons. Hard choices. Stories from the frontier.'),
  };

  static CommunityIdentity forId(int id) =>
      (id <= -1000
          ? const CommunityIdentity(
              'Your people. Shared favourites. A place of your own.')
          : all[id]) ??
      const CommunityIdentity(
          'Find your next film. Share what stayed with you.');
}

class CommunityIdentityHeader extends StatelessWidget {
  const CommunityIdentityHeader(
      {super.key, required this.id, required this.name});
  final int id;
  final String name;

  @override
  Widget build(BuildContext context) {
    final identity = CommunityIdentity.forId(id);
    final title = Semantics(
      header: true,
      child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(name,
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: context.colors.white)),
            ExcludeSemantics(child: CommunityIcon(id: id, size: 26)),
          ]),
    );
    final description = Text(identity.blurb,
        style: TextStyle(
            fontSize: 16, height: 1.45, color: context.colors.medium));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: LayoutBuilder(builder: (context, constraints) {
        final hasPip = CommunityPip.assetFor(id) != null;
        final compact = constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(16) > 20;
        final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 10), description]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!hasPip)
            copy
          else if (compact) ...[
            Row(children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              CommunityPip(id: id, size: 64)
            ]),
            const SizedBox(height: 10),
            description,
          ] else
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: copy),
              const SizedBox(width: 16),
              CommunityPip(id: id, size: 120),
            ]),
          const SizedBox(height: 12),
          Text(
              id == -4
                  ? 'Korean drama series · Opinions from people who joined'
                  : id < 0
                      ? 'Films & series · Opinions from people who joined'
                      : 'Films · Opinions from people who joined',
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: context.colors.medium)),
        ]);
      }),
    );
  }
}

/// Original Flixie vector marks; decorative alongside the community name.
class CommunityIcon extends StatelessWidget {
  const CommunityIcon({super.key, required this.id, this.size = 24});
  final int id;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: id <= -1000
            ? Icon(Icons.lock_outline,
                size: size, color: Theme.of(context).colorScheme.secondary)
            : SvgPicture.asset(
                'assets/icon/communities/${CommunityIdentity.all.containsKey(id) ? id : 10770}.svg',
                width: size,
                height: size,
                colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.secondary, BlendMode.srcIn),
              ),
      );
}
