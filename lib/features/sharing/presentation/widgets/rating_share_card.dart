import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../share_card_quote.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/models/rating_card_style.dart';
import 'blended_share_poster.dart';

class RatingShareCard extends StatefulWidget {
  const RatingShareCard(
      {super.key,
      required this.data,
      this.style = RatingCardStyle.fullStory,
      this.background = RatingCardBackground.transparent,
      this.showNote = true,
      this.quote,
      this.pip,
      this.posterProvider,
      this.onArtworkReady});
  final ShareCardData data;
  final RatingCardStyle style;
  final RatingCardBackground background;
  final bool showNote;
  final String? quote;
  final String? pip;
  final ImageProvider? posterProvider;

  /// Called once the poster has loaded, or failed into the explicit fallback.
  final ValueChanged<bool>? onArtworkReady;

  @override
  State<RatingShareCard> createState() => _RatingShareCardState();
}

class _RatingShareCardState extends State<RatingShareCard> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _poster;
  int _generation = 0;
  Color _edge = const Color(0xFF080808);
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolved) _resolve();
  }

  @override
  void didUpdateWidget(RatingShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.posterUrl != widget.data.posterUrl ||
        oldWidget.posterProvider != widget.posterProvider) {
      _resolve();
    }
  }

  void _resolve() {
    _resolved = true;
    final generation = ++_generation;
    _detach();
    _poster?.dispose();
    _poster = null;
    _edge = const Color(0xFF080808);
    final provider = widget.posterProvider ??
        (widget.data.posterUrl == null
            ? null
            : CachedNetworkImageProvider(widget.data.posterUrl!));
    if (provider == null) {
      _notifyReady(false, generation);
      return;
    }
    _stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) async {
      if (!mounted || generation != _generation) {
        info.dispose();
        return;
      }
      _poster?.dispose();
      _poster = info;
      final image = info.image;
      try {
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (!mounted || generation != _generation) return;
        if (bytes != null) {
          // Median perimeter samples follow the poster background and avoid
          // letting a small bright subject colour flood the entire card.
          final channels = [<int>[], <int>[], <int>[]];
          void sample(int x, int y) {
            final index = (y * image.width + x) * 4;
            for (var c = 0; c < 3; c++) {
              channels[c].add(bytes.getUint8(index + c));
            }
          }

          for (var i = 0; i < 64; i++) {
            final x = ((image.width - 1) * i / 63).round();
            final y = ((image.height - 1) * i / 63).round();
            sample(x, 0);
            sample(x, image.height - 1);
            sample(0, y);
            sample(image.width - 1, y);
          }
          for (final channel in channels) {
            channel.sort();
          }
          _edge = Color.fromARGB(
              255, channels[0][128], channels[1][128], channels[2][128]);
        }
      } catch (_) {
        /* The loaded poster remains usable without edge sampling. */
      }
      if (mounted && generation == _generation) {
        setState(() {});
        _notifyReady(true, generation);
      }
    }, onError: (Object error, StackTrace? stack) {
      if (!mounted || generation != _generation) return;
      setState(() {});
      _notifyReady(false, generation);
    });
    _stream!.addListener(_listener!);
  }

  void _notifyReady(bool loaded, int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) {
        widget.onArtworkReady?.call(loaded);
      }
    });
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _generation++;
    _detach();
    _poster?.dispose();
    super.dispose();
  }

  static const _cardInk = Color(0xFF15121C);
  Color get _backgroundColor => switch (widget.background) {
        RatingCardBackground.transparent => Colors.transparent,
        RatingCardBackground.dark => _cardInk,
        RatingCardBackground.lilac => const Color(0xFFCFC0E8),
        RatingCardBackground.bone => const Color(0xFFEEE6D8),
      };
  Color get _foreground => (widget.background == RatingCardBackground.lilac ||
          widget.background == RatingCardBackground.bone)
      ? _cardInk
      : Colors.white;

  BoxDecoration? _transparentOutline(
          {BoxShape shape = BoxShape.rectangle, double radius = 0}) =>
      widget.background == RatingCardBackground.transparent
          ? BoxDecoration(
              shape: shape,
              borderRadius: shape == BoxShape.rectangle
                  ? BorderRadius.circular(radius)
                  : null,
              border: Border.all(color: Colors.white70, width: 1.5))
          : null;

  Widget _outlinedTicket({bool pocket = false}) => CustomPaint(
      foregroundPainter: widget.background == RatingCardBackground.transparent
          ? const _TicketOutline()
          : null,
      child: _ticket(pocket: pocket));

  String get _note => shareCardQuoteExcerpt(widget.quote ?? widget.data.note);
  bool get _hasNote => widget.showNote && _note.trim().isNotEmpty;

  Text _text(String text, double size,
          {Color? color,
          FontWeight weight = FontWeight.w600,
          TextAlign align = TextAlign.center,
          bool italic = false}) =>
      Text(text,
          textAlign: align,
          style: TextStyle(
              inherit: false,
              letterSpacing: 0,
              fontFamily: 'Manrope',
              fontSize: size,
              height: 1.18,
              color: color ?? _foreground,
              fontWeight: weight,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal));

  Widget _posterArea(double height, {double? width}) => SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent
                  ],
                  stops: [
                    0,
                    .06,
                    .94,
                    1
                  ]).createShader(bounds),
          child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent
                  ], stops: [
                    0,
                    .04,
                    .96,
                    1
                  ]).createShader(bounds),
              child: ColoredBox(color: _edge, child: BlendedSharePoster(image: _poster?.image)))));
  Widget _brand() => const DecoratedBox(
      decoration: BoxDecoration(
          color: Color(0xFF15121C),
          borderRadius: BorderRadius.all(Radius.circular(5))),
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: FlixieWordmark(fontSize: 22, foregroundColor: Colors.white)));
  Widget _score({Color? color, double size = 46}) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _text('${widget.data.rating}', size,
                color: color, weight: FontWeight.w900),
            _text('/10', 16, color: color)
          ]));

  String get _verdict => widget.data.neutralRecommendation
      ? 'has no recommendation'
      : widget.data.recommended == true
          ? 'recommends this'
          : widget.data.recommended == false
              ? "doesn't recommend this"
              : 'rated this';
  Widget _username({Color? color, double size = 14}) => FittedBox(
      fit: BoxFit.scaleDown,
      child: _text('@${widget.data.username}', size, color: color));

  Widget _verdictLine({Color? color, double size = 13}) => Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.data.recommended != null ||
                widget.data.neutralRecommendation) ...[
              Icon(
                  widget.data.neutralRecommendation
                      ? Icons.remove_rounded
                      : widget.data.recommended!
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_down_alt_rounded,
                  color: color ?? _foreground,
                  size: size + 1),
              const SizedBox(width: 5)
            ],
            Flexible(
                child: _text(_verdict, size,
                    color: color, weight: FontWeight.w400)),
          ]);

  Widget _attribution({Color? color, double size = 14}) => Semantics(
      label: '@${widget.data.username} $_verdict',
      child: Column(
          key: const ValueKey('share-card-attribution'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _username(color: color, size: size),
            const SizedBox(height: 3),
            _verdictLine(color: color, size: size - 1)
          ]));

  Widget _quote({Color? color, double size = 17}) =>
      _text(_note, size, color: color, italic: true, weight: FontWeight.w400);

  Widget _withPip(Widget child, {bool circle = false}) =>
      Stack(clipBehavior: Clip.none, children: [
        child,
        if (widget.pip != null)
          Positioned(
              right: circle ? 0 : 8,
              bottom: circle ? -22 : 8,
              child: Image.asset(PipCollection.asset(widget.pip!),
                  width: 76,
                  height: 88,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true))
      ]);

  double _height(String text, double width, double size,
      {FontWeight weight = FontWeight.w600, bool italic = false}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                inherit: false,
                letterSpacing: 0,
                fontFamily: 'Manrope',
                fontSize: size,
                height: 1.18,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                fontWeight: weight)),
        textDirection: Directionality.of(context))
      ..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _titleSize(double width, double preferred, double maxHeight) {
    var size = preferred;
    final words = widget.data.title.split(RegExp(r'\s+'));
    while (size > 12) {
      final word = TextPainter(
          text: const TextSpan(text: '', style: TextStyle()),
          textDirection: Directionality.of(context));
      var widest = 0.0;
      for (final part in words) {
        word.text = TextSpan(
            text: part,
            style: TextStyle(
                inherit: false,
                letterSpacing: 0,
                fontFamily: 'Manrope',
                fontSize: size,
                height: 1.18,
                fontWeight: FontWeight.w800));
        word.layout();
        widest = math.max(widest, word.width);
      }
      word.dispose();
      if (widest <= width &&
          _height(widget.data.title, width, size, weight: FontWeight.w800) <=
              maxHeight) { break; }
      size -= .5;
    }
    return size;
  }

  Widget _title(double width,
      {Color? color,
      double size = 28,
      double maxHeight = 84,
      TextAlign align = TextAlign.center}) {
    final font = _titleSize(width, size, maxHeight);
    return SizedBox(
        width: width,
        child: Text(widget.data.title,
            key: const ValueKey('share-card-title'),
            textAlign: align,
            style: TextStyle(
                inherit: false,
                letterSpacing: 0,
                fontFamily: 'Manrope',
                fontSize: font,
                height: 1.18,
                color: color ?? _foreground,
                fontWeight: FontWeight.w800)));
  }

  double _titleHeight(double width, double size, double maxHeight) =>
      _height(widget.data.title, width, _titleSize(width, size, maxHeight),
          weight: FontWeight.w800);

  double _footerHeight(double width) => widget.pip == null ? 40 : 116;

  Widget _footer({Color? color, double width = 252}) {
    if (widget.pip == null) {
      return SizedBox(
          height: 40, child: Center(child: _attribution(color: color))); }
    return SizedBox(
        height: 116,
        child: Column(children: [
          SizedBox(height: 20, child: _username(color: color)),
          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.only(right: 72),
              child: _verdictLine(color: color)),
        ]));
  }

  Widget _fullStory() {
    const width = 312.0;
    final dense = _titleHeight(width, 30, 84) > 55 ||
        (_hasNote &&
            _height(_note, width, 17, weight: FontWeight.w400, italic: true) >
                60);
    final titleSize = dense ? 26.0 : 30.0;
    final titleMaxHeight = dense ? 72.0 : 84.0;
    final quoteSize = dense ? 16.0 : 17.0;
    final titleHeight = _titleHeight(width, titleSize, titleMaxHeight);
    final quoteHeight = _hasNote
        ? _height(_note, width, quoteSize,
                weight: FontWeight.w400, italic: true) +
            10
        : 0.0;
    final verticalPadding = dense ? 44.0 : 58.0;
    final headerHeight = dense ? 34.0 : 38.0;
    final scoreHeight = dense ? 54.0 : 60.0;
    final posterHeight = 640 -
        verticalPadding -
        headerHeight -
        12 -
        scoreHeight -
        8 -
        titleHeight -
        quoteHeight -
        10 -
        (widget.pip == null ? 40 : 72);
    return Container(
        width: 360,
        height: 640,
        key: const ValueKey('rating-card-surface'),
        foregroundDecoration: _transparentOutline(radius: 14),
        color: _backgroundColor,
        padding: EdgeInsets.fromLTRB(24, dense ? 24 : 34, 24, dense ? 20 : 24),
        child: Column(children: [
          SizedBox(
              height: headerHeight,
              child: Row(children: [
                _brand(),
                const SizedBox(width: 16),
                Expanded(
                    child: Align(
                        alignment: Alignment.centerRight, child: _username()))
              ])),
          const SizedBox(height: 12),
          SizedBox(
              height: math.max(40, posterHeight),
              child: _posterArea(double.infinity)),
          SizedBox(height: scoreHeight, child: _score(size: dense ? 44 : 50)),
          const SizedBox(height: 8),
          _title(width, size: titleSize, maxHeight: titleMaxHeight),
          if (_hasNote) ...[
            const SizedBox(height: 10),
            _quote(size: quoteSize)
          ],
          const SizedBox(height: 10),
          SizedBox(height: widget.pip == null ? 40 : 72,
            child: Row(children: [
              Expanded(child: _attribution()),
              if (widget.pip != null) ...[
                const SizedBox(width: 12),
                Image.asset(PipCollection.asset(widget.pip!),
                  key: const ValueKey('full-story-pip'),
                  width: 64, height: 72, fit: BoxFit.contain,
                  excludeFromSemantics: true),
              ],
            ])),
        ]));
  }

  Widget _sticker() {
    const width = 244.0, detailWidth = 128.0;
    final longTitle = _titleSize(detailWidth, 23, 72) < 18;
    return Container(
      width: 292,
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border.all(color: Colors.white, width: 4),
        borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _brand(),
          if (widget.pip != null)
            Image.asset(PipCollection.asset(widget.pip!),
              key: const ValueKey('sticker-top-pip'),
              width: 56, height: 62, fit: BoxFit.contain,
              excludeFromSemantics: true),
        ]),
        const SizedBox(height: 14),
        if (longTitle) ...[
          _title(width, size: 25, maxHeight: 110, align: TextAlign.left),
          const SizedBox(height: 12),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 100, height: 150,
            child: _poster == null
              ? Center(child: _text('Poster unavailable', 12))
              : RawImage(image: _poster!.image, fit: BoxFit.contain,
                  key: const ValueKey('sticker-intact-poster'))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!longTitle) ...[
                _title(detailWidth, size: 23, maxHeight: 72, align: TextAlign.left),
                const SizedBox(height: 12),
              ],
              _score(size: 42),
            ])),
        ]),
        if (_hasNote) ...[const SizedBox(height: 12), _quote(size: 16)],
        const SizedBox(height: 16),
        _attribution(size: 13),
      ]));
  }

  Widget _ticket({bool pocket = false}) {
    const width = 260.0;
    final paper = _backgroundColor;
    final ink = _foreground;
    final longTitle =
        _titleSize(154, 23, 60) < 18 || _titleHeight(154, 23, 60) > 55;
    Widget poster(double height) => SizedBox(
        height: height,
        child: _poster == null
            ? const Center(child: Text('Poster unavailable'))
            : RawImage(
                image: _poster!.image,
                fit: BoxFit.contain,
                key: const ValueKey('ticket-intact-poster')));
    final title = _title(longTitle || !pocket ? width : 154,
        color: ink, size: 25, maxHeight: 100, align: TextAlign.left);
    return ClipPath(
      clipper: const _TicketClipper(),
      child: Container(
          width: 300,
          color: paper,
          key: const ValueKey('ticket-surface'),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _withPip(Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    _brand(),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: _username(color: ink, size: 12)))
                  ]),
                  const SizedBox(height: 14),
                  if (pocket) ...[
                    if (longTitle) ...[title, const SizedBox(height: 10)],
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 94, child: poster(141)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                if (!longTitle) title,
                                const SizedBox(height: 10),
                                _score(color: ink, size: 36)
                              ])),
                        ]),
                  ] else ...[
                    poster(_hasNote && _note.length > 80 ? 170 : 210),
                    const SizedBox(height: 14),
                    if (longTitle) ...[
                      title,
                      const SizedBox(height: 6),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: _score(color: ink, size: 32))
                    ] else
                      Row(children: [
                        Expanded(
                            child: _title(154,
                                color: ink, size: 23, align: TextAlign.left)),
                        const SizedBox(width: 8),
                        SizedBox(width: 98, child: _score(color: ink, size: 32))
                      ]),
                  ],
                  if (_hasNote) ...[
                    const SizedBox(height: 10),
                    _quote(color: ink, size: 16)
                  ],
                  const SizedBox(height: 10),
                  _footer(color: ink, width: width),
                ]))),
            CustomPaint(
                size: const Size(264, 1), painter: _TicketPerforation(ink)),
            SizedBox(
                height: 120,
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            _text('ADMISSION 1', 12,
                                color: ink, weight: FontWeight.w800),
                            const SizedBox(height: 8),
                            _text('Find your next film', 14,
                                color: ink, align: TextAlign.left),
                            const SizedBox(height: 4),
                            _text('flixie.co.uk', 11, color: ink),
                          ])),
                      const SizedBox(width: 12),
                      SvgPicture.asset('assets/images/flixie-share-qr.svg',
                          width: 90,
                          height: 90,
                          semanticsLabel:
                              'Scan to open https://www.flixie.co.uk/',
                          key: const ValueKey('ticket-flixie-qr')),
                    ]))),
          ])),
    );
  }

  Widget _polaroid() {
    const width = 250.0;
    final titleHeight = _titleHeight(width, 25, 84);
    final quoteHeight = _hasNote
        ? _height(_note, width, 17, weight: FontWeight.w400, italic: true) + 12
        : 0.0;
    final posterHeight = (540 -
            50 -
            titleHeight -
            quoteHeight -
            12 -
            44 -
            18 -
            _footerHeight(width))
        .clamp(120.0, 300.0);
    return Transform.rotate(
        angle: -.055,
        child: Container(
            width: 282,
            foregroundDecoration: _transparentOutline(),
            padding: const EdgeInsets.all(12),
            color: _backgroundColor,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ColoredBox(color: _edge, child: _posterArea(posterHeight)),
              Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _title(width, color: _foreground, size: 25),
                    if (_hasNote) ...[
                      const SizedBox(height: 8),
                      _quote(color: _foreground)
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                        height: 44,
                        child: Row(children: [
                          Expanded(
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _score(color: _foreground, size: 32))),
                          const SizedBox(width: 12),
                          _brand()
                        ])),
                    const SizedBox(height: 12),
                    Row(
                        key: const ValueKey('polaroid-attribution-row'),
                        children: [
                          Expanded(
                              child:
                                  _attribution(color: _foreground, size: 13)),
                          if (widget.pip != null) ...[
                            const SizedBox(width: 10),
                            Image.asset(PipCollection.asset(widget.pip!),
                                key: const ValueKey('polaroid-pip'),
                                width: 64,
                                height: 72,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true),
                          ],
                        ]),
                  ])),
            ])));
  }

  Widget _circle() {
    const diameter = 312.0, titleWidth = 224.0;
    final titleOutside =
        _height(widget.data.title, titleWidth, 16, weight: FontWeight.w800) >
            60;
    final quoteOutside = _hasNote &&
        _height(_note, 224, 16, weight: FontWeight.w400, italic: true) > 20;
    final titleHeight = titleOutside ? 0.0 : _titleHeight(titleWidth, 24, 60);
    final middleTop = titleOutside ? 72.0 : 68 + titleHeight + 8;
    final inlineQuote = _hasNote && !quoteOutside;
    final middleBottom = inlineQuote ? 206.0 : 222.0;
    final circle = _withPip(
        ClipOval(
            child: Container(
                width: diameter,
                height: diameter,
                foregroundDecoration:
                    _transparentOutline(shape: BoxShape.circle),
                color: _backgroundColor,
                child: Stack(children: [
                  Positioned(
                      top: 28,
                      left: 80,
                      right: 80,
                      height: 32,
                      child: Center(child: _brand())),
                  if (!titleOutside)
                    Positioned(
                        top: 68,
                        left: 44,
                        right: 44,
                        child: _title(titleWidth, size: 24, maxHeight: 60)),
                  Positioned(
                      top: middleTop,
                      left: 48,
                      right: 48,
                      height: middleBottom - middleTop,
                      child: Row(children: [
                        SizedBox(
                            width: 90, child: _posterArea(double.infinity)),
                        const SizedBox(width: 14),
                        Expanded(child: _score(size: 44))
                      ])),
                  if (inlineQuote)
                    Positioned(
                        top: 212,
                        left: 44,
                        right: 44,
                        height: 20,
                        child: _text(_note, 16,
                            italic: true, weight: FontWeight.w400)),
                  Positioned(
                      top: 238,
                      left: 66,
                      right: 66,
                      height: 48,
                      child: Center(child: _attribution(size: 12))),
                ]))),
        circle: true);
    if (!titleOutside && !quoteOutside) return circle;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      circle,
      SizedBox(height: widget.pip == null ? 12 : 28),
      Container(
          width: 292,
          foregroundDecoration: _transparentOutline(radius: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _backgroundColor, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (titleOutside) _title(256, size: 24),
            if (titleOutside && quoteOutside) const SizedBox(height: 10),
            if (quoteOutside) _quote(),
          ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (widget.style) {
      RatingCardStyle.posterSticker => _sticker(),
      RatingCardStyle.cinemaTicket => _outlinedTicket(),
      RatingCardStyle.pocketTicket => _outlinedTicket(pocket: true),
      RatingCardStyle.polaroid => _polaroid(),
      RatingCardStyle.circleStamp => _circle(),
      RatingCardStyle.fullStory => _fullStory(),
    };
    return MediaQuery.withNoTextScaling(
        child: SizedBox(
            width: 360,
            height: 640,
            child: ColoredBox(
                color: Colors.transparent,
                child: Center(
                    child: Padding(
                        padding: EdgeInsets.all(
                            widget.style == RatingCardStyle.fullStory ? 0 : 24),
                        child: FittedBox(
                            fit: BoxFit.scaleDown, child: content))))));
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();
  @override
  Path getClip(Size size) {
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(14)));
    final holes = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(0, size.height - 120), radius: 12))
      ..addOval(Rect.fromCircle(
          center: Offset(size.width, size.height - 120), radius: 12));
    return Path.combine(PathOperation.difference, outer, holes);
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) => false;
}

class _TicketPerforation extends CustomPainter {
  const _TicketPerforation(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(
          Offset(x, 0), Offset(math.min(x + 4, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_TicketPerforation oldDelegate) =>
      color != oldDelegate.color;
}

class _TicketOutline extends CustomPainter {
  const _TicketOutline();
  @override
  void paint(Canvas canvas, Size size) {
    final path = const _TicketClipper().getClip(size);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketOutline oldDelegate) => false;
}
