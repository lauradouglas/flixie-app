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
          const SizedBox(height: 16),
          const _SkeletonSectionHeader(width: 150),
          const SizedBox(height: 8),

          // Current 560px trending card: tall poster plus detail/actions.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child:
                          SkeletonBox(width: double.infinity, borderRadius: 18),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(14, 13, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 210, height: 23, borderRadius: 6),
                          SizedBox(height: 7),
                          SkeletonBox(width: 250, height: 13, borderRadius: 4),
                          SizedBox(height: 8),
                          SkeletonBox(width: double.infinity, height: 12),
                          SizedBox(height: 6),
                          SkeletonBox(width: 230, height: 12),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child:
                                    SkeletonBox(height: 40, borderRadius: 10),
                              ),
                              SizedBox(width: 10),
                              SkeletonBox(
                                  width: 72, height: 40, borderRadius: 10),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                )),
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

          // For-you poster carousel.
          const _SkeletonSectionHeader(width: 92),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => const SizedBox(
                width: 124,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 124, height: 186, borderRadius: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 108, height: 13, borderRadius: 4),
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
  const _SkeletonSectionHeader({this.width = 140});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SkeletonBox(width: width, height: 18, borderRadius: 6),
    );
  }
}

class ProfileScreenSkeleton extends StatelessWidget {
  const ProfileScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SkeletonBox(width: 108, height: 108, borderRadius: 54),
            SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  SkeletonBox(width: 150, height: 16),
                  SizedBox(height: 12),
                  SkeletonBox(width: 118, height: 28),
                  SizedBox(height: 10),
                  SkeletonBox(width: 190, height: 13),
                  SizedBox(height: 6),
                  SkeletonBox(width: 145, height: 13),
                ])),
          ]),
          SizedBox(height: 22),
          SkeletonBox(height: 94, borderRadius: 16),
          SizedBox(height: 18),
          Row(children: [
            Expanded(child: SkeletonBox(height: 44, borderRadius: 22)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 44, borderRadius: 22)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 44, borderRadius: 22)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 44, borderRadius: 22)),
          ]),
          SizedBox(height: 22),
          _SkeletonSectionHeader(width: 150),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: SkeletonBox(height: 132, borderRadius: 16)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 132, borderRadius: 16)),
          ]),
          SizedBox(height: 22),
          _SkeletonSectionHeader(width: 110),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: SkeletonBox(height: 190, borderRadius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 190, borderRadius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 190, borderRadius: 14)),
          ]),
        ]),
      );
}

class MovieListsScreenSkeleton extends StatelessWidget {
  const MovieListsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(children: [
          const Row(children: [
            SkeletonBox(width: 104, height: 40, borderRadius: 20),
            Spacer(),
            SkeletonBox(width: 40, height: 40, borderRadius: 20),
            SizedBox(width: 8),
            SkeletonBox(width: 40, height: 40, borderRadius: 20),
          ]),
          const SizedBox(height: 14),
          const Row(children: [
            Expanded(child: SkeletonBox(height: 44, borderRadius: 22)),
            SizedBox(width: 10),
            SkeletonBox(width: 112, height: 44, borderRadius: 22),
          ]),
          const SizedBox(height: 20),
          Expanded(
              child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: .72,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonBox(borderRadius: 16),
          )),
        ]),
      );
}

class WatchRequestsSkeleton extends StatelessWidget {
  const WatchRequestsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(width: 150, height: 18),
          SizedBox(height: 12),
          SkeletonBox(height: 190, borderRadius: 16),
          SizedBox(height: 12),
          SkeletonBox(height: 190, borderRadius: 16),
          SizedBox(height: 22),
          SkeletonBox(width: 96, height: 18),
          SizedBox(height: 12),
          SkeletonBox(height: 142, borderRadius: 16),
        ],
      );
}

class MediaDetailScreenSkeleton extends StatelessWidget {
  const MediaDetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 54, 16, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            SkeletonBox(width: 44, height: 44, borderRadius: 22),
            Spacer(),
            SkeletonBox(width: 44, height: 44, borderRadius: 22),
          ]),
          const SizedBox(height: 18),
          Container(
            height: 330,
            decoration: BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FlixieColors.tabBarBorder),
            ),
            padding: const EdgeInsets.all(10),
            child: const Row(children: [
              Expanded(
                flex: 9,
                child: SkeletonBox(height: double.infinity, borderRadius: 14),
              ),
              SizedBox(width: 14),
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 132, height: 42, borderRadius: 21),
                    SizedBox(height: 16),
                    SkeletonBox(width: double.infinity, height: 28),
                    SizedBox(height: 8),
                    SkeletonBox(width: 170, height: 28),
                    SizedBox(height: 14),
                    SkeletonBox(width: 185, height: 14),
                    SizedBox(height: 16),
                    SkeletonBox(width: double.infinity, height: 15),
                    SizedBox(height: 12),
                    Row(children: [
                      SkeletonBox(width: 76, height: 30, borderRadius: 15),
                      SizedBox(width: 8),
                      SkeletonBox(width: 86, height: 30, borderRadius: 15),
                    ]),
                    Spacer(),
                    SkeletonBox(width: 170, height: 24),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 104, borderRadius: 16),
          const SizedBox(height: 12),
          const SkeletonBox(height: 94, borderRadius: 16),
          const SizedBox(height: 22),
          const SkeletonBox(width: 138, height: 22),
          const SizedBox(height: 10),
          const SkeletonBox(height: 46, borderRadius: 23),
          const SizedBox(height: 10),
          const Row(children: [
            Expanded(child: SkeletonBox(height: 70, borderRadius: 14)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 70, borderRadius: 14)),
          ]),
          const SizedBox(height: 22),
          const SkeletonBox(width: 90, height: 22),
          const SizedBox(height: 10),
          const SkeletonBox(height: 110, borderRadius: 16),
        ]),
      );
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
