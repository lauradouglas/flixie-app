import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'search_content.dart';

class SearchPersonTile extends StatelessWidget {
  const SearchPersonTile({
    super.key,
    required this.person,
    required this.query,
    this.onTap,
  });

  final Person person;
  final String query;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .07)),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 67,
                  height: 100,
                  child: person.profileImgUrl != null
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w185${person.profileImgUrl}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchHighlightedText(
                      text: person.name,
                      query: query,
                      baseStyle: TextStyle(
                        color: context.colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const FlixiePill.label(label: Text('Person')),
                        if (person.department?.isNotEmpty ?? false)
                          Text(
                            person.department!,
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: context.colors.medium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: context.colors.secondary.withValues(alpha: .3),
        child: Icon(Icons.person, color: context.colors.secondary),
      );
}
