import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../data/library_import_controller.dart';
import '../data/library_export_links.dart';
import '../data/library_import_models.dart';
import '../data/library_import_parser.dart';

class LibraryImportScreen extends StatefulWidget {
  const LibraryImportScreen({super.key, required this.controller});
  final LibraryImportController controller;
  @override
  State<LibraryImportScreen> createState() => _LibraryImportScreenState();
}

class _LibraryImportScreenState extends State<LibraryImportScreen> {
  LibraryImportController get c => widget.controller;
  bool _reading = false;
  bool _restoring = false;
  bool _leaving = false;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    if (c.data == null) {
      _restoring = true;
      c.restore().catchError((_) {
        _error =
            'Could not load saved progress. Please reopen Import your library.';
      }).whenComplete(() {
        if (mounted) {
          setState(() {
            _restoring = false;
          });
        }
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
    if (_leaving && !c.busy && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _leave() {
    if (c.busy) {
      _leaving = true;
      c.pause();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    super.dispose();
  }

  Future<void> _chooseFiles() async {
    var filesChosen = false;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv', 'zip'],
          allowMultiple: true,
          withData: false);
      if (picked == null || !mounted) return;
      filesChosen = true;
      var size = 0;
      final files = <LibraryImportFile>[];
      for (final file in picked.files) {
        size += file.size;
        if (size > 20 * 1024 * 1024) {
          throw const FormatException(
              'Choose exports totalling 20 MB or less.');
        }
        final Uint8List bytes = file.bytes ?? await file.xFile.readAsBytes();
        files.add(LibraryImportFile(file.name, bytes));
      }
      final data = await compute(parseLibraryImport, files);
      if (!mounted) return;
      await c.setData(data);
      if (mounted) {
        setState(() {
          _reading = false;
          _filter = 'all';
        });
        await c.resolve();
      }
    } on MissingPluginException {
      logger.w(
          'Library import: native file picker is not registered in this build.');
      if (mounted) {
        setState(() {
          _error = kDebugMode
              ? 'This app needs a full rebuild to enable file imports. Hot reload cannot add the file picker.'
              : 'File imports are unavailable in this version of Flixie. Please update the app and try again.';
        });
      }
    } on PlatformException catch (e) {
      logger.w('Library import: file picker failed (${e.code}).');
      if (mounted) {
        setState(() {
          _error = filesChosen
              ? 'The selected export could not be read. Save it to Files on your device and try again.'
              : 'The file chooser could not open. Close and reopen Flixie, then try again.';
        });
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
        });
      }
    } catch (e) {
      logger.w(
          'Library import: ${filesChosen ? 'reading export' : 'opening picker'} failed (${e.runtimeType}).');
      if (mounted) {
        setState(() {
          _error = filesChosen
              ? 'This file could not be opened. Download a fresh export and choose it again.'
              : kDebugMode
                  ? 'The file chooser could not open. If file imports were just added, stop and fully rebuild the app before trying again.'
                  : 'The file chooser could not open. Close and reopen Flixie, then try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _reading = false;
        });
      }
    }
  }

  Future<void> _open(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw StateError('No browser');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not open your browser. Visit $url to export your data.';
        });
      }
    }
  }

  Future<void> _review(LibraryImportRow row) async {
    final selection = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) => _ImportMatchScreen(row: row, controller: c)));
    if (selection == null || !mounted) return;
    try {
      await c.select(row, selection.isEmpty ? null : selection);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save this choice. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = c.data;
    final busy = _reading || _restoring || c.busy;
    final rows = data?.rows
            .where((r) => _filter == 'all' || r.status == _filter)
            .toList() ??
        [];
    return PopScope(
        canPop: !c.busy,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: FlixieColors.background,
          appBar: AppBar(
              toolbarHeight:
                  56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              titleTextStyle: Theme.of(context).textTheme.titleLarge,
              leading: BackButton(onPressed: _leave),
              title: const Text('Import your library')),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(slivers: [
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text(
                            data == null
                                ? 'Bring your library with you'
                                : 'Review your library',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                            data == null
                                ? 'Bring your IMDb or Letterboxd ratings and watchlist to Flixie.'
                                : c.doneCount > 0
                                    ? 'Your processed titles are saved. Existing Flixie ratings are kept. You can continue with any remaining titles below.'
                                    : 'Existing Flixie ratings are kept. Duplicate entries are combined. Nothing is imported until you choose Import.',
                            style: const TextStyle(
                                color: FlixieColors.light, height: 1.5)),
                        if (_error != null || c.error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                              liveRegion: true,
                              child: Text(_error ?? c.error!,
                                  style: const TextStyle(
                                      color: FlixieColors.danger))),
                        ],
                        if (data == null) ...[
                          const SizedBox(height: 20),
                          _ImportButton(
                              label: _reading
                                  ? 'Opening your export…'
                                  : 'Choose export files',
                              icon: Icons.file_upload_outlined,
                              onPressed: busy ? null : _chooseFiles),
                          const SizedBox(height: 8),
                          const Text('ZIP or CSV · up to 20 MB',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FlixieColors.medium)),
                          const SizedBox(height: 24),
                          _ExportHelp(
                              title: 'Letterboxd',
                              text:
                                  'Open Export your data and download the ZIP. Bring that ZIP straight here — no unzipping needed. You can also choose ratings.csv and watchlist.csv.',
                              action: 'Open Letterboxd export',
                              onTap: () => _open(letterboxdExportUrl)),
                          const Divider(height: 32),
                          _ExportHelp(
                              title: 'IMDb',
                              text:
                                  'On IMDb’s website, open Your ratings or Your Watchlist and choose Export. Download the ready export from your export history, then choose the CSV files here. You can select both together.',
                              action: 'Open IMDb ratings',
                              onTap: () => _open(imdbRatingsExportUrl),
                              secondaryAction: 'Open IMDb watchlist',
                              onSecondaryTap: () =>
                                  _open(imdbWatchlistExportUrl)),
                          const SizedBox(height: 24),
                          const Text(
                              'Your passwords stay with IMDb and Letterboxd. Only title details and the ratings or watchlist entries you choose are sent to Flixie.',
                              style: TextStyle(
                                  color: FlixieColors.light, height: 1.5)),
                        ] else ...[
                          const SizedBox(height: 20),
                          Text('${data.rows.length} titles found',
                              style: Theme.of(context).textTheme.titleLarge),
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                  'Ratings (${data.rows.where((r) => r.rating != null).length})'),
                              subtitle: const Text(
                                  'Letterboxd stars become scores out of 10. 3½ stars = 7/10.'),
                              value: c.includeRatings,
                              onChanged: busy || c.doneCount > 0
                                  ? null
                                  : (v) => setState(() {
                                        c.includeRatings = v!;
                                      })),
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                  'Watchlist (${data.rows.where((r) => r.watchlist).length})'),
                              value: c.includeWatchlist,
                              onChanged: busy || c.doneCount > 0
                                  ? null
                                  : (v) => setState(() {
                                        c.includeWatchlist = v!;
                                      })),
                          const Text(
                              'Ratings keep their original rating date where available and add an undated watch if needed. Watchlist-only imports stay on your watchlist. TV episodes are not marked watched.',
                              style: TextStyle(
                                  color: FlixieColors.light, height: 1.4)),
                          if (data.notices.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title:
                                        const Text('Notes about your export'),
                                    children: data.notices
                                        .map((n) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: Text(n)))
                                        .toList())),
                          if (busy) ...[
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                                value: _reading || data.rows.isEmpty
                                    ? null
                                    : c.phase == 'Finding your titles'
                                        ? (data.rows.length - c.pendingCount) /
                                            data.rows.length
                                        : c.doneCount /
                                            (c.doneCount + c.readyCount)),
                            const SizedBox(height: 12),
                            Semantics(
                                liveRegion: true,
                                child: Text(
                                    '${c.phase}… ${c.phase == 'Finding your titles' ? data.rows.length - c.pendingCount : c.doneCount} processed')),
                            TextButton(
                                onPressed: c.paused ? null : c.pause,
                                child: Text(c.paused
                                    ? 'Pausing after this title…'
                                    : 'Pause')),
                            const Text(
                                'Keep this screen open while importing. If you leave, your progress is saved here.',
                                style: TextStyle(color: FlixieColors.light)),
                          ] else ...[
                            if (c.doneCount > 0) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                  liveRegion: true,
                                  child: Text(
                                      '${c.doneCount} titles processed · ${data.rows.where((r) => r.result?['rating'] == 'added').length} ratings added · ${data.rows.where((r) => r.result?['watchlist'] == 'added').length} watchlist entries added',
                                      style: const TextStyle(
                                          color: FlixieColors.success,
                                          height: 1.5))),
                              Text(
                                  '${data.rows.where((r) => r.result?['rating'] == 'kept').length} existing ratings and ${data.rows.where((r) => r.result?['watchlist'] == 'kept').length} existing watchlist entries kept.',
                                  style: const TextStyle(
                                      color: FlixieColors.light)),
                            ],
                            if (c.pendingCount > 0)
                              TextButton(
                                  onPressed: c.resolve,
                                  child: const Text('Find remaining titles')),
                            const SizedBox(height: 16),
                            if (c.readyCount > 0)
                              _ImportButton(
                                  label: c.doneCount > 0
                                      ? 'Import remaining titles (${c.readyCount})'
                                      : 'Import ${c.readyCount} titles',
                                  icon: Icons.download_done_rounded,
                                  onPressed: c.commit),
                            if (data.rows.any((r) => r.status == 'review'))
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                      '${data.rows.where((r) => r.status == 'review').length} titles need a match. You can import the ready titles first.',
                                      style: const TextStyle(
                                          color: FlixieColors.warning))),
                            if (data.rows.isEmpty)
                              const Text(
                                  'No supported ratings or watchlist entries were found. See the export notes above, or choose another file.'),
                            TextButton(
                                onPressed: () async {
                                  await c.clear();
                                  if (mounted) {
                                    setState(() {
                                      _filter = 'all';
                                    });
                                  }
                                },
                                child: Text(c.doneCount > 0 &&
                                        c.readyCount == 0 &&
                                        c.pendingCount == 0
                                    ? 'Finish and clear this preview'
                                    : 'Clear preview and choose another export')),
                          ],
                          const SizedBox(height: 20),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final filter in {
                              'all': 'All',
                              'review': 'Needs a match',
                              'ready': 'Ready',
                              'done': 'Processed',
                              'skipped': 'Skipped'
                            }.entries)
                              ChoiceChip(
                                  label: Text(filter.value),
                                  selected: _filter == filter.key,
                                  onSelected: (_) => setState(() {
                                        _filter = filter.key;
                                      })),
                          ]),
                        ],
                      ]))),
              SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final done = row.status == 'done';
                    final selectedTitle = row.match?['title'];
                    return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          leading: Icon(
                              done
                                  ? Icons.check_circle_outline
                                  : row.status == 'review'
                                      ? Icons.help_outline
                                      : Icons.movie_outlined,
                              color: done
                                  ? FlixieColors.success
                                  : FlixieColors.light),
                          title: Text(
                              '${row.title}${row.year == null ? '' : ' (${row.year})'}'),
                          subtitle: Text([
                            if (row.rating != null) '${row.rating}/10',
                            if (row.watchlist) 'Watchlist',
                            row.mediaType == 'show' ? 'TV series' : 'Film',
                            if (selectedTitle != null)
                              'Matched: $selectedTitle (${row.match!['year'] ?? 'year unknown'})',
                            if (row.status == 'pending') 'Waiting to match',
                            if (row.status == 'review') 'Choose a match',
                            if (row.status == 'skipped')
                              'Skipped · tap to choose a match',
                          ].join(' · ')),
                          trailing:
                              done ? null : const Icon(Icons.chevron_right),
                          onTap: busy || done ? null : () => _review(row),
                        ));
                  }),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ]),
          ))),
        ));
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton(
      {required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
      style: FilledButton.styleFrom(
          backgroundColor: FlixieColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center));
}

