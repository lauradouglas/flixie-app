import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_requests_poster_placeholder.dart';

class WatchRequestCard extends StatelessWidget {
  const WatchRequestCard({
    super.key,
    required this.request,
    required this.myUserId,
    required this.formattedDate,
    this.onMovieTap,
    this.onRefresh,
  });

  final WatchRequest request;
  final String myUserId;
  final String formattedDate;
  final VoidCallback? onMovieTap;
  final VoidCallback? onRefresh;

  Color get _statusColor {
    if (request.isAccepted) return FlixieColors.success;
    if (request.isDeclined) return FlixieColors.danger;
    return FlixieColors.warning;
  }

  IconData get _statusIcon {
    if (request.isAccepted) return Icons.check_circle_outline;
    if (request.isDeclined) return Icons.cancel_outlined;
    return Icons.hourglass_top_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final other = request.otherUser(myUserId);
    final isSent = request.requesterId == myUserId;
    final movie = request.movie;

    final posterUrl = movie?.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie!.posterPath}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster
            GestureDetector(
              onTap: onMovieTap,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
                child: SizedBox(
                  width: 80,
                  child: posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const WatchRequestPosterPlaceholder(),
                          errorWidget: (_, __, ___) =>
                              const WatchRequestPosterPlaceholder(),
                        )
                      : const WatchRequestPosterPlaceholder(),
                ),
              ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Movie title
                    GestureDetector(
                      onTap: onMovieTap,
                      child: Text(
                        movie?.title ?? 'Unknown Movie',
                        style: TextStyle(
                          color: onMovieTap != null
                              ? FlixieColors.primary
                              : FlixieColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decorationColor: FlixieColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Direction label + username
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 13),
                        children: [
                          TextSpan(text: isSent ? 'To: ' : 'From: '),
                          TextSpan(
                            text: other?.username ?? '-',
                            style: const TextStyle(
                                color: FlixieColors.light,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    // Message
                    if (request.message != null &&
                        request.message!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${request.message}"',
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (request.movieId != null) ...[
                      const SizedBox(height: 8),
                      _RequestProviderCompatibility(
                        movieId: request.movieId!,
                        myUserId: myUserId,
                        otherUserId: other?.id,
                      ),
                    ],
                    const Spacer(),
                    // Accept/Decline buttons for pending requests (if recipient)
                    if (request.isPending && request.recipientId == myUserId)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showMessageDialog(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FlixieColors.primary,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Accept',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _showMessageDialog(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FlixieColors.light,
                                side: BorderSide(
                                    color: FlixieColors.medium
                                        .withValues(alpha: 0.5)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Decline',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    // Status badge + date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _statusColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon, size: 12, color: _statusColor),
                              const SizedBox(width: 4),
                              Text(
                                request.status,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (formattedDate.isNotEmpty)
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(BuildContext context, bool accept) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept
            ? 'Add a message for acceptance'
            : 'Add a message for decline'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      _handleAction(context, accept, result);
    }
  }

  void _handleAction(BuildContext context, bool accept, String message) async {
    final status = accept ? 'ACCEPTED' : 'DECLINED';
    try {
      await RequestService.updateRequest(request.id, status, message: message);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Request accepted successfully.'
              : 'Request declined successfully.'),
          backgroundColor: FlixieColors.success,
        ),
      );
      onRefresh?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Failed to accept. Please try again.'
              : 'Failed to decline. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }
}

class _RequestProviderCompatibility extends StatefulWidget {
  const _RequestProviderCompatibility({
    required this.movieId,
    required this.myUserId,
    required this.otherUserId,
  });

  final int movieId;
  final String myUserId;
  final String? otherUserId;

  @override
  State<_RequestProviderCompatibility> createState() =>
      _RequestProviderCompatibilityState();
}

class _RequestProviderCompatibilityState
    extends State<_RequestProviderCompatibility> {
  bool _started = false;
  bool _loading = true;
  List<WatchProvider> _available = [];
  Set<int> _mine = {};
  Set<int> _theirs = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final otherId = widget.otherUserId;
    if (otherId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final region =
        context.read<AuthProvider>().dbUser?.countryAbbreviation ?? 'GB';
    try {
      final results = await Future.wait([
        MovieService().getMovieWatchProviders(widget.movieId, region),
        UserService.getUserWatchProviders(widget.myUserId),
        UserService.getUserWatchProviders(otherId),
      ]);
      if (!mounted) return;
      setState(() {
        _available =
            results[0].where((provider) => provider.isStreaming).toList();
        _mine = results[1].map((provider) => provider.id).toSet();
        _theirs = results[2].map((provider) => provider.id).toSet();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Text(
        'Checking streaming services…',
        style: TextStyle(color: FlixieColors.medium, fontSize: 11),
      );
    }
    if (_available.isEmpty) {
      return const Text(
        'Not on a streaming subscription',
        style: TextStyle(color: FlixieColors.medium, fontSize: 11),
      );
    }
    final shared = _available
        .where((provider) =>
            _mine.contains(provider.id) && _theirs.contains(provider.id))
        .toList();
    return Row(
      children: [
        Icon(
          shared.isEmpty ? Icons.tv_off_outlined : Icons.live_tv_rounded,
          size: 14,
          color: shared.isEmpty ? FlixieColors.medium : FlixieColors.success,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            shared.isEmpty
                ? 'No streaming service you both have'
                : 'You both have ${shared.map((provider) => provider.providerName).join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  shared.isEmpty ? FlixieColors.medium : FlixieColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
