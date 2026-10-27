import 'package:flutter/material.dart';
import '../../data/guest_diary_store.dart';
import '../../models/guest_diary_draft.dart';

/// The same editor before and after authentication; local writes precede handoff.
class GuestDiaryEditor extends StatefulWidget {
  const GuestDiaryEditor(
      {super.key,
      required this.draft,
      required this.onContinue,
      this.signedIn = false,
      this.onBusyChanged});
  final GuestDiaryDraft draft;
  final bool signedIn;
  final Future<void> Function(GuestDiaryDraft) onContinue;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<GuestDiaryEditor> createState() => _GuestDiaryEditorState();
}

class _GuestDiaryEditorState extends State<GuestDiaryEditor> {
  late final _date = TextEditingController(text: widget.draft.date);
  late final _note = TextEditingController(text: widget.draft.note);
  late int? _rating = widget.draft.rating;
  late bool? _recommended = widget.draft.recommended;
  bool _busy = false;
  late bool _locked = widget.draft.submitted;
  String? _error;
  GuestDiaryDraft get _draft => GuestDiaryDraft(
      id: widget.draft.id,
      movieId: widget.draft.movieId,
      title: widget.draft.title,
      poster: widget.draft.poster,
      watchInviteToken: widget.draft.watchInviteToken,
      watchRequestId: widget.draft.watchRequestId,
      inviterName: widget.draft.inviterName,
      referralCode: widget.draft.referralCode,
      connectInviter: widget.draft.connectInviter,
      owner: widget.draft.owner,
      submitted: _locked,
      logWatch: widget.draft.logWatch,
      rating: _rating,
      date: _date.text,
      note: _note.text,
      recommended: _recommended);
  Future<void> _persist() async {
    try {
      await GuestDiaryStore.instance.save(_draft);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t keep this draft on your device. Try again before leaving.');
      }
    }
  }

  Future<void> _continue() async {
    if (_busy) return;
    final draft = _draft;
    final error = draft.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      await GuestDiaryStore.instance.save(draft);
      if (widget.signedIn) {
        setState(() => _locked = true);
        await GuestDiaryStore.instance.save(_draft);
      }
      await widget.onContinue(_draft);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t finish saving. Your entry is still here. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  Future<void> _chooseDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final parsed = DateTime.tryParse(_date.text);
    var selected =
        parsed != null && !parsed.isAfter(today) && parsed.year >= 1900
            ? parsed
            : today;
    final value = await showModalBottomSheet<DateTime>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheet) => SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .8,
            child: StatefulBuilder(
                builder: (context, update) => SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Watch date',
                              style: Theme.of(context).textTheme.titleLarge),
                          CalendarDatePicker(
                              initialDate: selected,
                              firstDate: DateTime(1900),
                              lastDate: today,
                              onDateChanged: (date) =>
                                  update(() => selected = date)),
                          FilledButton(
                              onPressed: () => Navigator.pop(sheet, selected),
                              child: const Text('Save date')),
                          TextButton(
                              onPressed: () => Navigator.pop(sheet),
                              child: const Text('Cancel')),
                        ])))));
    if (value == null || !mounted) return;
    _date.text = value.toIso8601String().substring(0, 10);
    await _persist();
  }

  @override
  void dispose() {
    _date.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.draft.title,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(widget.signedIn
            ? 'Your draft is ready. Check it, then save it to your account.'
            : 'Your film, your memories. Kept as a draft on this device.'),
        const SizedBox(height: 24),
        Text(widget.draft.logWatch ? 'Your score (optional)' : 'Your score',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var n = 1; n <= 10; n++)
            ChoiceChip(
                label: Text('$n'),
                selected: _rating == n,
                onSelected: (_busy || _locked)
                    ? null
                    : (selected) {
                        setState(() => _rating = selected ? n : null);
                        _persist();
                      })
        ]),
        const SizedBox(height: 20),
        const Text('Would you recommend it? (optional)'),
        Wrap(spacing: 8, children: [
          for (final value in [true, false])
            ChoiceChip(
                label: Text(value ? 'Yes' : 'No'),
                selected: _recommended == value,
                onSelected: (_busy || _locked)
                    ? null
                    : (selected) {
                        setState(() => _recommended = selected ? value : null);
                        _persist();
                      })
        ]),
        if (widget.draft.logWatch) ...[
          const SizedBox(height: 20),
          TextField(
              controller: _date,
              enabled: !_busy && !_locked,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                  suffixIcon: IconButton(
                      tooltip: 'Choose watch date',
                      onPressed: (_busy || _locked) ? null : _chooseDate,
                      icon: const Icon(Icons.calendar_today)),
                  labelText: 'Watch date (optional)',
                  hintText: 'YYYY-MM-DD',
                  helperText: 'Leave blank if you don’t remember the date.',
                  helperMaxLines: 3),
              onChanged: (_) => _persist()),
          const SizedBox(height: 20),
          TextField(
              controller: _note,
              enabled: !_busy && !_locked,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                  labelText: 'A note for your diary (optional)',
                  alignLabelWithHint: true),
              onChanged: (_) => _persist()),
        ],
        if (_locked)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  'This entry is ready to retry exactly as sent. You can edit it from your diary once saving is confirmed.')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _busy ? null : _continue,
            child: Text(_busy
                ? 'Saving…'
                : widget.signedIn
                    ? 'Save to my account'
                    : 'Preview my entry')),
        const SizedBox(height: 12),
        const Text('Device-only drafts are removed if you clear app data.',
            textAlign: TextAlign.center),
      ]);
}
