import 'package:flutter/material.dart';

/// Keeps the selected title recognisable throughout registration and its editor.
class SignupTitleContext extends StatelessWidget {
  const SignupTitleContext(
      {super.key,
      required this.title,
      required this.isShow,
      this.poster,
      this.posterWidth = 48});
  final String title;
  final bool isShow;
  final String? poster;
  final double posterWidth;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
            width: posterWidth,
            height: posterWidth * 1.5,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: poster?.isNotEmpty == true
                    ? Image.network(
                        poster!.startsWith('http')
                            ? poster!
                            : 'https://image.tmdb.org/t/p/w154$poster',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) =>
                            Icon(isShow ? Icons.tv : Icons.movie_outlined),
                      )
                    : Icon(isShow ? Icons.tv : Icons.movie_outlined))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(isShow ? 'TV show' : 'Film'),
        ])),
      ]));
}
