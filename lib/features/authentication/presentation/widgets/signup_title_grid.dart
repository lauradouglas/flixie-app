import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../data/setup_service.dart';

/// Poster-led results for explicit watchlist and favourite additions.
class SignupTitleGrid extends StatelessWidget {
  const SignupTitleGrid(
      {super.key,
      required this.titles,
      required this.saved,
      required this.pending,
      required this.favourites,
      required this.onAdd,
      this.selectForLog = false,
      this.selectForRating = false,
      this.allowRemoval = false,
      this.disabled = false});
  final List<SetupTitle> titles;
  final Set<String> saved, pending;
  final bool favourites;
  final bool disabled;
  final bool selectForLog;
  final bool selectForRating, allowRemoval;
  final ValueChanged<SetupTitle> onAdd;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final columns =
            (box.maxWidth / (largeText ? 150 : 105)).floor().clamp(1, 5);
        final width = (box.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 24, children: [
          for (final title in titles)
            SizedBox(
                width: width,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                          label: title.name,
                          selected: saved.contains(title.key),
                          child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(fit: StackFit.expand, children: [
                                    ColoredBox(
                                        color: context.colors.surfaceElevated,
                                        child: title.poster?.isNotEmpty != true
                                            ? const Icon(
                                                Icons.local_movies_outlined)
                                            : Image.network(
                                                title.poster!.startsWith('http')
                                                    ? title.poster!
                                                    : 'https://image.tmdb.org/t/p/w342${title.poster}',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons
                                                        .local_movies_outlined))),
                                    Positioned(
                                        bottom: 6,
                                        right: 6,
                                        child: Material(
                                            color: context.colors.background,
                                            shape: const CircleBorder(),
                                            child: IconButton(
                                                tooltip: selectForRating
                                                    ? 'Rate ${title.name}'
                                                    : selectForLog
                                                        ? 'Log ${title.name}'
                                                        : saved.contains(
                                                                title.key)
                                                            ? (favourites
                                                                ? (allowRemoval
                                                                    ? 'Remove ${title.name} from favourites'
                                                                    : 'Added to favourites')
                                                                : 'Saved to watchlist')
                                                            : (favourites
                                                                ? 'Add ${title.name} to favourites'
                                                                : 'Save ${title.name}'),
                                                onPressed: disabled ||
                                                        (saved.contains(
                                                                title.key) &&
                                                            !allowRemoval &&
                                                            !selectForRating) ||
                                                        pending
                                                            .contains(title.key)
                                                    ? null
                                                    : () => onAdd(title),
                                                icon: pending
                                                        .contains(title.key)
                                                    ? const SizedBox.square(
                                                        dimension: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2))
                                                    : Icon(
                                                        selectForRating
                                                            ? Icons.star_outline
                                                            : selectForLog
                                                                ? Icons
                                                                    .edit_note
                                                                : favourites
                                                                    ? (saved.contains(title.key)
                                                                        ? Icons
                                                                            .favorite
                                                                        : Icons
                                                                            .favorite_border)
                                                                    : (saved.contains(title.key)
                                                                        ? Icons
                                                                            .bookmark
                                                                        : Icons.bookmark_border),
                                                        color: saved.contains(title.key) ? context.colors.primaryText : context.colors.textPrimary))))
                                  ])))),
                      const SizedBox(height: 8),
                      Text(title.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, height: 1.3)),
                      const SizedBox(height: 4),
                      Text(title.reason ?? (title.isShow ? 'TV show' : 'Film'),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]))
        ]);
      });
}
