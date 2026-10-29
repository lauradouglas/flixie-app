import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../data/milestone_badge_service.dart';
import '../../models/milestone_badge.dart';
import 'film_milestone_badge.dart';

class ProfileMilestoneBadges extends StatefulWidget {
  const ProfileMilestoneBadges(
      {super.key,
      required this.userId,
      this.editable = false,
      this.identityBadges,
      this.service = const MilestoneBadgeService()});
  final Widget? identityBadges;
  final String userId;
  final bool editable;
  final MilestoneBadgeService service;
  @override
  State<ProfileMilestoneBadges> createState() => _ProfileMilestoneBadgesState();
}

class _ProfileMilestoneBadgesState extends State<ProfileMilestoneBadges> {
  List<MilestoneBadge> _badges = [];
  int _generation = 0;
  String? _viewer;
  AuthProvider? _auth;
  bool _failed = false, _loading = true;
  int _activityVersion = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (_auth != auth) {
      _auth?.removeListener(_accountChanged);
      _auth = auth;
      auth.addListener(_accountChanged);
      _viewer = auth.dbUser?.id;
      _activityVersion = auth.activityVersion;
      _load();
    }
  }

  void _accountChanged() {
    if (_viewer == _auth?.dbUser?.id) {
      if (_viewer == widget.userId &&
          _activityVersion != _auth?.activityVersion) {
        _activityVersion = _auth!.activityVersion;
        _load();
      }
      return;
    }
    _viewer = _auth?.dbUser?.id;
    _generation++;
    setState(() {
      _badges = [];
      _failed = false;
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileMilestoneBadges oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.service != widget.service) {
      _badges = [];
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (_viewer == null) return;
    _loading = true;
    try {
      final badges = await widget.service.load(widget.userId);
      if (mounted && generation == _generation) {
        setState(() {
          _badges = badges;
          _failed = false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _auth?.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _customise() async {
    final generation = _generation, viewer = _viewer;
    if (viewer != widget.userId) return;
    final saved = await showFlixiePromptSheet<List<MilestoneBadge>>(
        context: context,
        maxHeightFraction: .9,
        builder: (_) => ListenableBuilder(
            listenable: _auth!,
            builder: (context, child) {
              if (_auth?.dbUser?.id != viewer) {
                return const Text(
                    'Your account has changed. Close this sheet to continue.');
              }
              return MilestoneBadgePicker(
                  badges: _badges,
                  save: (ids) async {
                    if (!mounted ||
                        generation != _generation ||
                        _auth?.dbUser?.id != viewer) {
                      throw StateError('Account changed');
                    }
                    final saved = await widget.service.save(widget.userId, ids);
                    if (!mounted || _auth?.dbUser?.id != viewer) {
                      throw StateError('Account changed');
                    }
                    return saved;
                  });
            }));
    if (mounted && generation == _generation && saved != null) {
      setState(() => _badges = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _badges.where((b) => b.displayOrder != null).toList()
      ..sort((a, b) => a.displayOrder!.compareTo(b.displayOrder!));
    return Wrap(
        spacing: 12,
        runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.identityBadges != null) widget.identityBadges!,
          if (shown.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final badge in shown)
                    Tooltip(
                        message: '${badge.metal} · ${badge.label}',
                        child: FilmMilestoneBadge(badge: badge, size: 48))
                ])),
          if (widget.editable && _viewer == widget.userId)
            TextButton.icon(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard),
                onPressed: _loading
                    ? null
                    : _failed
                        ? _load
                        : _customise,
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text(
                    _loading
                        ? 'Loading badges…'
                        : _failed
                            ? 'Retry badges'
                            : 'Customise badges',
                    style: const TextStyle(fontSize: 13))),
        ]);
  }
}

class MilestoneBadgePicker extends StatefulWidget {
  const MilestoneBadgePicker(
      {super.key, required this.badges, required this.save});
  final List<MilestoneBadge> badges;
  final Future<List<MilestoneBadge>> Function(List<String>) save;
  @override
  State<MilestoneBadgePicker> createState() => _MilestoneBadgePickerState();
}

class _MilestoneBadgePickerState extends State<MilestoneBadgePicker> {
  late final List<String> _selected =
      (widget.badges.where((b) => b.displayOrder != null).toList()
            ..sort((a, b) => a.displayOrder!.compareTo(b.displayOrder!)))
          .map((b) => b.id)
          .toList();
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final badges = await widget.save(List.of(_selected));
      if (mounted) Navigator.pop(context, badges);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t save your badges. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Customise badges',
            style: TextStyle(
                color: context.colors.primaryText,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Choose up to 3 for your profile · ${_selected.length}/3',
            style: TextStyle(color: context.colors.light)),
        const SizedBox(height: 16),
        for (final badge in widget.badges)
          CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              secondary: FilmMilestoneBadge(
                  badge: badge, size: 56, locked: !badge.earned),
              title: Text(badge.label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(badge.earned
                  ? '${badge.metal[0].toUpperCase()}${badge.metal.substring(1)} · Earned'
                  : 'Unlock at ${badge.label}'),
              value: _selected.contains(badge.id),
              onChanged: _saving || !badge.earned
                  ? null
                  : (selected) {
                      if (selected == true && _selected.length >= 3) return;
                      setState(() {
                        if (selected == true) {
                          _selected.add(badge.id);
                        } else {
                          _selected.remove(badge.id);
                        }
                      });
                    }),
        const SizedBox(height: 12),
        Text(
            'Tap badges in the order you want to show them. Uncheck all to hide them. Earned badges are yours to keep.',
            style: TextStyle(
                color: context.colors.light, fontSize: 14, height: 1.5)),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
        const SizedBox(height: 20),
        Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48)),
                  child: Text(_saving ? 'Saving…' : 'Save badges'))
            ]),
      ]));
}
