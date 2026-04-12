import 'package:flutter/material.dart';

import '../../models/friendship.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../services/request_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

class MovieWatchRequestSheet extends StatefulWidget {
  const MovieWatchRequestSheet({
    super.key,
    required this.movieId,
    required this.movieTitle,
    required this.requesterId,
    required this.friends,
    required this.onSuccess,
    required this.onError,
  });

  final int? movieId;
  final String? movieTitle;
  final String requesterId;
  final List<Friendship> friends;
  final VoidCallback onSuccess;
  final VoidCallback onError;

  @override
  State<MovieWatchRequestSheet> createState() => _MovieWatchRequestSheetState();
}

class _MovieWatchRequestSheetState extends State<MovieWatchRequestSheet> {
  final _messageController = TextEditingController();
  bool _isGroupMode = false;
  String? _selectedFriendId;
  String? _selectedGroupId;
  bool _isSending = false;

  List<Group> _groups = [];
  bool _loadingGroups = false;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final groups = await GroupService.getUserGroups(widget.requesterId);
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final canSend =
        _isGroupMode ? _selectedGroupId != null : _selectedFriendId != null;
    if (!canSend || _isSending) return;
    setState(() => _isSending = true);
    try {
      if (_isGroupMode) {
        // Legacy fallback: POST /groups/:groupId/send-request
        // The response may now include a conversationId from the updated backend.
        final result = await GroupService.sendWatchRequest(
          _selectedGroupId!,
          widget.requesterId,
          _messageController.text.trim(),
          'MOVIE',
          widget.movieId!,
        );
        final conversationId = result?['conversationId'] as String?;
        logger.d('[WatchRequest] group send result: $result, '
            'conversationId: $conversationId');
      } else {
        final result = await RequestService.sendRequest({
          'requesterId': widget.requesterId,
          'recipientId': _selectedFriendId,
          'movieId': widget.movieId,
          'message': _messageController.text.trim(),
          'type': 'MOVIE_WATCH_REQUEST',
        });
        final notification = result?['notification'] as Map<String, dynamic>?;
        logger.d('[WatchRequest] notification created: $notification');
      }
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      logger.e('Failed to send watch request: $e');
      if (mounted) setState(() => _isSending = false);
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFriends = widget.friends.isNotEmpty;
    final hasGroups = _groups.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite to Watch',
                style: Theme.of(context).textTheme.titleLarge),
            if (widget.movieTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.movieTitle!,
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 14),
              ),
            ],
            const SizedBox(height: 20),
            // Friend / Group toggle
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F2033),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _ModeTab(
                    label: 'A Friend',
                    selected: !_isGroupMode,
                    onTap: () => setState(() {
                      _isGroupMode = false;
                      _selectedGroupId = null;
                    }),
                  ),
                  _ModeTab(
                    label: 'A Group',
                    selected: _isGroupMode,
                    onTap: () => setState(() {
                      _isGroupMode = true;
                      _selectedFriendId = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!_isGroupMode) ...[
              const Text(
                'SELECT A FRIEND',
                style: TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              if (!hasFriends)
                const Text(
                  'Add some friends to invite them to watch',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                )
              else
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.friends.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final friend = widget.friends[i].friendUser;
                      if (friend == null) return const SizedBox.shrink();
                      final isSelected = _selectedFriendId == friend.id;
                      final iconColor = friend.iconColor;
                      final hex = ((iconColor?['hexCode'] ?? iconColor?['hex'])
                                  as String? ??
                              '')
                          .replaceAll('#', '');
                      final pillColor = hex.isNotEmpty
                          ? Color(int.tryParse('0xFF$hex') ??
                              FlixieColors.primary.toARGB32())
                          : FlixieColors.primary;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedFriendId = friend.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? pillColor
                                : pillColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? pillColor
                                  : pillColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            friend.displayName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : FlixieColors.light,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ] else ...[
              const Text(
                'SELECT A GROUP',
                style: TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingGroups)
                const SizedBox(
                  height: 44,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (!hasGroups)
                const Text(
                  "You're not in any groups yet",
                  style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                )
              else
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final group = _groups[i];
                      final isSelected = _selectedGroupId == group.id;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedGroupId = group.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? FlixieColors.primary
                                : FlixieColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? FlixieColors.primary
                                  : FlixieColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            group.abbreviation?.isNotEmpty == true
                                ? group.abbreviation!
                                : group.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : FlixieColors.light,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              'MESSAGE (OPTIONAL)',
              style: TextStyle(
                color: FlixieColors.medium,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              style: const TextStyle(color: FlixieColors.light),
              decoration: InputDecoration(
                hintText: 'e.g. Want to watch this together?',
                hintStyle:
                    const TextStyle(color: FlixieColors.medium, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F2033),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E2D40)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E2D40)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: FlixieColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ||
                        (_isGroupMode
                            ? _selectedGroupId == null
                            : _selectedFriendId == null)
                    ? null
                    : _send,
                child: _isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text('Send Invite'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? FlixieColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : FlixieColors.medium,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
