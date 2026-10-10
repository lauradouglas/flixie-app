import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/person.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

class PersonDetailHero extends StatelessWidget {
  const PersonDetailHero(
      {super.key,
      required this.person,
      required this.images,
      required this.isFavorite,
      required this.favoriteLoading,
      required this.onFavorite,
      required this.onOpenPhoto,
      required this.onLaunch});
  final Person person;
  final List<PersonImage> images;
  final bool isFavorite, favoriteLoading;
  final VoidCallback onFavorite;
  final ValueChanged<int> onOpenPhoto;
  final ValueChanged<String> onLaunch;
  @override
  Widget build(BuildContext context) {
    final profileUrl = person.profileImgUrl == null
        ? null
        : 'https://image.tmdb.org/t/p/w500${person.profileImgUrl}';
    return Stack(children: [
      _buildCompactHero(context, person, profileUrl),
      Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 12,
          child: _heroNavigationButton(context,
              icon: flixieBackIcon(context, backIcon: Icons.arrow_back_rounded),
              label: flixieBackLabel(context),
              onPressed: () => flixieBackOrHome(context))),
      Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 12,
          child: favoriteLoading
              ? Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.colors.danger)))
              : _heroNavigationButton(context,
                  transparentBackground: true,
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: isFavorite ? 'Remove favourite' : 'Add favourite',
                  color:
                      isFavorite ? context.colors.danger : context.colors.light,
                  onPressed: onFavorite)),
    ]);
  }

  Widget _buildCompactHero(
      BuildContext context, Person person, String? profileUrl) {
    final width = MediaQuery.sizeOf(context).width;
    final portraitWidth = (width * .42).clamp(140.0, 190.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
            ),
            child: GestureDetector(
              onTap: images.isEmpty ? null : () => onOpenPhoto(0),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(12)),
                child: SizedBox(
                  width: portraitWidth,
                  height: portraitWidth * 1.48,
                  child: profileUrl != null
                      ? CachedNetworkImage(
                          imageUrl: profileUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorWidget: (_, __, ___) =>
                              _portraitFallback(context, person.name),
                        )
                      : _portraitFallback(context, person.name),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 12,
              ),
              child: _buildHeroSummary(context, person),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroNavigationButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = FlixieColors.light,
    bool transparentBackground = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(44),
          backgroundColor: transparentBackground
              ? Colors.transparent
              : Colors.black.withValues(alpha: .5),
          foregroundColor: color,
          side: transparentBackground
              ? BorderSide.none
              : BorderSide(color: Colors.white.withValues(alpha: .1)),
        ),
        icon: Icon(icon),
      ),
    );
  }

  Widget _buildHeroSummary(BuildContext context, Person person) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (person.department != null && person.department!.isNotEmpty) ...[
          _miniBadge(
              context, person.department!.toUpperCase(), FlixieColors.primary),
          const SizedBox(height: 10),
        ],
        Text(
          person.name,
          style: TextStyle(
            color: context.colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (person.dateOfBirth != null && person.dateOfBirth!.isNotEmpty)
              _heroMeta(context, Icons.calendar_today_outlined,
                  _formatDate(person.dateOfBirth)),
            if (person.dateOfDeath != null && person.dateOfDeath!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _heroMeta(context, Icons.event_busy_outlined,
                    _formatDate(person.dateOfDeath)),
              ),
            if (person.placeOfBirth != null && person.placeOfBirth!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _heroMeta(
                    context, Icons.place_outlined, person.placeOfBirth!),
              ),
            if (_ageLabel(person) != null)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child:
                    _heroMeta(context, Icons.cake_outlined, _ageLabel(person)!),
              ),
          ],
        ),
        if ((person.imdbId?.isNotEmpty ?? false) ||
            (person.instagramId?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (person.imdbId?.isNotEmpty ?? false)
                _compactExternalLink(
                  context,
                  icon: Icons.movie_filter_outlined,
                  label: 'IMDb',
                  onTap: () =>
                      onLaunch('https://www.imdb.com/name/${person.imdbId}'),
                ),
              if (person.instagramId?.isNotEmpty ?? false)
                _compactExternalLink(
                  context,
                  icon: Icons.camera_alt_outlined,
                  label: 'Instagram',
                  onTap: () => onLaunch(
                    'https://www.instagram.com/${person.instagramId}',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _compactExternalLink(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return FlixiePill.action(
        avatar: Icon(icon, size: 15), label: Text(label), onPressed: onTap);
  }

  Widget _heroMeta(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: context.colors.light, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.colors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split('-');
    if (parts.length < 3) return raw;
    const months = [
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
      'Dec'
    ];
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return raw;
    return '${months[month - 1]} ${parts[2]}, ${parts[0]}';
  }

  String? _ageLabel(Person person) {
    final born = DateTime.tryParse(person.dateOfBirth ?? '');
    if (born == null) return null;
    final end = DateTime.tryParse(person.dateOfDeath ?? '') ?? DateTime.now();
    var age = end.year - born.year;
    if (end.month < born.month ||
        (end.month == born.month && end.day < born.day)) {
      age--;
    }
    if (age < 0) return null;
    return person.dateOfDeath == null ? 'Age $age' : 'Lived to $age';
  }

  Widget _miniBadge(BuildContext context, String label, Color color,
      {IconData? icon}) {
    return FlixiePill.label(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, color: color));
  }

  Widget _portraitFallback(BuildContext context, String name) {
    return Container(
      color: context.colors.surfaceElevated,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: context.colors.medium,
            fontSize: 80,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}
