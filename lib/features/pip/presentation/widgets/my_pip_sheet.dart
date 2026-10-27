import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/app_icon/app_icon_service.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../../models/pip_collection.dart';
import '../controllers/pip_collection_controller.dart';

Future<void> showMyPipSheet(BuildContext context,
    {bool celebrate = false}) async {
  final controller = context.read<PipCollectionController?>();
  if (controller == null || controller.userId == null) return;
  final owner = controller.userId;
  unawaited(controller.refresh());
  await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => MyPipSheet(controller: controller, celebrate: celebrate));
  if (controller.userId == owner &&
      controller.collection.celebrationPending &&
      controller.verified) {
    try {
      await controller.acknowledge();
    } catch (_) {/* Keep notification for a later visit. */}
  }
}

class MyPipSheet extends StatefulWidget {
  const MyPipSheet(
      {super.key,
      required this.controller,
      this.celebrate = false,
      this.icons});
  final PipCollectionController controller;
  final bool celebrate;
  final AppIconService? icons;
  @override
  State<MyPipSheet> createState() => _MyPipSheetState();
}

class _MyPipSheetState extends State<MyPipSheet> {
  late String pane = widget.celebrate ? 'celebrate' : 'collection';
  late String selectedPip = widget.controller.collection.activePip;
  late final String? owner = widget.controller.userId;
  String selectedIcon = 'default', currentIcon = 'default';
  bool supported = false, iconLoaded = false, busy = false;
  String? error, feedback;
  String successTitle = 'Pip saved';
  AppIconService get icons => widget.icons ?? AppIconService.instance;
  PipCollectionController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  Future<void> _loadIcon() async {
    try {
      final status = await icons.status();
      if (mounted) {
        setState(() {
          supported = status['supported'] == true;
          iconLoaded = true;
          currentIcon =
              selectedIcon = status['selected'] as String? ?? 'default';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          iconLoaded = true;
          supported = false;
        });
      }
    }
  }

  void change(String value) {
    setState(() {
      pane = value;
      error = null;
      feedback = null;
      selectedPip = c.collection.activePip;
      selectedIcon = currentIcon;
    });
  }

