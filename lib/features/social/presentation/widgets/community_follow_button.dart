import 'package:flutter/material.dart';
import '../../data/community_service.dart';

class CommunityFollowButton extends StatefulWidget {
  const CommunityFollowButton(
      {super.key,
      required this.path,
      required this.service,
      this.list = false,
      this.outlined = false});
  final String path;
  final CommunityService service;
  final bool list;
  final bool outlined;
  @override
  State<CommunityFollowButton> createState() => _CommunityFollowButtonState();
}

class _CommunityFollowButtonState extends State<CommunityFollowButton> {
  bool? _following;
  bool _busy = false, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.service.follows(widget.path);
      if (mounted) {
        setState(() {
          _following = value;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggle() async {
    if (_busy || _following == null) return;
    setState(() => _busy = true);
    try {
      await widget.service.follow(widget.path, !_following!);
      if (mounted) setState(() => _following = !_following!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t update following. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message: _following == true
          ? 'Unfollow${widget.list ? ' list' : ''}'
          : 'Follow',
      child: widget.outlined
          ? OutlinedButton(
              onPressed: _busy
                  ? null
                  : _failed
                      ? _load
                      : _following == null
                          ? null
                          : _toggle,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(76, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text(_busy
                  ? 'Saving…'
                  : _failed
                      ? 'Retry follow status'
                      : _following == null
                          ? 'Loading…'
                          : _following!
                              ? 'Following'
                              : 'Follow'),
            )
          : TextButton.icon(
              onPressed: _busy
                  ? null
                  : _failed
                      ? _load
                      : _following == null
                          ? null
                          : _toggle,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_following == true ? Icons.check : Icons.add,
                      size: 16),
              style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              label: Text(_failed
                  ? 'Retry follow status'
                  : _following == true
                      ? 'Following${widget.list ? ' list' : ''}'
                      : 'Follow${widget.list ? ' list' : ''}')));
}
