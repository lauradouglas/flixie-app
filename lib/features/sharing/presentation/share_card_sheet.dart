import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import '../models/rating_card_style.dart';
import 'share_card_quote.dart';
import 'quick_share_sheet.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/widgets/flixie_share_cards.dart';
import 'package:flixie_app/features/sharing/services/share_card_export_service.dart';

Future<void> showShareCardSheet(
  BuildContext context,
  ShareCardData data,
) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: context.colors.surface,
        body: ShareCardSheet(data: data),
      ),
    ),
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
  const ShareCardSheet(
      {super.key,
      required this.data,
      this.posterProvider,
      this.exportService = const ShareCardExportService()});

  final ShareCardData data;
  final ImageProvider? posterProvider;
  final ShareCardExportService exportService;

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

enum _ExportAction { share, save, invite }

class _ShareCardSheetState extends State<ShareCardSheet> {
  final _boundaryKey = GlobalKey();
  final _ticketTypesKey = GlobalKey();
  ShareCardExportService get _exportService => widget.exportService;
  Color _posterAccent = FlixieColors.primary;
  bool _showNote = true;
  late final TextEditingController _quoteController =
      TextEditingController(text: shareCardQuoteExcerpt(widget.data.note));
  RatingCardStyle _style = RatingCardStyle.fullStory;
  RatingCardStyle _lastTicketStyle = RatingCardStyle.cinemaTicket;
  bool get _isTicket =>
      _style == RatingCardStyle.cinemaTicket ||
      _style == RatingCardStyle.pocketTicket;
  RatingCardBackground _background = RatingCardBackground.bone;
  int _editorTab = 0;
  bool _savedToPhotos = false;
  String? _pip;
  String? _effectivePip;
  bool _artworkReady = false;
  bool _posterFailed = false;
  int _artworkGeneration = 0;
  _ExportAction? _activeAction;
  Uint8List? _renderedBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _artworkReady =
        widget.data.posterUrl == null && widget.posterProvider == null;
    if (widget.data.variant == ShareCardVariant.review) _extractPosterColour();
  }

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
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
    if (!_artworkReady && widget.data.variant == ShareCardVariant.rating) {
      throw StateError('Please wait for the poster to load.');
    }
    final pip = _effectivePip;
    if (pip != null) {
      var pipFailed = false;
      await precacheImage(
          AssetImage(pip == 'cinemaClub'
              ? 'assets/icon/pip_cosmetics/cinema_club.png'
              : 'assets/icon/pip_cosmetics/classic.png'),
          context, onError: (Object error, StackTrace? stack) {
        pipFailed = true;
      });
      if (pipFailed) {
        throw StateError('Pip could not load. Choose None and try again.');
      }
    }
    if (!mounted) throw StateError('The share editor was closed.');
    // The pinned actions remain reachable when the preview has scrolled away.
    // Bring its repaint boundary back into the painted viewport before capture.
    if (_renderedBytes == null && _boundaryKey.currentContext != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      await Scrollable.ensureVisible(_boundaryKey.currentContext!);
    }
    return _renderedBytes ??= await _exportService.renderPng(_boundaryKey);
  }

  Future<void> _run(_ExportAction action, BuildContext actionContext) async {
    if (_activeAction != null) return;
    setState(() {
      _activeAction = action;
      _error = null;
      _savedToPhotos = false;
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
            setState(() => _savedToPhotos = true);
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

  Future<void> _quickShare(BuildContext actionContext) async {
    final share = await showQuickShareSheet(context,
      saveCard: () async {
        await _run(_ExportAction.save, actionContext);
        if (_error != null) throw StateError(_error!);
      },
      copyReferralLink: _exportService.copyReferralLink,
    );
    if (share == true && mounted && actionContext.mounted) {
      await _run(_ExportAction.share, actionContext);
    }
  }

  void _change(VoidCallback change) {
    setState(() {
      change();
      _renderedBytes = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isRating = widget.data.variant == ShareCardVariant.rating;
    final pips = context.watch<PipCollectionController?>();
    final viewer = context.watch<AuthProvider?>()?.dbUser?.id;
    final cinemaOwned = viewer != null &&
        pips?.userId == viewer &&
        pips?.verified == true &&
        pips!.collection.cinemaUnlocked;
    final effectivePip = _pip == 'cinemaClub' && !cinemaOwned ? null : _pip;
    if (_effectivePip != effectivePip) {
      _renderedBytes = null;
    }
    _effectivePip = effectivePip;
    final busy = _activeAction != null;
    return SizedBox.expand(
        child: Material(
            color: context.colors.surface,
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(children: [
                    Expanded(
                        child: Text('Share your take',
                            style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800))),
                    IconButton(
                        tooltip: 'Close',
                        onPressed:
                            busy ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded))
                  ])),
              Expanded(
                  child: SingleChildScrollView(
                      key: const ValueKey('share-card-options-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _preview(screen, effectivePip),
                            if (isRating && !_artworkReady)
                              const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('Loading poster…',
                                      textAlign: TextAlign.center)),
                            if (isRating && _posterFailed)
                              Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                        'Poster unavailable. Share without it, or'),
                                    TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => _change(() {
                                                  _artworkReady = false;
                                                  _posterFailed = false;
                                                  _artworkGeneration++;
                                                }),
                                        child: const Text('Retry poster'))
                                  ]),
                            if (isRating)
                              ..._ratingOptions(
                                  busy, cinemaOwned, effectivePip),
                            if (!isRating)
                              Builder(
                                  builder: (buttonContext) => TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => _run(_ExportAction.invite,
                                              buttonContext),
                                      icon: _actionIcon(_ExportAction.invite,
                                          fallback: Icons.group_add_rounded),
                                      label: const Text('Join me on Flixie'))),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: context.colors.danger))),
                          ]))),
              Padding(
                  key: const ValueKey('share-editor-actions'),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_savedToPhotos)
                      const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Image saved to your photos',
                              semanticsLabel: 'Image saved to your photos')),
                    _exportButtons(!busy && (!isRating || _artworkReady)),
                    const SizedBox(height: 8),
                    const Text('Send to friends, or save for your Story.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFFC7BBD5))),
                  ])),
            ]))));
  }

  // Zoom only the editor presentation; the export boundary stays 360 × 640.
  double get _previewZoom {
    if (widget.data.variant != ShareCardVariant.rating ||
        widget.data.title.length > 35 ||
        (_showNote && _quoteController.text.length > 70)) { return 1; }
    return switch (_style) {
      RatingCardStyle.circleStamp => 1.45,
      RatingCardStyle.posterSticker => 1.25,
      RatingCardStyle.pocketTicket => 1.12,
      _ => 1,
    };
  }

  Widget _preview(Size screen, String? pip) => Center(
      child: SizedBox(
          height: (screen.height * .38).clamp(180.0, 350.0),
          child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Transform.scale(
                  key: const ValueKey('share-preview-zoom'),
                  scale: _previewZoom,
                  child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                          key: _boundaryKey,
                          child: FlixieShareCard(
                            key: ValueKey(_artworkGeneration),
                            data: widget.data,
                            posterAccent: _posterAccent,
                            showNote: _showNote,
                            quote: _quoteController.text,
                            style: _style,
                            background: _background,
                            pip: pip,
                            posterProvider: widget.posterProvider,
                            onArtworkReady: (loaded) {
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _artworkReady = true;
                                _posterFailed = !loaded &&
                                    (widget.data.posterUrl != null ||
                                        widget.posterProvider != null);
                                _renderedBytes = null;
                              });
                            },
                          )))))));

  List<Widget> _ratingOptions(
          bool busy, bool cinemaOwned, String? effectivePip) =>
      [
        const SizedBox(height: 16),
        DecoratedBox(
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: context.colors.mediumShade
                            .withValues(alpha: .25)))),
            child: Row(children: [
              for (final entry
                  in ['Style', 'Colour', 'Pip', 'Note'].asMap().entries)
                Expanded(
                    child: Semantics(
                        selected: _editorTab == entry.key,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: _editorTab == entry.key
                                          ? const Color(0xFFBA8AFF)
                                          : Colors.transparent,
                                      width: 2))),
                          child: TextButton(
                              key: ValueKey('share-tab-${entry.key}'),
                              style: TextButton.styleFrom(
                                  foregroundColor: _editorTab == entry.key
                                      ? const Color(0xFFE0C9FF)
                                      : context.colors.mediumShade,
                                  backgroundColor: Colors.transparent,
                                  shape: const RoundedRectangleBorder(),
                                  minimumSize: const Size(44, 48)),
                              onPressed: busy
                                  ? null
                                  : () =>
                                      setState(() => _editorTab = entry.key),
                              child: Text(entry.value)),
                        ))),
            ])),
        const SizedBox(height: 12),
        if (_editorTab == 0) ...[
          Padding(padding: const EdgeInsets.only(bottom: 10),
              child: Text('${_isTicket ? 'Ticket' : _style.label} · Swipe for more',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFD9CFE5)))),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final style in RatingCardStyle.values.where(
                  (style) => style != RatingCardStyle.pocketTicket))
                Padding(padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(width: 114, child: _styleTile(style, busy))),
            ]),
          ),
          if (_isTicket) ...[
            const SizedBox(height: 16),
            Text('Ticket type', key: _ticketTypesKey,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, constraints) {
              final width = MediaQuery.textScalerOf(context).scale(14) > 20
                  ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final type in [RatingCardStyle.cinemaTicket, RatingCardStyle.pocketTicket])
                  SizedBox(width: width, child: _styleTile(type, busy, subtype: true)),
              ]);
            }),
          ],
        ],
        if (_editorTab == 1) ...[
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(12) > 18 ? 2 : 4;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(spacing: 10, runSpacing: 12, children: [
              for (final background in RatingCardBackground.values)
                SizedBox(width: width, child: _colourSwatch(background, busy)),
            ]);
          }),
        ],
        if (_editorTab == 2)
          Wrap(spacing: 12, runSpacing: 12, children: [
            _pipTile('None', null, null, effectivePip, busy),
            _pipTile('Classic', 'classic', 'assets/icon/pip_cosmetics/classic.png', effectivePip, busy),
            if (cinemaOwned)
              _pipTile('Cinema Club', 'cinemaClub', 'assets/icon/pip_cosmetics/cinema_club.png', effectivePip, busy),
          ]),
        if (_editorTab == 3 && widget.data.note == null)
          const Text('No diary note for this rating.'),
        if (_editorTab == 3 && widget.data.note != null) ...[
          SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show diary note'),
              value: _showNote,
              onChanged:
                  busy ? null : (value) => _change(() => _showNote = value)),
          if (_showNote)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                    controller: _quoteController,
                    enabled: !busy,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: shareCardQuoteLimit,
                    decoration: InputDecoration(
                        labelText: 'Share quote',
                        helperMaxLines: 4,
                        helperText: (widget.data.note?.characters.length ?? 0) >
                                shareCardQuoteLimit
                            ? 'An excerpt of your longer note. Edit this quote; your diary note stays unchanged.'
                            : 'Only changes the share card. Your diary note stays unchanged.'),
                    onChanged: (_) => _change(() {}))),
        ],
        if (_editorTab == 3)
          Builder(
              builder: (buttonContext) => TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => _run(_ExportAction.invite, buttonContext),
                  icon: _actionIcon(_ExportAction.invite,
                      fallback: Icons.group_add_rounded),
                  label: const Text('Join me on Flixie'))),
      ];

  Widget _colourSwatch(RatingCardBackground background, bool busy) {
    final selected = _background == background;
    final colour = switch (background) {
      RatingCardBackground.transparent => Colors.transparent,
      RatingCardBackground.dark => const Color(0xFF15121C),
      RatingCardBackground.lilac => const Color(0xFFCFC0E8),
      RatingCardBackground.bone => const Color(0xFFEEE6D8),
    };
    final light = background == RatingCardBackground.lilac ||
        background == RatingCardBackground.bone;
    return ChoiceChip(
      showCheckmark: false,
      selected: selected,
      backgroundColor: Colors.transparent,
      selectedColor: Colors.transparent,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(vertical: 8),
      labelPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: busy ? null : (_) => _change(() => _background = background),
      label: SizedBox(width: double.infinity, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62, height: 62,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(width: 2,
                    color: selected ? const Color(0xFFBA8AFF) : Colors.transparent)),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: colour,
                  border: Border.all(color: const Color(0xFF80718E))),
              child: Center(child: selected
                  ? Icon(Icons.check_rounded, size: 25,
                      color: light ? const Color(0xFF241A2E) : Colors.white)
                  : background == RatingCardBackground.transparent
                      ? const Icon(Icons.texture_rounded, size: 28, color: Color(0xFFC7BBD5))
                      : null),
            ),
          ),
          const SizedBox(height: 8),
          Text(background.label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? const Color(0xFFE0C9FF) : const Color(0xFFDDD4E6))),
        ],
      )),
    );
  }

  Widget _styleTile(RatingCardStyle style, bool busy, {bool subtype = false}) {
    final selected = !subtype && style == RatingCardStyle.cinemaTicket
        ? _isTicket : _style == style;
    final label = !subtype && style == RatingCardStyle.cinemaTicket ? 'Ticket' : style.label;
    return ChoiceChip(
      showCheckmark: false,
      selectedColor: const Color(0xFF292137),
      backgroundColor: const Color(0xFF211A2C),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(color: selected ? const Color(0xFFBA8AFF) : const Color(0xFF41364E)),
      label: SizedBox(width: double.infinity, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: subtype ? 72 : 52, child: Stack(alignment: Alignment.center, children: [
            Center(child: CustomPaint(size: Size(subtype ? 60 : 44, subtype ? 70 : 50),
                painter: _StyleThumbnail(style))),
            if (selected) const Positioned(top: 0, right: 0,
              child: Icon(Icons.check_circle, size: 16, color: Color(0xFFBA8AFF))),
          ])),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFFF4EFFA))),
          if (subtype) ...[
            const SizedBox(height: 4),
            Text(style == RatingCardStyle.pocketTicket ? 'Small & social' : 'Poster in focus',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFFD9CFE5))),
          ] else
            Text(style == RatingCardStyle.cinemaTicket ? '2 layouts ↓' :
                style == RatingCardStyle.fullStory ? 'Story size' : 'Cut-out',
                style: const TextStyle(fontSize: 11, color: Color(0xFFD9CFE5))),
        ])),
      selected: selected,
      onSelected: busy ? null : (_) => _change(() {
        if (_isTicket) _lastTicketStyle = _style;
        _style = !subtype && style == RatingCardStyle.cinemaTicket ? _lastTicketStyle : style;
        if (_isTicket) {
          _lastTicketStyle = _style;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final target = _ticketTypesKey.currentContext;
            if (mounted && target != null) { Scrollable.ensureVisible(target,
              duration: const Duration(milliseconds: 200), alignment: .5); }
          });
        }
      }),
    );
  }

  Widget _pipTile(String label, String? value, String? asset,
      String? selectedPip, bool busy) {
    final selected = selectedPip == value;
    return SizedBox(width: 104, child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(label: label, selected: selected, button: true,
          child: InkWell(
            key: ValueKey('pip-option-$label'),
            borderRadius: BorderRadius.circular(12),
            onTap: busy ? null : () => _change(() => _pip = value),
            child: Ink(width: 104, height: 104,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFDCC3FF) : context.colors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? const Color(0xFFBA8AFF) : Colors.transparent, width: 2)),
              child: Stack(alignment: Alignment.center, children: [
                if (asset != null) Image.asset(asset, width: 80, height: 80,
                  fit: BoxFit.contain, excludeFromSemantics: true)
                else Icon(Icons.block_rounded, size: 32,
                  color: selected ? const Color(0xFF241A2E) : context.colors.textPrimary),
                if (selected) const Positioned(top: 5, right: 5,
                  child: Icon(Icons.check_circle, size: 18, color: Color(0xFF241A2E))),
              ])))),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center),
      ]));
  }

  Widget _exportButtons(bool enabled) =>
      LayoutBuilder(builder: (context, constraints) {
        final buttons = [
          Builder(
              builder: (buttonContext) => FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: enabled
                      ? () => _quickShare(buttonContext)
                      : null,
                  icon: _actionIcon(_ExportAction.share,
                      fallback: Icons.ios_share_rounded),
                  label: const Text('Share…'))),
          Builder(
              builder: (buttonContext) => OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE9DFF2),
                      side: const BorderSide(color: Color(0xFF514260)),
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: enabled
                      ? () => _run(_ExportAction.save, buttonContext)
                      : null,
                  icon: _actionIcon(_ExportAction.save,
                      fallback: Icons.download_rounded),
                  label: const Text('Save'))),
        ];
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [buttons[0], const SizedBox(height: 6), buttons[1]]);
        }
        return Row(children: [
          Flexible(flex: 2, child: buttons[1]),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: buttons[0])
        ]);
      });

  Widget _actionIcon(_ExportAction action, {required IconData fallback}) {
    if (_activeAction != action) return Icon(fallback, size: 19);
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Preview-only checkerboard: deliberately outside the exported boundary.
class ShareTransparencyPainter extends CustomPainter {
  const ShareTransparencyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    for (var row = 0; row < (size.height / cell).ceil(); row++) {
      for (var column = 0; column < (size.width / cell).ceil(); column++) {
        canvas.drawRect(
            Rect.fromLTWH(
                column * cell,
                row * cell,
                math.min(cell, size.width - column * cell),
                math.min(cell, size.height - row * cell)),
            Paint()
              ..color = (row + column).isEven
                  ? const Color(0xFFE8E3EE)
                  : const Color(0xFFCCC5D6));
      }
    }
  }

  @override
  bool shouldRepaint(ShareTransparencyPainter oldDelegate) => false;
}