  Future<void> save({required bool icon}) async {
    if (busy || owner != c.userId) return;
    setState(() {
      busy = true;
      error = null;
      feedback = null;
    });
    try {
      if (icon) {
        await icons.select(selectedIcon);
        if (mounted && owner == c.userId) currentIcon = selectedIcon;
      } else {
        await c.select(selectedPip);
      }
      if (mounted && owner == c.userId) {
        setState(() {
          pane = 'collection';
          successTitle = icon ? 'App icon saved' : 'Pip saved';
          feedback = icon
              ? 'Your app icon has changed on this device.'
              : '${PipCollection.label(selectedPip)} is now in use.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = icon
            ? 'Your icon hasn’t changed. Your reward and choice are safe. Try again.'
            : 'Couldn’t save your Pip. Your choice is still here. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget art(String pip, {double size = 150}) =>
      Image.asset(PipCollection.asset(pip),
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: PipCollection.label(pip));
  Widget iconArt(String key, {double size = 64}) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
          switch (key) {
            'pipPeeksIn' => 'assets/icon/pip_cosmetics/pip_peeks_in.png',
            'pipHoodie' => 'assets/icon/pip_hoodie.png',
            'pipGlasses' => 'assets/icon/pip_glasses.png',
            _ => 'assets/icon/flixie_icon_1024.png'
          },
          width: size,
          height: size,
          fit: BoxFit.contain));
  Widget primary(String label, VoidCallback? action) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: busy ? null : action,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              child: Text(label, textAlign: TextAlign.center))));
  Widget choice(String label, String sub, Widget image, bool selected,
          VoidCallback action) =>
      Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
              selected: selected,
              child: OutlinedButton(
                  onPressed: busy ? null : action,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      side: BorderSide(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: selected ? 2 : 1)),
                  child: Row(children: [
                    image,
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(label),
                          Text(sub,
                              style: Theme.of(context).textTheme.bodySmall)
                        ])),
                    const SizedBox(width: 6),
                    Icon(selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off)
                  ]))));
  Widget title(String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(value, style: Theme.of(context).textTheme.headlineSmall));
  List<Widget> rules() => [
        title('Your first film together'),
        const Text(
            'Both people unlock Cinema Club Pip and the Pip peeks in app icon. Already friends on Flixie? That counts too.'),
        const SizedBox(height: 16),
        const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.movie_outlined),
            title: Text('Save a film you watched together'),
            subtitle: Text('Choose a friend, or share a watch invitation.')),
        const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.people_outline),
            title: Text('They confirm their own watch'),
            subtitle: Text(
                'Their own entry. Ratings are optional and don’t need to match.')),
        const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.redeem_outlined),
            title: Text('You both unlock the collection'),
            subtitle: Text(
                'No public review, extra invites or deadline. Yours to keep.')),
        const Text(
            'Sending an invitation alone doesn’t unlock rewards. Your watch stays saved while you wait.'),
        primary('Find a film to log together', () {
          Navigator.pop(context);
          context.push('/search?focus=1');
        }),
      ];
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final owned = c.collection.cinemaUnlocked;
        final canChoose = c.verified && owned;
        final same = owner != null && owner == c.userId;
        final founder =
            AppIconService.eligible(context.watch<AuthProvider?>()?.dbUser);
        final content = <Widget>[];
        if (!same) {
          content.add(const Text(
              'Your account changed. Close this sheet to see your own collection.'));
        } else if ((pane == 'icon' && !iconLoaded) ||
            (pane == 'outfit' && c.loading && !c.verified)) {
          content.addAll([
            const Text('Loading your saved look…'),
            const SizedBox(height: 16),
            const LinearProgressIndicator()
          ]);
        } else if (pane == 'rules') {
          content.addAll(rules());
        } else if (pane == 'celebrate' && owned) {
          content.addAll([
            title('You’re in the Cinema Club.'),
            Center(child: art('cinemaClub')),
            const SizedBox(height: 12),
            const Text(
                'You’ve both confirmed a shared film. Cinema Club Pip and Pip peeks in are now yours.'),
            const SizedBox(height: 20),
            Row(children: [
              iconArt('pipPeeksIn'),
              const SizedBox(width: 16),
              const Expanded(
                  child: Text(
                      'Two little rewards. Choose either, both, or keep your current look.'))
            ]),
            primary('Choose my look', () => change('collection')),
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14)),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Keep my current look',
                            textAlign: TextAlign.center)))),
          ]);
        } else if (pane == 'outfit') {
          content.addAll([
            title('Choose your Pip'),
            const Text(
                'Your companion in your diary and after a shared watch.'),
            const SizedBox(height: 16),
            Center(child: art(selectedPip)),
            choice(
                'Classic Pip',
                'Always available',
                art('classic', size: 56),
                selectedPip == 'classic',
                () => setState(() => selectedPip = 'classic')),
            choice(
                'Cinema Club',
                owned
                    ? 'Unlocked'
                    : c.verified
                        ? 'Locked · your first shared film'
                        : 'Refresh to check ownership',
                art('cinemaClub', size: 56),
                selectedPip == 'cinemaClub',
                () => setState(() => selectedPip = 'cinemaClub')),
            if (c.collection.ogUnlocked)
              choice(
                  'OG Pip',
                  'First 100 · yours from the beginning',
                  art('og', size: 56),
                  selectedPip == 'og',
                  () => setState(() => selectedPip = 'og')),
            if (selectedPip == 'cinemaClub' && !owned)
              primary(c.verified ? 'How to unlock' : 'Refresh rewards',
                  c.verified ? () => change('rules') : () => c.refresh())
            else
              primary(
                  error == null ? 'Use this Pip' : 'Try again',
                  (selectedPip == 'cinemaClub' && !canChoose) ||
                          (selectedPip == 'og' &&
                              (!c.verified || !c.collection.ogUnlocked))
                      ? null
                      : () => save(icon: false)),
            if ((owned || c.collection.ogUnlocked) && !c.verified)
              TextButton(
                  onPressed: () => c.refresh(),
                  child: const Text('Refresh rewards to choose this Pip')),
            const SizedBox(height: 12),
            const Text('Your profile photo and badge border stay as they are.'),
          ]);
        } else if (pane == 'icon') {
          content.addAll([
            title('Choose your app icon'),
            const Text(
                'For this device’s Home Screen. You can switch back any time.'),
            const SizedBox(height: 20),
            Center(child: iconArt(selectedIcon, size: 100)),
            const SizedBox(height: 12),
            if (!iconLoaded)
              const LinearProgressIndicator()
            else if (!supported)
              const Text(
                  'Changing the app icon isn’t available on this device. Your reward remains in your collection.'),
            choice(
                'Classic',
                'Always available',
                iconArt('default', size: 56),
                selectedIcon == 'default',
                () => setState(() => selectedIcon = 'default')),
            choice(
                'Pip peeks in',
                owned
                    ? 'Unlocked'
                    : c.verified
                        ? 'Locked · your first shared film'
                        : 'Refresh to check ownership',
                iconArt('pipPeeksIn', size: 56),
                selectedIcon == 'pipPeeksIn',
                () => setState(() => selectedIcon = 'pipPeeksIn')),
            if (founder) ...[
              choice(
                  'Pip in 3D',
                  'First 100 & Founder',
                  iconArt('pipGlasses', size: 56),
                  selectedIcon == 'pipGlasses',
                  () => setState(() => selectedIcon = 'pipGlasses')),
              choice(
                  'Pip in a hoodie',
                  'First 100 & Founder',
                  iconArt('pipHoodie', size: 56),
                  selectedIcon == 'pipHoodie',
                  () => setState(() => selectedIcon = 'pipHoodie')),
            ],
            if (selectedIcon == 'pipPeeksIn' && !owned)
              primary(c.verified ? 'How to unlock' : 'Refresh rewards',
                  c.verified ? () => change('rules') : () => c.refresh())
            else
              primary(
                  error == null ? 'Use this icon' : 'Try again',
                  !supported || (selectedIcon == 'pipPeeksIn' && !canChoose)
                      ? null
                      : () => save(icon: true)),
            const SizedBox(height: 12),
            const Text('Your device may show a system confirmation.'),
          ]);
        } else {
          content.addAll([
            if (feedback != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: .65, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: ExcludeSemantics(
                              child: Icon(Icons.check_circle_rounded,
                                  size: 40,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(successTitle,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text(feedback!),
                            ])),
                      ]),
                ),
              ),
            title('Make Flixie yours.'),
            Center(child: art(c.collection.activePip, size: 132)),
            Text(PipCollection.label(c.collection.activePip),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pip outfit'),
                subtitle: Text(
                    '${PipCollection.label(c.collection.activePip)} · in use'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => change('outfit')),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App icon'),
                subtitle: const Text('Choose for this device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => change('icon')),
            const Divider(height: 24),
            Row(children: [
              Icon(owned
                  ? Icons.check_circle_outline
                  : c.verified
                      ? Icons.lock_outline
                      : Icons.cloud_off_outlined),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Cinema Club collection',
                      style: Theme.of(context).textTheme.titleMedium))
            ]),
            const SizedBox(height: 10),
            Text(owned
                ? 'Unlocked after a confirmed shared film. Yours to keep.'
                : c.verified
                    ? 'Log your first film together to unlock two rewards for both people.'
                    : 'Connect to check your collection. Classic Pip is always available.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: () => change(owned ? 'celebrate' : 'rules'),
                child: Text(owned ? 'View your rewards' : 'How to unlock',
                    textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 16),
            Text('Find My Pip in Settings under Personalisation.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
          ]);
        }
        return PopScope(
            canPop: !busy,
            child: ConstrainedBox(
                key: const ValueKey('my-pip-content-sheet'),
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .85),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                      child: Row(children: [
                        if (pane != 'collection')
                          IconButton(
                              tooltip: 'Back to My Pip',
                              onPressed:
                                  busy ? null : () => change('collection'),
                              icon: const Icon(Icons.arrow_back)),
                        const Expanded(child: Text('My Pip')),
                        IconButton(
                            tooltip: 'Close',
                            onPressed:
                                busy ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close))
                      ])),
                  if (busy || c.loading) const LinearProgressIndicator(),
                  Flexible(
                      child: SingleChildScrollView(
                          key: ValueKey('pip-page-$pane'),
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c.error != null) ...[
                                  Text(c.error!),
                                  TextButton(
                                      onPressed: () => c.refresh(),
                                      child: const Text('Retry rewards')),
                                  const SizedBox(height: 12)
                                ],
                                ...content,
                                if (error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Semantics(
                                          liveRegion: true,
                                          child: Text(error!,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error)))),
                                if (pane == 'outfit' || pane == 'icon')
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => change('collection'),
                                      child: const Text('Cancel')),
                              ]))),
                ])));
      });
}
