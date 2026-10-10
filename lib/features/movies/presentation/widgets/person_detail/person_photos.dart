import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/person.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class PersonPhotosSection extends StatelessWidget {
  const PersonPhotosSection(
      {super.key,
      required this.images,
      required this.loading,
      required this.onViewAll,
      required this.onOpen});
  final List<PersonImage> images;
  final bool loading;
  final VoidCallback onViewAll;
  final ValueChanged<int> onOpen;
  @override
  Widget build(BuildContext context) {
    if (loading && images.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos',
            style: TextStyle(
              color: context.colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(
            height: 150,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  SkeletonBox(width: 100, height: 150, borderRadius: 12),
                  SizedBox(width: 10),
                  SkeletonBox(width: 100, height: 150, borderRadius: 12),
                  SizedBox(width: 10),
                  SkeletonBox(width: 225, height: 150, borderRadius: 12),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Photos',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onViewAll(),
              child: Text(
                'See all (${images.length})',
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final image = images[index];
              final width =
                  (150 * (image.aspectRatio ?? .67)).clamp(100.0, 240.0);
              return InkWell(
                onTap: () => onOpen(index),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: image.thumbnailUrl,
                    width: width,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => SkeletonBox(
                      width: width,
                      height: 150,
                      borderRadius: 12,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: width,
                      color: context.colors.surface,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: context.colors.medium,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PersonPhotoGridScreen extends StatelessWidget {
  const PersonPhotoGridScreen(
      {super.key, required this.person, required this.images});

  final Person person;
  final List<PersonImage> images;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${person.name} photos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${images.length} images',
              style: TextStyle(
                color: context.colors.medium,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 700 ? 4 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: .78,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) => Semantics(
            button: true,
            label: 'Open photo ${index + 1} of ${images.length}',
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, animation, __) => FadeTransition(
                    opacity: animation,
                    child: PersonPhotoViewer(
                      personName: person.name,
                      images: images,
                      initialIndex: index,
                    ),
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: images[index].thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(
                    color: context.colors.surface,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: FlixieColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: context.colors.surface,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: context.colors.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PersonPhotoViewer extends StatefulWidget {
  const PersonPhotoViewer({
    super.key,
    required this.personName,
    required this.images,
    required this.initialIndex,
  });

  final String personName;
  final List<PersonImage> images;
  final int initialIndex;

  @override
  State<PersonPhotoViewer> createState() => PersonPhotoViewerState();
}

class PersonPhotoViewerState extends State<PersonPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, index) => InteractiveViewer(
                key: ValueKey(widget.images[index].imageUrl),
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index].originalUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                        color: FlixieColors.primary,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.broken_image_outlined,
                      color: context.colors.medium,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .65),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              top: 14,
              right: 16,
              child: FlixiePill.label(
                  label: Text('${_index + 1} / ${widget.images.length}')),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Text(
                widget.personName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
