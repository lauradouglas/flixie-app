import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import '../../data/person_detail_service.dart';
import '../controllers/person_detail_controller.dart';
import '../person_detail_action_flow.dart';
import '../person_filmography_selection.dart';
import '../widgets/person_detail/person_detail_hero.dart';
import '../widgets/person_detail/person_photos.dart';
import '../widgets/person_detail/person_biography.dart';
import '../widgets/person_detail/person_credit_stats.dart';
import '../widgets/person_detail/person_known_for.dart';
import '../widgets/person_detail/person_empty_section.dart';
import '../widgets/person_detail/person_filmography.dart';

class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen(
      {super.key,
      required this.personId,
      this.source = DetailSource.unknown,
      this.parentContentId,
      this.parentContentType,
      this.service = const PersonDetailService()});
  final String personId;
  final DetailSource source;
  final int? parentContentId;
  final String? parentContentType;
  final PersonDetailService service;
  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late final AuthProvider _auth;
  late PersonDetailController _controller;
  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_syncViewer);
    _createController();
  }

  void _createController() {
    _controller = PersonDetailController(
        personId: widget.personId,
        viewer: _auth.dbUser,
        service: widget.service);
    _controller.addListener(_onChanged);
    final id = int.tryParse(widget.personId);
    if (id != null && id > 0) {
      context.read<AnalyticsController?>()?.personOpened(
          personId: id,
          source: widget.source.value,
          parentContentId: widget.parentContentId,
          parentContentType: widget.parentContentType);
    }
    unawaited(_controller.load().then((_) async {
      if (!mounted || _auth.dbUser == null || _controller.person == null) return;
      if (GuestAccess.takeAction('/people/${widget.personId}') == 'favorite' && !_controller.favorite) {
        await togglePersonFavorite(context, _controller);
      }
    }));
  }

  void _syncViewer() => _controller.selectViewer(_auth.dbUser);
  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PersonDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId ||
        oldWidget.service != widget.service) {
      _controller.dispose();
      _createController();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncViewer);
    _controller.dispose();
    super.dispose();
  }

  void _openCredit(int id, String type) => context.push(type == 'tv'
      ? showDetailPath(id, source: DetailSource.personCredits)
      : movieDetailPath(id, source: DetailSource.personCredits));
  void _openPhoto(int index) {
    final person = _controller.person;
    if (person == null || _controller.images.isEmpty) return;
    Navigator.of(context).push(PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: PersonPhotoViewer(
                personName: person.name,
                images: _controller.images,
                initialIndex: index))));
  }

  void _openPhotoGrid() {
    final person = _controller.person;
    if (person == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            PersonPhotoGridScreen(person: person, images: _controller.images)));
  }

  void _showCredits(List<PersonFilmCredit> credits, String label) {
    unawaited(showPersonCredits(context,
        credits: credits, roleLabel: label, onOpen: _openCredit));
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) {
      return Scaffold(
          backgroundColor: context.colors.background,
          body: const SafeArea(child: MediaDetailScreenSkeleton()));
    }
    final person = _controller.person;
    if (_controller.error != null || person == null) {
      return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
              backgroundColor: context.colors.background,
              leading: const FlixieBackButton()),
          body: Center(
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: context.colors.danger, size: 56),
                            const SizedBox(height: 16),
                            Text('Failed to load person',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(_controller.error ?? 'Unknown error',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            ElevatedButton(
                                onPressed: _controller.load,
                                child: const Text('Retry')),
                          ])))));
    }
    final credits = _controller.credits;
    return Scaffold(
        backgroundColor: context.colors.background,
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: PersonDetailHero(
                  person: person,
                  images: _controller.images,
                  isFavorite: _controller.favorite,
                  favoriteLoading: _controller.saving,
                  onFavorite: () =>
                      unawaited(togglePersonFavorite(context, _controller)),
                  onOpenPhoto: _openPhoto,
                  onLaunch: (url) => unawaited(launchPersonLink(url)))),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        if (credits != null)
                          PersonCreditStats(
                              credits: credits,
                              allCredits: _controller.allCredits),
                        const SizedBox(height: 24),
                        if (credits != null)
                          PersonKnownForSection(
                              credits: credits,
                              library: _controller.library,
                              onOpen: _openCredit),
                        if (credits != null) const SizedBox(height: 24),
                        PersonPhotosSection(
                            images: _controller.images,
                            loading: _controller.imagesLoading,
                            onViewAll: _openPhotoGrid,
                            onOpen: _openPhoto),
                        if (_controller.imagesLoading ||
                            _controller.images.isNotEmpty)
                          const SizedBox(height: 28),
                        if (person.biography?.isNotEmpty ?? false)
                          PersonBiography(
                              key: ValueKey(person.id),
                              biography: person.biography!)
                        else
                          const PersonEmptySection(
                              'No biography yet',
                              'Biography details will appear here when available.',
                              Icons.person_outline),
                        if (credits != null) ...[
                          const SizedBox(height: 32),
                          PersonFilmographySection(
                              credits: _controller.allCredits,
                              library: _controller.library,
                              viewerId: _controller.viewerId,
                              onOpen: _openCredit,
                              onViewAll: _showCredits),
                        ],
                        const SizedBox(height: 32),
                      ]))),
        ]));
  }
}
