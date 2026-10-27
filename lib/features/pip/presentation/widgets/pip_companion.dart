import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pip_collection.dart';
import '../controllers/pip_collection_controller.dart';
import 'my_pip_sheet.dart';

/// A separate control: never replaces a destination or a user's avatar.
class PipCompanion extends StatefulWidget {
  const PipCompanion({super.key, this.compact = false, this.celebrate = false});
  final bool compact, celebrate;
  @override
  State<PipCompanion> createState() => _PipCompanionState();
}

class _PipCompanionState extends State<PipCompanion> {
  String? offeredOwner;
  bool sheetOpen = false;
  Future<void> open({bool celebrate = false}) async {
    if (sheetOpen) return;
    sheetOpen = true;
    try {
      await showMyPipSheet(context, celebrate: celebrate);
    } finally {
      sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PipCollectionController?>();
    if (data == null || data.userId == null) return const SizedBox.shrink();
    final value = data.collection;
    if (widget.celebrate &&
        data.verified &&
        value.celebrationPending &&
        offeredOwner != data.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            sheetOpen ||
            ModalRoute.of(context)?.isCurrent == false ||
            !data.verified ||
            !data.collection.celebrationPending) {
          return;
        }
        offeredOwner = data.userId;
        unawaited(open(celebrate: true));
      });
    }
    return Align(
        heightFactor: 1,
        alignment: widget.compact ? Alignment.centerRight : Alignment.center,
        child: TextButton(
            onPressed: () => open(),
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
            child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  Image.asset(PipCollection.asset(value.activePip),
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true),
                  const Text('My Pip'),
                  if (value.celebrationPending)
                    const Tooltip(
                        message: 'New Pip reward',
                        child: Icon(Icons.redeem_outlined, size: 18)),
                ])));
  }
}

class PipDiaryCompanion extends StatelessWidget {
  const PipDiaryCompanion({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PipCollectionController?>();
    if (data == null || data.userId == null) return const SizedBox.shrink();
    return IconButton(
        tooltip: 'My Pip',
        onPressed: () => showMyPipSheet(context),
        icon: Image.asset(PipCollection.asset(data.collection.activePip),
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            excludeFromSemantics: true));
  }
}

/// Compact access beside the Home wordmark, with a full touch target.
class PipHeaderCompanion extends StatelessWidget {
  const PipHeaderCompanion({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PipCollectionController?>();
    if (data == null || data.userId == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'My Pip',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      // Optical alignment with the wordmark’s visible letters, whose
      // centre sits slightly above the text line box. Keep the 48px target.
      padding: const EdgeInsets.fromLTRB(2, 8, 18, 12),
      onPressed: () => showMyPipSheet(context),
      icon: Image.asset(PipCollection.asset(data.collection.activePip),
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          excludeFromSemantics: true),
    );
  }
}
