import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Extracts a 4-digit year string from a release date in various formats.
String? searchReleaseYear(String? releaseDate) {
  if (releaseDate == null || releaseDate.isEmpty) return null;
  final iso = DateTime.tryParse(releaseDate);
  if (iso != null) return iso.year.toString();
  final parts = releaseDate.split(' ');
  if (parts.length == 4) return parts[3];
  if (releaseDate.length >= 4) return releaseDate.substring(0, 4);
  return null;
}

class SearchHighlightedText extends StatelessWidget {
  const SearchHighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.baseStyle,
  });

  final String text;
  final String query;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final start = text.toLowerCase().indexOf(query.toLowerCase());
    if (query.isEmpty || start < 0) {
      return Text(text, style: baseStyle);
    }
    final end = start + query.length;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(color: FlixieColors.primary),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

class SearchSummary extends StatelessWidget {
  const SearchSummary({super.key, required this.query, required this.total});

  final String query;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.search_rounded,
            color: context.colors.medium,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: TextStyle(color: context.colors.light, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Search for '),
                    TextSpan(
                      text: '‘$query’',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$total ${total == 1 ? 'result' : 'results'}',
                style: TextStyle(color: context.colors.medium, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget searchRetryMessage(String message, VoidCallback retry) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    );
