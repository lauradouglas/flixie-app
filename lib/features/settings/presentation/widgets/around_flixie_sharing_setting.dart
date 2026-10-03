import 'package:flutter/material.dart';
import 'package:flixie_app/features/social/data/community_service.dart';

/// Account-level opt-in, shared by signup and Settings. Merely viewing it never
/// changes consent; a failed save leaves the last confirmed value visible.
class AroundFlixieSharingSetting extends StatefulWidget {
  const AroundFlixieSharingSetting(
      {super.key,
      this.load,
      this.save,
      this.onBusyChanged,
      this.enabled = true,
      this.contentPadding = const EdgeInsets.all(16)});
  final bool enabled;
  final Future<bool> Function()? load;
  final Future<void> Function(bool)? save;
  final ValueChanged<bool>? onBusyChanged;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<AroundFlixieSharingSetting> createState() => _SharingState();
}

class _SharingState extends State<AroundFlixieSharingSetting> {
  bool? _enabled;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enabled = await (widget.load ?? const CommunityService().sharing)();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load sharing settings.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      await (widget.save ?? const CommunityService().setSharing)(value);
      if (mounted) setState(() => _enabled = value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sharing wasn’t changed. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: widget.contentPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share on Around Flixie'),
            subtitle: Text(_enabled == null
                ? (_error == null
                    ? 'Loading your sharing preference…'
                    : 'Sharing preference unavailable')
                : 'Optional · change this anytime in Settings'),
            value: _enabled ?? false,
            onChanged:
                !widget.enabled || _busy || _enabled == null ? null : _save,
          ),
          const SizedBox(height: 12),
          const Text(
              'Everyone on Flixie can see your existing and future reviews, their ratings, and public personal lists.'),
          const SizedBox(height: 12),
          const Text('Watch history, watchlists and watch plans stay out.'),
          const SizedBox(height: 12),
          const Text(
              'Turn this off to stop sharing your reviews and lists through Around Flixie and community review feeds. Friends sharing stays the same.'),
          const SizedBox(height: 12),
          const Text(
              'Discussions and public replies you publish are separate. Turning this off does not delete them; use Delete on each discussion or reply.'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, semanticsLabel: _error),
            if (_enabled == null)
              TextButton(
                  onPressed: _busy ? null : _load, child: const Text('Retry')),
          ],
        ]),
      );
}