/// Small layout diagrams distinguish shapes without loading another poster.
class _StyleThumbnail extends CustomPainter {
  const _StyleThumbnail(this.style);
  final RatingCardStyle style;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 60, size.height / 72);
    final paper = Paint()..color = const Color(0xFFEEE6D8);
    final ink = Paint()..color = const Color(0xFF544263);
    final art = Paint()..color = const Color(0xFFB9A2CE);
    final circle = style == RatingCardStyle.circleStamp;
    final pocket = style == RatingCardStyle.pocketTicket || style == RatingCardStyle.posterSticker;
    final ticket = style == RatingCardStyle.cinemaTicket || style == RatingCardStyle.pocketTicket;
    final rect = Rect.fromLTWH(8, pocket ? 12 : 2, 44, pocket ? 48 : 68);
    if (circle) {
      canvas.drawCircle(const Offset(30, 36), 27, paper);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect,
          Radius.circular(style == RatingCardStyle.polaroid ? 1 : 5)), paper);
    }
    final poster = circle || pocket
        ? const Rect.fromLTWH(14, 22, 15, 23)
        : const Rect.fromLTWH(14, 10, 32, 36);
    canvas.drawRRect(RRect.fromRectAndRadius(poster, const Radius.circular(1)), art);
    canvas.drawCircle(poster.center.translate(0, -3), 4, ink);
    canvas.drawRect(Rect.fromLTWH(poster.left + 3, poster.bottom - 7, poster.width - 6, 4), ink);
    for (var i = 0; i < 2; i++) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(
          circle || pocket ? 33 : 14, circle || pocket ? 26 + i * 7.0 : 51 + i * 6.0,
          circle || pocket ? 13 : 25 - i * 7.0, 3), const Radius.circular(1)), ink);
    }
    if (ticket) {
      final y = rect.bottom - 10;
      for (double x = 12; x < 49; x += 5) {
        canvas.drawRect(Rect.fromLTWH(x, y, 3, 1), ink);
      }
      canvas.drawRect(Rect.fromLTWH(40, y + 3, 5, 5), ink);
      final notch = Paint()..color = const Color(0xFF292137);
      canvas.drawCircle(Offset(8, y), 3, notch);
      canvas.drawCircle(Offset(52, y), 3, notch);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(_StyleThumbnail oldDelegate) => oldDelegate.style != style;
}
