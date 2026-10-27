import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Returns true when the user chooses the native image share menu.
Future<bool?> showQuickShareSheet(BuildContext context, {
  required Future<void> Function() saveCard,
  required Future<void> Function() copyReferralLink,
}) => showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface,
  builder: (context) => QuickShareSheet(
    saveCard: saveCard, copyReferralLink: copyReferralLink),
);

class QuickShareSheet extends StatefulWidget {
  const QuickShareSheet({super.key, required this.saveCard, required this.copyReferralLink});
  final Future<void> Function() saveCard;
  final Future<void> Function() copyReferralLink;
  @override
  State<QuickShareSheet> createState() => _QuickShareSheetState();
}

class _QuickShareSheetState extends State<QuickShareSheet> {
  bool _story = false;
  bool _busy = false;
  bool _saved = false;
  bool _copied = false;
  String? _error;

  Future<void> _perform({required bool copy}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await (copy ? widget.copyReferralLink() : widget.saveCard());
      if (mounted) setState(() { if (copy) { _copied = true; } else { _saved = true; } });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _option(IconData icon, String title, String subtitle, VoidCallback onTap) =>
      Column(children: [
        ListTile(
          enabled: !_busy,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF302047),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: const Color(0xFFDCC3FF))),
          title: Text(title, style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w600, color: Color(0xFFF4EFF6))),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 13,
              color: Color(0xFFBCB0CB))),
          trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFBCB0CB)),
          onTap: onTap,
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF38284A)),
      ]);

  @override
  Widget build(BuildContext context) => SafeArea(top: false, child: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (_story) IconButton(tooltip: 'Back', onPressed: _busy ? null : () => setState(() { _story = false; _error = null; }), icon: const Icon(Icons.arrow_back)),
          Expanded(child: Text(_story ? 'Finish in Instagram' : 'Ready to share?',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          IconButton(tooltip: 'Close', onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        const SizedBox(height: 16),
        if (!_story) ...[
          _option(Icons.auto_awesome_outlined, 'Post to your Story',
              'Card + link for Instagram', () => setState(() => _story = true)),
          _option(Icons.send_outlined, 'Send to friends', 'Messages, WhatsApp & more', () => Navigator.pop(context, true)),
          const SizedBox(height: 6),
        ] else ...[
          const Text('Add the saved card to your Instagram Story. Choose the Link sticker and paste your referral link.', style: TextStyle(height: 1.5)),
          const SizedBox(height: 16),
          const Text('Sticker label: Join me on Flixie', style: TextStyle(color: Color(0xFFDCC3FF))),
          const SizedBox(height: 20),
          _option(_copied ? Icons.check : Icons.link,
              _copied ? 'Referral link copied' : 'Copy referral link',
              _copied ? 'Ready to paste into the Link sticker' : 'Use it in Instagram’s Link sticker',
              () => _perform(copy: true)),
        ],
        if (!_story)
          _option(_saved ? Icons.check : Icons.download_outlined,
              _saved ? 'Saved to Photos' : 'Just save the card',
              'Keep it in your photos', () => _perform(copy: false)),
        if (_story)
          _option(_saved ? Icons.check : Icons.download_outlined,
              _saved ? 'Saved to Photos' : 'Save card to Photos',
              _saved ? 'Ready to add to your Story' : 'Add the image to your Story',
              () => _perform(copy: false)),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, semanticsLabel: _error, style: TextStyle(color: context.colors.danger))),
      ]),
    ),
  ));
}
