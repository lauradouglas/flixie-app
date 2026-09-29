import 'package:flutter/material.dart';

/// A retryable failure, distinct from a successful empty result.
/// Can be shown above retained content or centred on an initially failed page.
class LoadFailureNotice extends StatelessWidget {
  const LoadFailureNotice(
      {super.key,
      required this.message,
      required this.onRetry,
      this.retrying = false});
  final String message;
  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Semantics(
                  liveRegion: true,
                  child: Text(message, textAlign: TextAlign.center)),
              TextButton(
                  onPressed: retrying ? null : onRetry,
                  child: Text(retrying ? 'Retrying…' : 'Retry')),
            ]),
      );
}
