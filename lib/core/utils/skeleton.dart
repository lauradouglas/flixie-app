import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

/// Animated shimmer box used to build skeleton loading layouts.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.65).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBorder.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home screen skeleton
// ---------------------------------------------------------------------------

class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting and the four quick actions.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 28, height: 28, borderRadius: 14),
                    SizedBox(width: 9),
                    SkeletonBox(width: 190, height: 17, borderRadius: 5),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 53, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 53, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 53, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 53, borderRadius: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Watch plans shortcut.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Container(
              height: 76,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlixieColors.tabBarBackgroundFocused,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: FlixieColors.tabBarBorder.withValues(alpha: 0.7)),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 46, height: 46, borderRadius: 12),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonBox(width: 112, height: 16, borderRadius: 5),
                        SizedBox(height: 7),
                        SkeletonBox(width: 210, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 20, height: 20, borderRadius: 6),
                ],
              ),
            ),
          ),

          // Hero carousel: image, title, summary and action row.
          const SizedBox(
            height: 438,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SkeletonBox(width: double.infinity, borderRadius: 0),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 13, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 210, height: 23, borderRadius: 6),
                      SizedBox(height: 7),
                      SkeletonBox(width: 280, height: 13, borderRadius: 4),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SkeletonBox(height: 45, borderRadius: 10),
                          ),
                          SizedBox(width: 10),
                          SkeletonBox(width: 45, height: 45, borderRadius: 10),
                          SizedBox(width: 10),
                          SkeletonBox(width: 45, height: 45, borderRadius: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonBox(width: 20, height: 6, borderRadius: 3),
              SizedBox(width: 6),
              SkeletonBox(width: 6, height: 6, borderRadius: 3),
              SizedBox(width: 6),
              SkeletonBox(width: 6, height: 6, borderRadius: 3),
            ],
          ),
          const SizedBox(height: 20),

          // The first poster row below the hero.
          const _SkeletonSectionHeader(),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 150, height: 210, borderRadius: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 126, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 76, height: 11, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SkeletonBox(width: 140, height: 18, borderRadius: 6),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic error state widget with retry
// ---------------------------------------------------------------------------

class ErrorRetryWidget extends StatelessWidget {
  const ErrorRetryWidget({
    super.key,
    this.message = 'Something went wrong.',
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 48, color: FlixieColors.medium),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FlixieColors.medium, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
