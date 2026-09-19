import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/profile/data/avatar_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

class ProfileAvatarView extends StatefulWidget {
  const ProfileAvatarView({
    super.key,
    required this.avatar,
    required this.fallbackText,
    required this.fallbackColor,
    this.size = 44,
    this.useFullSize = false,
    this.profileBadges = const [],
  });

  final ProfileAvatar? avatar;
  final String fallbackText;
  final Color fallbackColor;
  final double size;

  /// Selection flows always show the original, even in a compact grid.
  final bool useFullSize;
  final List<String> profileBadges;

  @override
  State<ProfileAvatarView> createState() => _ProfileAvatarViewState();
}

class _ProfileAvatarViewState extends State<ProfileAvatarView> {
  static final AvatarUrlResolver _resolver = AvatarUrlResolver();
  Future<String>? _url;
  bool _iconFailed = false;

  bool get _usesIcon =>
      !widget.useFullSize &&
      widget.size <= 48 &&
      !_iconFailed &&
      (widget.avatar?.iconImageUrl != null ||
          widget.avatar?.iconStoragePath != null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar?.storagePath != widget.avatar?.storagePath ||
        oldWidget.avatar?.imageUrl != widget.avatar?.imageUrl ||
        oldWidget.avatar?.iconStoragePath != widget.avatar?.iconStoragePath ||
        oldWidget.avatar?.iconImageUrl != widget.avatar?.iconImageUrl ||
        oldWidget.size != widget.size ||
        oldWidget.useFullSize != widget.useFullSize) {
      _iconFailed = false;
      _load();
    }
  }

  void _load({bool retry = false}) {
    final avatar = widget.avatar;
    if (avatar == null) {
      _url = null;
      return;
    }
    final imageUrl = _usesIcon ? avatar.iconImageUrl : avatar.imageUrl;
    final storagePath = _usesIcon
        ? avatar.iconStoragePath ?? avatar.storagePath
        : avatar.storagePath;
    _url = imageUrl != null
        ? Future.value(imageUrl)
        : _resolver.resolve(storagePath, retry: retry);
  }

  void _fallBackToOriginal() {
    if (!_usesIcon) return;
    // Image errors arrive during build; change the source after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_usesIcon) return;
      setState(() {
        _iconFailed = true;
        _load();
      });
    });
  }

  void _retry() {
    setState(() => _load(retry: true));
  }

  Widget _fallback() => CircleAvatar(
        radius: widget.size / 2,
        backgroundColor: context.colors.surfaceElevated,
        child: Padding(
          padding: EdgeInsets.all(widget.size * .18),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.fallbackText.trim().toUpperCase(),
                style: TextStyle(
                  color: context.colors.primaryText,
                  fontSize: widget.size * .36,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();
    return SpecialAvatarFrame(
      badges: widget.profileBadges,
      child: avatar,
    );
  }

  Widget _buildAvatar() {
    if (_url == null) return _fallback();
    return Semantics(
      image: true,
      label: widget.avatar!.displayName,
      child: FutureBuilder<String>(
        future: _url,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (_usesIcon) {
              _fallBackToOriginal();
              return _fallback();
            }
            logger.e(
              'Unable to load avatar ${widget.avatar!.storagePath}: '
              '${snapshot.error}',
            );
            return Semantics(
              button: true,
              label: 'Avatar unavailable. Tap to retry.',
              child: GestureDetector(
                onTap: _retry,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _fallback(),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.refresh,
                        size: widget.size * .25,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return SizedBox.square(
              dimension: widget.size,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return ClipOval(
            child: CachedNetworkImage(
              imageUrl: snapshot.data!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) {
                _fallBackToOriginal();
                return _fallback();
              },
            ),
          );
        },
      ),
    );
  }
}
