import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../../data/activity_state_batch.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import '../../data/community_service.dart';

class CommunityBookmarkButton extends StatefulWidget {
  const CommunityBookmarkButton(
      {super.key,
      required this.item,
      required this.service,
      this.initiallySaved = false,
      this.iconOnly = false,
      this.onChanged});
  final ActivityListItem item;
  final CommunityService service;
  final bool initiallySaved;
  final bool iconOnly;
  final ValueChanged<bool>? onChanged;
  @override
  State<CommunityBookmarkButton> createState() =>
      _CommunityBookmarkButtonState();
}

class _CommunityBookmarkButtonState extends State<CommunityBookmarkButton> {
  bool? _saved;
  bool _busy = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    if (widget.initiallySaved) {
      _saved = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final viewer = context.read<AuthProvider?>()?.dbUser?.id;
    setState(() => _failed = false);
    try {
      final value = viewer == null
          ? await widget.service.isSaved(widget.item)
          : (await ActivityStateBatch.load(
                  viewer: viewer,
                  owner: widget.item.userId,
                  type: widget.item.type.value,
                  id: widget.item.id,
                  community: true))['saved'] ==
              true;
      if (mounted &&
          generation == _generation &&
          viewer == context.read<AuthProvider?>()?.dbUser?.id) {
        setState(() => _saved = value);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggle() async {
    if (_busy || _saved == null) return;
    final next = !_saved!;
    setState(() => _busy = true);
    try {
      await widget.service.save(widget.item, next);
      ActivityStateBatch.clear();
      if (mounted) {
        setState(() => _saved = next);
        widget.onChanged?.call(next);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t update saved posts. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _icon() => _busy
      ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel:
                _saved == true ? 'Removing saved post' : 'Saving post',
          ),
        )
      : Icon(_saved == true ? Icons.bookmark : Icons.bookmark_border);

  @override
  Widget build(BuildContext context) => widget.iconOnly
      ? IconButton(
          tooltip: _busy
              ? (_saved == true ? 'Removing…' : 'Saving…')
              : _failed
                  ? 'Retry save'
                  : _saved == true
                      ? 'Unsave post'
                      : widget.item.listId != null
                          ? 'Save list'
                          : 'Save post',
          onPressed: _busy
              ? null
              : _failed
                  ? _load
                  : _saved == null
                      ? null
                      : _toggle,
          icon: _icon())
      : TextButton.icon(
          onPressed: _busy
              ? null
              : _failed
                  ? _load
                  : _saved == null
                      ? null
                      : _toggle,
          icon: _icon(),
          label: Text(_busy
              ? (_saved == true ? 'Removing…' : 'Saving…')
              : _failed
                  ? 'Retry save'
                  : _saved == true
                      ? 'Saved'
                      : widget.item.listId != null
                          ? 'Save list'
                          : 'Save post'),
        );
}
