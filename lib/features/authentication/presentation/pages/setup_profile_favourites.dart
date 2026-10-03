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
      this.enabled = true,
      this.onBusyChanged});
  final bool enabled;
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
  Future<void> _saveSelected({bool moviesOnly = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      for (final title in widget.titles
          .where((t) => _selected.contains(t.key) && (!moviesOnly || !t.isShow))
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
        setState(() => _error = 'Some favourites couldn’t be added. '
            'Your successful choices are saved. Retry, or manage your favourites in Profile.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  Future<void> _quickAddMovies() async {
    setState(() => _selected.addAll(widget.titles
        .where((t) => !t.isShow && !_saved.contains(t.key))
        .map((t) => t.key)));
    await _saveSelected(moviesOnly: true);
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: true,
        title: const Text('Add your favourites'),
        subtitle: const Text('Add favourites people can see · optional'),
        children: [
          const Text(
              'Use your taste picks below—no need to search again. Adding favourites puts them on your profile and helps personalise your recommendations. You can skip this.'),
          if (widget.titles.any((t) => !t.isShow && !_saved.contains(t.key)))
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FilledButton.icon(
                  onPressed: !widget.enabled || _busy ? null : _quickAddMovies,
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Add my movie picks to favourites'),
                )),
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
              onChanged: !widget.enabled || _busy || _saved.contains(title.key)
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
                onPressed: !widget.enabled || _busy || _selected.isEmpty
                    ? null
                    : _saveSelected,
                child: Text(_busy
                    ? 'Adding favourites…'
                    : 'Add selected to my profile'),
              )),
        ],
      );
}
