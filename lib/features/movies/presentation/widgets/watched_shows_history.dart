import 'watch_history_card.dart';
import 'write_review_sheet.dart';
import 'package:flixie_app/models/review.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/load_failure_notice.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';

class WatchedShowsHistory extends StatefulWidget {
  const WatchedShowsHistory(
      {super.key, required this.query, required this.sortBy, this.onCountChanged});
  final String query, sortBy;
  final ValueChanged<int>? onCountChanged;
  @override
  State<WatchedShowsHistory> createState() => _WatchedShowsHistoryState();
}

class _WatchedShowsHistoryState extends State<WatchedShowsHistory> {
  List<Map<String, dynamic>> shows = [];
  bool loading = true, failed = false;
  int generation = 0;
  String? viewer;
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<AuthProvider>().dbUser?.id;
    if (!initialized || id != viewer) {
      initialized = true;
      viewer = id;
      shows = [];
      load();
    }
  }

  Future<void> load() async {
    final id = viewer, request = ++generation;
    if (id == null) {
      setState(() {
        loading = false;
        failed = true;
      });
      return;
    }
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result = await UserService.getUserWatchedShows(id);
      if (!mounted || request != generation) return;
      setState(
          () => shows = result.where((s) => s['removed'] != true).toList());
      widget.onCountChanged?.call(shows.length);
    } catch (_) {
      if (mounted && request == generation) setState(() => failed = true);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  String title(Map s) =>
      ((s['show'] as Map?)?['title'] ?? s['title'] ?? 'Untitled show')
          .toString();
  String date(Map s) => (s['watchedAt'] ?? s['createdAt'] ?? '').toString();
  @override
  Widget build(BuildContext context) {
    final visible = shows
        .where(
            (s) => title(s).toLowerCase().contains(widget.query.toLowerCase()))
        .toList()
      ..sort((a, b) => switch (widget.sortBy) {
            'titleAsc' => title(a).compareTo(title(b)),
            'titleDesc' => title(b).compareTo(title(a)),
            'dateAsc' => date(a).compareTo(date(b)),
            _ => date(b).compareTo(date(a)),
          });
    return Column(children: [
      if (loading) const LinearProgressIndicator(),
      if (failed)
        LoadFailureNotice(
            message: 'Couldn’t load your watched shows.',
            onRetry: load,
            retrying: loading),
      Expanded(
          child: RefreshIndicator(
              onRefresh: load,
              child: visible.isEmpty
                  ? ListView(physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24), children: [
                        if (!loading && !failed) Text(widget.query.isEmpty
                            ? 'No watched shows yet.' : 'No matching shows.')])
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: .48,
                        crossAxisSpacing: 12, mainAxisSpacing: 12),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final show = visible[index];
                        final details = show['show'] as Map? ?? show;
                        final id = show['showId'] ?? details['id'];
                        final watched = DateTime.tryParse(date(show));
                        return WatchHistoryCard(
                          title: title(show),
                          posterPath: (details['posterPath'] ?? details['posterImgUrl'])?.toString(),
                          rating: (show['rating'] as num?)?.toDouble(),
                          formattedDate: watched == null ? '' : DateFormat('d MMM yyyy').format(watched),
                          onTap: () { if (id is int) context.push('/shows/$id'); },
                          onWriteReview: id is int && viewer != null
                              ? () => writeReview(id, title(show), (show['rating'] as num?)?.toDouble()) : null,
                        );
                      }))),
    ]);
  }

  Future<void> writeReview(int id, String name, double? rating) async {
    final userId = viewer;
    if (userId == null) return;
    await showModalBottomSheet<Review>(
      context: context, useRootNavigator: true, useSafeArea: true,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => WriteReviewSheet(showId: id, mediaTitle: name,
          initialRating: rating, userId: userId, onSubmitted: (_) {
            if (mounted && viewer == userId) {
              final auth = context.read<AuthProvider>();
              auth.invalidateCachedReviews();
              auth.markActivityChanged();
            }
          }));
    if (mounted && viewer == userId) await load();
  }
}
