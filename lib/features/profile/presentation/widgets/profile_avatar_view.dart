import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/profile/data/avatar_service.dart';

class ProfileAvatarView extends StatefulWidget {
  const ProfileAvatarView({
    super.key,
    required this.avatar,
    required this.fallbackText,
    required this.fallbackColor,
    this.size = 44,
  });

  final ProfileAvatar? avatar;
  final String fallbackText;
  final Color fallbackColor;
  final double size;

  @override
  State<ProfileAvatarView> createState() => _ProfileAvatarViewState();
}

class _ProfileAvatarViewState extends State<ProfileAvatarView> {
  static final AvatarUrlResolver _resolver = AvatarUrlResolver();
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar?.storagePath != widget.avatar?.storagePath) _load();
  }

  void _load({bool retry = false}) {
    final avatar = widget.avatar;
    _url = avatar == null
        ? null
        : avatar.imageUrl != null
            ? Future.value(avatar.imageUrl)
            : _resolver.resolve(avatar.storagePath, retry: retry);
  }

  void _retry() {
    setState(() => _load(retry: true));
  }

  Widget _fallback() => CircleAvatar(
        radius: widget.size / 2,
        backgroundColor: widget.fallbackColor.withValues(alpha: 0.25),
        child: Text(widget.fallbackText,
            style: TextStyle(color: widget.fallbackColor)),
      );

  @override
  Widget build(BuildContext context) {
    if (_url == null) return _fallback();
    return Semantics(
      image: true,
      label: widget.avatar!.displayName,
      child: FutureBuilder<String>(
        future: _url,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
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
              errorWidget: (_, __, ___) => _fallback(),
            ),
          );
        },
      ),
    );
  }
}
