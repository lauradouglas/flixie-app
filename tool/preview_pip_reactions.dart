import 'pip_preview_assets.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/pip_reaction.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_reaction_bubble.dart';

void main() => runApp(DefaultAssetBundle(
    bundle: PipPreviewAssets(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const PipPreview(),
    )));

class PipPreview extends StatefulWidget {
  const PipPreview({super.key});
  @override
  State<PipPreview> createState() => _PipPreviewState();
}

class _PipPreviewState extends State<PipPreview> {
  ActivityReaction? selected;
  bool opened = false;
  Future<void> open() async {
    final result = await showActivityReactionBubble(context, context,
        current: selected?.emoji, canReply: true);
    if (mounted && result is ActivityReaction) {
      setState(() => selected = result);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!opened) {
      opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => open());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pip reactions')),
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (selected != null) ...[
            PipReaction(selected!.emoji, size: 96),
            const SizedBox(height: 12),
            Text(selected!.label),
            const SizedBox(height: 24),
          ],
          FilledButton(onPressed: open, child: const Text('React with Pip')),
        ])),
      );
}
