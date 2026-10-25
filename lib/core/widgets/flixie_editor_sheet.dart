import 'package:flutter/material.dart';
import 'flixie_prompt_sheet.dart';
import 'load_failure_notice.dart';

/// Shared edit actions and draft protection. Present with drag/barrier dismissal
/// disabled so every exit goes through Close, Cancel or the system back action.
class FlixieEditorSheet extends StatefulWidget {
  const FlixieEditorSheet(
      {super.key,
      required this.title,
      required this.dirty,
      required this.busy,
      required this.onSave,
      required this.child,
      this.saveLabel = 'Save changes',
      this.error});
  final String title, saveLabel;
  final bool dirty, busy;
  final VoidCallback? onSave;
  final String? error;
  final Widget child;
  @override
  State<FlixieEditorSheet> createState() => _FlixieEditorSheetState();
}

class _FlixieEditorSheetState extends State<FlixieEditorSheet> {
  final _errorKey = GlobalKey();
  bool _confirming = false;

  @override
  void didUpdateWidget(covariant FlixieEditorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error != null && oldWidget.error != widget.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final errorContext = _errorKey.currentContext;
        if (mounted && errorContext != null) {
          Scrollable.ensureVisible(errorContext);
        }
      });
    }
  }
  Future<void> _close() async {
    if (widget.busy || _confirming) return;
    if (!widget.dirty) {
      Navigator.pop(context);
      return;
    }
    _confirming = true;
    FocusScope.of(context).unfocus();
    final discard = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (sheet) => FlixiePromptSheetContent(
                title: const Text('Discard unsaved changes?'),
                content: const Text(
                    'Your unsaved edits will be lost. Anything already saved stays saved.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(sheet, false),
                      child: const Text('Keep editing')),
                  FilledButton(
                      onPressed: () => Navigator.pop(sheet, true),
                      child: const Text('Discard changes')),
                ]));
    _confirming = false;
    if (discard == true && mounted && !widget.busy) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !widget.busy && !widget.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .85),
              child: SafeArea(
                  top: false,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                            child: Row(children: [
                              Expanded(
                                  child: Text(widget.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge)),
                              IconButton(
                                  tooltip: 'Close',
                                  onPressed: widget.busy ? null : _close,
                                  icon: const Icon(Icons.close)),
                            ])),
                        Flexible(
                            child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AbsorbPointer(
                                          absorbing: widget.busy,
                                          child: widget.child),
                                      if (widget.error != null)
                                        LoadFailureNotice(
                                            key: _errorKey,
                                            message: widget.error!,
                                            onRetry: widget.onSave,
                                            retrying: widget.busy),
                                    ]))),
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton(
                                      onPressed:
                                          widget.busy ? null : widget.onSave,
                                      child: Text(widget.busy
                                          ? 'Saving…'
                                          : widget.saveLabel)),
                                  TextButton(
                                      onPressed: widget.busy ? null : _close,
                                      child: const Text('Cancel')),
                                ])),
                      ])))));
}
