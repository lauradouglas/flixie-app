import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import '../../domain/release_status.dart';

Future<bool> confirmUnreleasedMovie(
  BuildContext context, {
  String? title,
  String? releaseDate,
  String? status,
}) async {
  if (!isNotReleasedYet(date: releaseDate, status: status)) return true;
  return await showFlixiePromptSheet<bool>(
        context: context,
        builder: (sheetContext) => UnreleasedMoviePrompt(
          title: title,
          onBack: () => Navigator.of(sheetContext).pop(false),
          onContinue: () => Navigator.of(sheetContext).pop(true),
        ),
      ) ==
      true;
}

class UnreleasedMoviePrompt extends StatelessWidget {
  const UnreleasedMoviePrompt(
      {super.key, this.title, required this.onBack, required this.onContinue});
  final String? title;
  final VoidCallback onBack, onContinue;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('This film isn’t out yet',
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(
              'Our release information says ${title?.trim().isNotEmpty == true ? title : 'this film'} hasn’t been released yet. Seen an early screening? You can still log your watch.',
              style: TextStyle(
                  color: context.colors.light, fontSize: 16, height: 1.5)),
          const SizedBox(height: 16),
          Text('Do you want to continue?',
              style: TextStyle(
                  color: context.colors.light, fontSize: 16, height: 1.5)),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: onBack,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: const Text('Go back')),
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: onContinue,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: context.colors.primaryText,
                  side: BorderSide(color: context.colors.primaryText)),
              child: const Text('Log watch anyway')),
        ],
      );
}
