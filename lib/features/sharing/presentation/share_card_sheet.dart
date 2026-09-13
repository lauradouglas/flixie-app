import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/widgets/flixie_share_cards.dart';
import 'package:flixie_app/features/sharing/services/share_card_export_service.dart';

Future<void> showShareCardSheet(
  BuildContext context,
  ShareCardData data,
) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: FlixieColors.background.withValues(alpha: .72),
    builder: (_) => ShareCardSheet(data: data),
  );
}

void promptShareCard(BuildContext context, ShareCardData data) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showFlixieToast(
    FlixieToast(
      type: FlixieToastType.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      content: const Text('Saved! Want to share your take?'),
      action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            if (context.mounted) showShareCardSheet(context, data);
          }),
    ),
  );
}

class ShareCardSheet extends StatefulWidget {
  const ShareCardSheet({super.key, required this.data});

  final ShareCardData data;

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

enum _ExportAction { share, save, invite }

class _ShareCardSheetState extends State<ShareCardSheet> {
  final _boundaryKey = GlobalKey();
  final _exportService = const ShareCardExportService();
  Color _posterAccent = FlixieColors.primary;
  bool _showNote = true;
  _ExportAction? _activeAction;
  Uint8List? _renderedBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _extractPosterColour();
  }

  Future<void> _extractPosterColour() async {
    final url = widget.data.posterUrl;
    if (url == null) return;
    try {
      final provider = CachedNetworkImageProvider(url);
      await precacheImage(provider, context);
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        maximumColorCount: 10,
      );
      final colour = palette.darkVibrantColor?.color ??
          palette.vibrantColor?.color ??
          palette.dominantColor?.color;
      if (mounted && colour != null) setState(() => _posterAccent = colour);
    } catch (_) {
      // The primary colour remains a safe, on-brand fallback.
    }
  }

  Future<Uint8List> _imageBytes() async {
    return _renderedBytes ??= await _exportService.renderPng(_boundaryKey);
  }

  Future<void> _run(_ExportAction action, BuildContext actionContext) async {
    if (_activeAction != null) return;
    setState(() {
      _activeAction = action;
      _error = null;
    });
    final box = actionContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      if (action == _ExportAction.invite) {
        final summary = await UserService.getMyReferral();
        await _exportService.shareReferralInvite(
          inviteUrl: summary.inviteUrl,
          referralCode: summary.code,
          origin: origin,
        );
        if (mounted) {
          await context.read<AnalyticsController>().friendInviteSent(
                inviteMethod: 'referral_link',
                source: 'movie_detail',
              );
        }
      } else {
        final bytes = await _imageBytes();
        if (action == _ExportAction.share) {
          await _exportService.share(
            bytes: bytes,
            data: widget.data,
            origin: origin,
          );
          if (mounted) {
            await context.read<AnalyticsController>().shareCreated(
                  shareType: widget.data.variant == ShareCardVariant.review
                      ? 'review'
                      : widget.data.mediaLabel,
                  contentType: widget.data.mediaLabel,
                  contentId: widget.data.mediaId,
                  source: widget.data.variant == ShareCardVariant.review
                      ? 'movie_detail'
                      : 'watch_history',
                );
          }
        } else {
          await _exportService.save(bytes: bytes, data: widget.data);
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.success,
                  content: const Text('Share image saved to your photos')),
            );
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final previewHeight = (screen.height * .53).clamp(340.0, 530.0);
    return ColoredBox(
      color: FlixieColors.surface,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          constraints: BoxConstraints(maxHeight: screen.height * .85),
          decoration: const BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.mediumShade,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saved - share your take',
                              style: TextStyle(
                                color: FlixieColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              )),
                          const SizedBox(height: 3),
                          Text('Made for Stories, Messages and more',
                              style: TextStyle(
                                color:
                                    FlixieColors.medium.withValues(alpha: .95),
                                fontSize: 13,
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Not now',
                      onPressed: _activeAction == null
                          ? () => Navigator.of(context).pop()
                          : null,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Center(
                    child: SizedBox(
                      height: previewHeight,
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RepaintBoundary(
                              key: _boundaryKey,
                              child: FlixieShareCard(
                                data: widget.data,
                                posterAccent: _posterAccent,
                                showNote: _showNote,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.data.variant == ShareCardVariant.rating &&
                  widget.data.note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlixieColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FlixieColors.primary.withValues(alpha: .28),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: SwitchListTile.adaptive(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: const Text(
                          'Show watch note',
                          style: TextStyle(
                            color: FlixieColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: _showNote,
                        activeThumbColor: FlixieColors.textPrimary,
                        activeTrackColor: FlixieColors.primary,
                        onChanged: _activeAction == null
                            ? (value) => setState(() {
                                  _showNote = value;
                                  _renderedBytes = null;
                                })
                            : null,
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: FlixieColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: FlixieColors.danger, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (buttonContext) => FilledButton.icon(
                          onPressed: _activeAction == null
                              ? () => _run(_ExportAction.share, buttonContext)
                              : null,
                          icon: _actionIcon(_ExportAction.share,
                              fallback: Icons.ios_share_rounded),
                          label: const Text('Share image'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (buttonContext) => OutlinedButton.icon(
                          onPressed: _activeAction == null
                              ? () => _run(_ExportAction.save, buttonContext)
                              : null,
                          icon: _actionIcon(_ExportAction.save,
                              fallback: Icons.download_rounded),
                          label: const Text('Save image'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _activeAction == null
                    ? () => Navigator.of(context).pop()
                    : null,
                child: const Text('Not now'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Builder(
                  builder: (buttonContext) => TextButton.icon(
                    onPressed: _activeAction == null
                        ? () => _run(_ExportAction.invite, buttonContext)
                        : null,
                    icon: _actionIcon(
                      _ExportAction.invite,
                      fallback: Icons.group_add_rounded,
                    ),
                    label: const Text('Join me on Flixie'),
                    style: TextButton.styleFrom(
                      foregroundColor: FlixieColors.secondary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIcon(_ExportAction action, {required IconData fallback}) {
    if (_activeAction != action) return Icon(fallback, size: 19);
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
