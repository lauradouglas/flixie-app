import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../data/setup_service.dart';

/// An explicit opt-in: taste seeds stay private until the user selects and saves.
class SetupProfileFavourites extends StatefulWidget {
  const SetupProfileFavourites(
      {super.key,
      required this.titles,
      required this.save,
      this.onSaved,
      this.onBusyChanged});
  final List<SetupTitle> titles;
  final Future<void> Function(SetupTitle) save;
  final VoidCallback? onSaved;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<SetupProfileFavourites> createState() => _SetupProfileFavouritesState();
}

class _SetupProfileFavouritesState extends State<SetupProfileFavourites> {
  final _selected = <String>{}, _saved = <String>{};
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Make your profile more you'),
        subtitle: const Text('Add favourites people can see · optional'),
        children: [
          const Text(
              'Want to strengthen your profile? Choose the titles you want '
              'to show as favourites. Your private taste picks won’t be shared unless you add them here.'),
          for (final title in widget.titles)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title.name),
              subtitle: Text(_saved.contains(title.key)
                  ? 'Added to your profile'
                  : title.isShow
                      ? 'Show'
                      : 'Film'),
              value:
                  _saved.contains(title.key) || _selected.contains(title.key),
              onChanged: _busy || _saved.contains(title.key)
                  ? null
                  : (value) => setState(() {
                        value == true
                            ? _selected.add(title.key)
                            : _selected.remove(title.key);
                      }),
            ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.colors.danger)),
          if (_saved.isNotEmpty)
            Semantics(
                liveRegion: true,
                child: const Text(
                    'Your favourites are on your profile. You can edit them there anytime.')),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: OutlinedButton(
                onPressed: _busy || _selected.isEmpty
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        widget.onBusyChanged?.call(true);
                        try {
                          for (final title in widget.titles
                              .where((t) => _selected.contains(t.key))
                              .toList()) {
                            await widget.save(title);
                            if (!mounted) return;
                            setState(() {
                              _saved.add(title.key);
                              _selected.remove(title.key);
                            });
                            widget.onSaved?.call();
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(() =>
                                _error = 'Some favourites couldn’t be added. '
                                    'Your successful choices are saved. Retry, or manage your favourites in Profile.');
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _busy = false);
                            widget.onBusyChanged?.call(false);
                          }
                        }
                      },
                child: Text(_busy
                    ? 'Adding favourites…'
                    : 'Add selected to my profile'),
              )),
        ],
      );
}
