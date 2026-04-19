import 'package:flutter/material.dart';

import '../../models/movie_watch_entry.dart';
import '../../theme/app_theme.dart';

class RewatchLogSheet extends StatefulWidget {
  const RewatchLogSheet({
    super.key,
    this.initial,
    required this.onSubmit,
  });

  final MovieWatchEntry? initial;
  final Future<void> Function({
    required String watchedAt,
    required double? rating,
    required String? notes,
  }) onSubmit;

  @override
  State<RewatchLogSheet> createState() => _RewatchLogSheetState();
}

class _RewatchLogSheetState extends State<RewatchLogSheet> {
  late DateTime _watchedAt;
  late TextEditingController _notesController;
  double? _rating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _watchedAt = DateTime.tryParse(widget.initial?.watchedAt ?? '') ?? DateTime.now();
    _rating = widget.initial?.rating;
    _notesController = TextEditingController(text: widget.initial?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initial == null ? 'Log Watch' : 'Edit Watch Entry',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Watched on'),
              subtitle: Text('${_watchedAt.day}/${_watchedAt.month}/${_watchedAt.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _watchedAt,
                  firstDate: DateTime(1970),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _watchedAt = date);
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Rating'),
                const Spacer(),
                if (_rating != null)
                  TextButton(
                    onPressed: () => setState(() => _rating = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            Slider(
              value: (_rating ?? 5).clamp(1, 10).toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: _rating?.toStringAsFixed(0) ?? '—',
              activeColor: FlixieColors.primary,
              onChanged: (v) => setState(() => _rating = v.roundToDouble()),
            ),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Notes (optional)'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        await widget.onSubmit(
                          watchedAt: _watchedAt.toUtc().toIso8601String(),
                          rating: _rating,
                          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                        );
                        if (mounted) Navigator.pop(context);
                      },
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.initial == null ? 'Log Watch' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
