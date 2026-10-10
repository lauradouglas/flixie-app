import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class PersonBiography extends StatefulWidget {
  const PersonBiography({super.key, required this.biography});
  final String biography;
  @override
  State<PersonBiography> createState() => _PersonBiographyState();
}

class _PersonBiographyState extends State<PersonBiography> {
  bool _expanded = false;
  String get bio => widget.biography;
  @override
  Widget build(BuildContext context) {
    const previewLines = 4;
    final shouldCollapse = bio.length > 380;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biography',
            style: TextStyle(
              color: context.colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded || !shouldCollapse
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              bio,
              maxLines: previewLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.light,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            secondChild: Text(
              bio,
              style: TextStyle(
                color: context.colors.light,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          if (shouldCollapse) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: FlixieColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
