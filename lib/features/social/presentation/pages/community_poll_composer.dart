import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import '../../data/community_space_service.dart';
import '../widgets/discussion/community_poll_title_picker.dart';

class CommunityPollComposer extends StatefulWidget {
  const CommunityPollComposer(
      {super.key, required this.communityId, required this.service});
  final int communityId;
  final CommunitySpaceService service;
  @override
  State<CommunityPollComposer> createState() => _CommunityPollComposerState();
}

class _CommunityPollComposerState extends State<CommunityPollComposer> {
  final _question = TextEditingController(), _body = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _options = <Map<String, dynamic>>[];
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _question.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = await pickCommunityPollTitle(context,
        communityId: widget.communityId,
        service: widget.service,
        excluded: _options.map(pollMediaKey).toSet());
    if (title != null &&
        mounted &&
        !_options.any((o) => pollMediaKey(o) == pollMediaKey(title))) {
      setState(() {
        _options.add(title);
        _error = null;
      });
    }
  }

  DateTime? _closesAt;
  Future<void> _chooseDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _closesAt ?? now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365 * 5)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            _closesAt ?? now.add(const Duration(hours: 1))));
    if (time == null || !mounted) return;
    final closing =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (!closing.isAfter(DateTime.now())) {
        _error = 'Choose a closing time in the future.';
      } else {
        _closesAt = closing;
        _error = null;
      }
    });
  }

  Future<void> _publish() async {
    if (_sending || !_form.currentState!.validate()) return;
    if (_options.length < 2) {
      setState(() => _error = 'Choose at least two starting titles.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.post(widget.communityId, '/discussions', {
        'title': _question.text.trim(),
        'body': _body.text.trim().isEmpty
            ? 'Pick your favourite, or add another title to the poll.'
            : _body.text.trim(),
        'spoiler': 'none',
        'poll': {
          'options': _options.map(pollMediaInput).toList(),
          if (_closesAt != null)
            'closesAt': _closesAt!.toUtc().toIso8601String()
        }
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException
            ? e.message
            : 'Couldn’t publish. Your poll draft is kept. Try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_sending,
      child: Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
              leading: const FlixieBackButton(),
              title: const Text('Create a poll')),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Form(
                          key: _form,
                          child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                const Text(
                                    'Ask the community to choose. Each member gets one vote and can change their pick until voting closes.'),
                                const SizedBox(height: 20),
                                TextFormField(
                                    controller: _question,
                                    enabled: !_sending,
                                    maxLength: 180,
                                    minLines: 1,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                        labelText: 'Your question',
                                        hintText: 'Best anime of all time?'),
                                    validator: (v) => (v?.trim().length ?? 0) <
                                            3
                                        ? 'Write a question of at least three characters.'
                                        : null),
                                TextFormField(
                                    controller: _body,
                                    enabled: !_sending,
                                    maxLength: 5000,
                                    minLines: 2,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Add some context (optional)')),
                                const SizedBox(height: 20),
                                Text('Starting titles',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text(
                                    'Choose 2–10 titles. Members can add another real film or series after you publish. Keep the question spoiler-free.'),
                                for (final title in _options)
                                  ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(title['title']),
                                      subtitle: Text(title['kind'] == 'show'
                                          ? 'Series'
                                          : 'Film'),
                                      trailing: IconButton(
                                          tooltip: 'Remove ${title['title']}',
                                          onPressed: _sending
                                              ? null
                                              : () => setState(
                                                  () => _options.remove(title)),
                                          icon: const Icon(Icons.close))),
                                if (_options.length < 10)
                                  OutlinedButton.icon(
                                      onPressed: _sending ? null : _add,
                                      icon: const Icon(Icons.add),
                                      label:
                                          const Text('Add a film or series')),
                                const SizedBox(height: 20),
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.schedule),
                                    title: const Text('Closing time'),
                                    subtitle: Text(_closesAt == null
                                        ? 'No deadline - close whenever you like'
                                        : '${MaterialLocalizations.of(context).formatFullDate(_closesAt!)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_closesAt!))}'),
                                    onTap: _sending ? null : _chooseDeadline),
                                if (_closesAt != null)
                                  TextButton(
                                      onPressed: _sending
                                          ? null
                                          : () =>
                                              setState(() => _closesAt = null),
                                      child: const Text('Remove deadline')),
                                const SizedBox(height: 24),
                                if (_error != null)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(_error!)),
                                FilledButton(
                                    onPressed: _sending ? null : _publish,
                                    child: Text(_sending
                                        ? 'Publishing…'
                                        : 'Publish poll')),
                                const SizedBox(height: 12),
                                const Text(
                                    'This poll and its results are visible to people browsing the community. Only members can vote or add titles.')
                              ])))))));
}
