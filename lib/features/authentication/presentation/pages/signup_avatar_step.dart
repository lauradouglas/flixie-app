import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'auth_ui.dart';

class SignupAvatarStep extends StatefulWidget {
  const SignupAvatarStep(
      {super.key,
      required this.avatars,
      required this.selectedId,
      required this.onSelected,
      required this.onContinue,
      required this.onBack,
      required this.onRetry,
      this.loading = false,
      this.saving = false,
      this.error,
      this.profileBadges = const []});
  final List<ProfileAvatar> avatars;
  final int? selectedId;
  final ValueChanged<ProfileAvatar> onSelected;
  final VoidCallback onContinue, onBack, onRetry;
  final bool loading, saving;
  final String? error;
  final List<String> profileBadges;
  @override
  State<SignupAvatarStep> createState() => _SignupAvatarStepState();
}

class _SignupAvatarStepState extends State<SignupAvatarStep> {
  String category = 'All';
  String categoryOf(ProfileAvatar a) {
    if (a.key.startsWith('girl') || a.key.startsWith('guy')) return 'People';
    if (const {
      'axolot',
      'cat',
      'corgi',
      'dinosaur',
      'cavalier',
      'lhasa-apso',
      'frog',
      'ginger-cat',
      'goldie'
    }.contains(a.key)) {
      return 'Animals';
    }
    return 'Playful';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final selected =
        widget.avatars.where((a) => a.id == widget.selectedId).firstOrNull;
    final visible = widget.avatars
        .where((a) => category == 'All' || categoryOf(a) == category)
        .toList();
    Widget portrait(ProfileAvatar a, double size) => ProfileAvatarView(
        avatar: a,
        fallbackText: a.displayName.characters.firstOrNull ?? '?',
        fallbackColor: FlixieColors.primary,
        size: size,
        useFullSize: true,
        profileBadges: widget.profileBadges);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
          title: const FlixieWordmark(fontSize: 24),
          centerTitle: true,
          leading: IconButton(
              onPressed: widget.saving ? null : widget.onBack,
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded))),
      body: SafeArea(
          top: false,
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('A little more you.',
                                style: text.headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            const Text(
                                'Choose your avatar. You can change it anytime.'),
                            const SizedBox(height: 20),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  'All',
                                  'Animals',
                                  'People',
                                  'Playful'
                                ]
                                    .map((c) => ChoiceChip(
                                        label: Text(c),
                                        selected: category == c,
                                        showCheckmark: false,
                                        onSelected: widget.saving
                                            ? null
                                            : (_) =>
                                                setState(() => category = c)))
                                    .toList()),
                            const SizedBox(height: 24),
                            if (widget.loading)
                              const Center(child: CircularProgressIndicator())
                            else if (widget.error != null ||
                                widget.avatars.isEmpty) ...[
                              Text(widget.error ??
                                  'No profile avatars are currently available.'),
                              TextButton(
                                  onPressed: widget.onRetry,
                                  child: const Text('Try again')),
                            ] else
                              LayoutBuilder(builder: (context, constraints) {
                                final columns =
                                    constraints.maxWidth >= 480 ? 4 : 3;
                                final width = (constraints.maxWidth -
                                        (columns - 1) * 16) /
                                    columns;
                                return Wrap(
                                    spacing: 16,
                                    runSpacing: 20,
                                    children: visible.map((a) {
                                      final active = a.id == widget.selectedId;
                                      return SizedBox(
                                          width: width,
                                          child: Semantics(
                                              button: true,
                                              selected: active,
                                              label: a.displayName,
                                              child: InkWell(
                                                onTap: widget.saving
                                                    ? null
                                                    : () =>
                                                        widget.onSelected(a),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    child: Column(children: [
                                                      Stack(children: [
                                                        AnimatedContainer(
                                                            duration: MediaQuery
                                                                    .disableAnimationsOf(
                                                                        context)
                                                                ? Duration.zero
                                                                : const Duration(
                                                                    milliseconds:
                                                                        180),
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(4),
                                                            decoration: BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                    color: active
                                                                        ? FlixieColors
                                                                            .primary
                                                                        : Colors
                                                                            .transparent,
                                                                    width: 2)),
                                                            child: portrait(
                                                                a, width - 20)),
                                                        if (active)
                                                          const Positioned(
                                                              right: 0,
                                                              top: 0,
                                                              child: Icon(
                                                                  Icons
                                                                      .check_circle,
                                                                  color: FlixieColors
                                                                      .primary,
                                                                  size: 24)),
                                                      ]),
                                                      const SizedBox(height: 8),
                                                      Text(a.displayName,
                                                          style:
                                                              text.labelMedium,
                                                          textAlign:
                                                              TextAlign.center),
                                                    ])),
                                              )));
                                    }).toList());
                              }),
                          ]))),
              Container(
                  decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      border:
                          Border(top: BorderSide(color: colors.tabBarBorder))),
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Semantics(
                        liveRegion: true,
                        child: Row(children: [
                          if (selected != null) ...[
                            portrait(selected, 44),
                            const SizedBox(width: 12)
                          ],
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    selected?.displayName ??
                                        'Pick your favourite',
                                    style: text.titleSmall),
                                Text(
                                    selected == null
                                        ? 'This is how you’ll appear around Flixie.'
                                        : 'Your avatar · change it anytime',
                                    style: text.bodySmall),
                              ])),
                        ])),
                    const SizedBox(height: 14),
                    PrimaryButton(
                        label: 'Continue',
                        isLoading: widget.saving,
                        onPressed:
                            selected == null || widget.saving || widget.loading
                                ? null
                                : widget.onContinue),
                    const SizedBox(height: 8),
                    Text('Next: find your kind of films & series',
                        style: text.bodySmall, textAlign: TextAlign.center),
                  ])),
            ]),
          ))),
    );
  }
}