class _ExportHelp extends StatelessWidget {
  const _ExportHelp(
      {required this.title,
      required this.text,
      required this.action,
      required this.onTap,
      this.secondaryAction,
      this.onSecondaryTap});
  final String title, text, action;
  final VoidCallback onTap;
  final String? secondaryAction;
  final VoidCallback? onSecondaryTap;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(text,
            style: const TextStyle(color: FlixieColors.light, height: 1.5)),
        TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(action)),
        if (secondaryAction != null && onSecondaryTap != null)
          TextButton.icon(
              onPressed: onSecondaryTap,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(secondaryAction!)),
      ]);
}

class _ImportMatchScreen extends StatefulWidget {
  const _ImportMatchScreen({required this.row, required this.controller});
  final LibraryImportRow row;
  final LibraryImportController controller;
  @override
  State<_ImportMatchScreen> createState() => _ImportMatchScreenState();
}

class _ImportMatchScreenState extends State<_ImportMatchScreen> {
  late final TextEditingController _query =
      TextEditingController(text: widget.row.title);
  late List<Map<String, dynamic>> _candidates = widget.row.candidates;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await widget.controller
          .search(_query.text.trim(), widget.row.mediaType);
      if (mounted) {
        setState(() {
          _candidates = results;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Search could not finish. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlixieColors.background,
        appBar: AppBar(
            toolbarHeight:
                56 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
            titleTextStyle: Theme.of(context).textTheme.titleLarge,
            title: const Text('Choose the right title')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(
                '${widget.row.title}${widget.row.year == null ? '' : ' (${widget.row.year})'}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Check the title and year. Search for an alternative title if you cannot find it.',
                style: TextStyle(color: FlixieColors.light)),
            const SizedBox(height: 20),
            TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                maxLength: 500,
                decoration: const InputDecoration(
                    labelText: 'Film or series title',
                    border: OutlineInputBorder()),
                onSubmitted: (_) => _search()),
            _ImportButton(
                label: _busy ? 'Searching…' : 'Search titles',
                icon: Icons.search,
                onPressed: _busy ? null : _search),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!,
                      style: const TextStyle(color: FlixieColors.danger))),
            const SizedBox(height: 20),
            if (_candidates.isEmpty && !_busy)
              const Text(
                  'No matches yet. Try a different title, or skip this item for now.'),
            for (final candidate in _candidates)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(candidate['title']),
                  subtitle: Text(
                      '${candidate['year'] ?? 'Year unknown'} · ${candidate['mediaType'] == 'show' ? 'TV series' : 'Film'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      _busy ? null : () => Navigator.pop(context, candidate)),
            const SizedBox(height: 20),
            TextButton(
                onPressed: () => Navigator.pop(context, <String, dynamic>{}),
                child: const Text('Skip this title')),
          ]),
        ))),
      );
}
