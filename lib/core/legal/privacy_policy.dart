import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openPrivacyPolicy(BuildContext context) async {
  final uri = Uri.parse('https://www.flixie.co.uk/privacy');
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Keep the address available if this device cannot open a browser.
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy Policy'),
      content: const SingleChildScrollView(
        child: SelectableText(
          'Could not open your browser. You can copy this address to read our policy:\n\nhttps://www.flixie.co.uk/privacy',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    ),
  );
}
