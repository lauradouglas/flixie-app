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
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Row(
              children: [
                SkeletonBox(width: 48, height: 48, borderRadius: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 86, height: 12),
                      SizedBox(height: 7),
                      SkeletonBox(width: 164, height: 22),
                    ],
                  ),
                ),
                SkeletonBox(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: 8),
                SkeletonBox(width: 40, height: 40, borderRadius: 20),
              ],
            ),
          ),
          _SkeletonSectionHeader(width: 126),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: 14, right: 14),
            child: SkeletonBox(height: 560, borderRadius: 24),
          ),
          SizedBox(height: 10),
          Center(child: SkeletonBox(width: 108, height: 6, borderRadius: 3)),
          SizedBox(height: 20),
          _SkeletonSectionHeader(width: 138),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkeletonBox(height: 270, borderRadius: 16),
          ),
          SizedBox(height: 20),
          _SkeletonSectionHeader(width: 154),
          SizedBox(height: 12),
          _SkeletonPosterRail(),
          SizedBox(height: 20),
          _SkeletonSectionHeader(width: 166),
          SizedBox(height: 12),
          _SkeletonActivityRows(),
        ],
      ),
    );
  }
}

class HomeBootLoadingScreen extends StatefulWidget {
  const HomeBootLoadingScreen({super.key});

  @override
  State<HomeBootLoadingScreen> createState() => _HomeBootLoadingScreenState();
}

class _HomeBootLoadingScreenState extends State<HomeBootLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  static const _messages = [
    'Finding tonight’s good stuff…',
    'Checking what your friends loved…',
    'Picking films that feel like you…',
    'Putting your watch plans together…',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final turn = _controller.value * 6.283;
                final pulse = 1 + .05 * (1 - (2 * _controller.value - 1).abs());
                return SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: 126,
                          height: 126,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                FlixieColors.primary.withValues(alpha: .28),
                                FlixieColors.primary.withValues(alpha: .04),
                              ],
                            ),
                            border: Border.all(
                              color:
                                  FlixieColors.primary.withValues(alpha: .32),
                            ),
                          ),
                          child: const Icon(
                            Icons.local_movies_rounded,
                            color: FlixieColors.primary,
                            size: 58,
                          ),
                        ),
                      ),
                      _orbitingSpark(
                        turn,
                        Icons.auto_awesome_rounded,
                        FlixieColors.tertiary,
                      ),
                      _orbitingSpark(
                        turn + 2.1,
                        Icons.favorite_rounded,
                        Colors.pinkAccent,
                      ),
                      _orbitingSpark(
                        turn + 4.2,
                        Icons.people_alt_rounded,
                        FlixieColors.success,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Getting the good stuff',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FlixieColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final index = (_controller.value * _messages.length).floor() %
                    _messages.length;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _messages[index],
                    key: ValueKey(index),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _orbitingSpark(double angle, IconData icon, Color color) {
    return Transform.rotate(
      angle: angle,
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.rotate(
          angle: -angle,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FlixieColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .45)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
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

class _SkeletonPosterRail extends StatelessWidget {
  const _SkeletonPosterRail();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 180,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              SizedBox(width: 16),
              SkeletonBox(width: 110, height: 148, borderRadius: 11),
              SizedBox(width: 8),
              SkeletonBox(width: 110, height: 148, borderRadius: 11),
              SizedBox(width: 8),
              SkeletonBox(width: 110, height: 148, borderRadius: 11),
            ],
          ),
        ),
      );
}

class _SkeletonActivityRows extends StatelessWidget {
  const _SkeletonActivityRows();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SkeletonBox(height: 72, borderRadius: 14),
            SizedBox(height: 10),
            SkeletonBox(height: 72, borderRadius: 14),
            SizedBox(height: 10),
            SkeletonBox(height: 72, borderRadius: 14),
          ],
        ),
      );
}

class ProfileScreenSkeleton extends StatelessWidget {
  const ProfileScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 16, 24),
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
          SizedBox(height: 18),
          Row(
            children: [
              SkeletonBox(width: 112, height: 16),
              Spacer(),
              SkeletonBox(width: 72, height: 30, borderRadius: 15),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 68,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  SkeletonBox(width: 122, height: 68, borderRadius: 12),
                  SizedBox(width: 8),
                  SkeletonBox(width: 122, height: 68, borderRadius: 12),
                  SizedBox(width: 8),
                  SkeletonBox(width: 122, height: 68, borderRadius: 12),
                ],
              ),
            ),
          ),
          SizedBox(height: 18),
          Row(children: [
            SkeletonBox(width: 92, height: 42, borderRadius: 21),
            SizedBox(width: 8),
            SkeletonBox(width: 96, height: 42, borderRadius: 21),
            SizedBox(width: 8),
            SkeletonBox(width: 88, height: 42, borderRadius: 21),
            SizedBox(width: 8),
            SkeletonBox(width: 84, height: 42, borderRadius: 21),
          ]),
          SizedBox(height: 16),
          SkeletonBox(width: 150, height: 18, borderRadius: 6),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            child: Row(children: [
              SkeletonBox(width: 112, height: 190, borderRadius: 14),
              SizedBox(width: 8),
              SkeletonBox(width: 112, height: 190, borderRadius: 14),
              SizedBox(width: 8),
              SkeletonBox(width: 112, height: 190, borderRadius: 14),
            ]),
          ),
          SizedBox(height: 20),
          SkeletonBox(width: 110, height: 18, borderRadius: 6),
          SizedBox(height: 10),
          SkeletonBox(height: 86, borderRadius: 14),
          SizedBox(height: 10),
          SkeletonBox(height: 86, borderRadius: 14),
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
          SkeletonBox(height: 190, borderRadius: 16),
          SizedBox(height: 12),
          SkeletonBox(height: 190, borderRadius: 16),
          SizedBox(height: 12),
          SkeletonBox(height: 190, borderRadius: 16),
        ],
      );
}

class GroupWatchRequestsSkeleton extends StatelessWidget {
  const GroupWatchRequestsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: const [
          Row(
            children: [
              SkeletonBox(width: 92, height: 40, borderRadius: 20),
              SizedBox(width: 8),
              SkeletonBox(width: 112, height: 40, borderRadius: 20),
              SizedBox(width: 8),
              SkeletonBox(width: 104, height: 40, borderRadius: 20),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 190, borderRadius: 16),
          SizedBox(height: 12),
          SkeletonBox(height: 190, borderRadius: 16),
        ],
      );
}

class MediaDetailScreenSkeleton extends StatelessWidget {
  const MediaDetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final posterWidth =
        (MediaQuery.sizeOf(context).width * .42).clamp(140.0, 168.0);
    final posterHeight = posterWidth * 1.5;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: posterWidth,
                    height: posterHeight,
                    borderRadius: 0,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 58, right: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 92, height: 28, borderRadius: 14),
                          SizedBox(height: 12),
                          SkeletonBox(height: 31, borderRadius: 7),
                          SizedBox(height: 7),
                          SkeletonBox(width: 156, height: 31, borderRadius: 7),
                          SizedBox(height: 13),
                          SkeletonBox(width: 178, height: 16),
                          SizedBox(height: 10),
                          SkeletonBox(width: 164, height: 16),
                          SizedBox(height: 10),
                          SkeletonBox(width: 142, height: 16),
                          SizedBox(height: 13),
                          Row(
                            children: [
                              SkeletonBox(
                                width: 70,
                                height: 30,
                                borderRadius: 15,
                              ),
                              SizedBox(width: 8),
                              SkeletonBox(
                                width: 82,
                                height: 30,
                                borderRadius: 15,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Positioned(
                top: 12,
                left: 12,
                child: SkeletonBox(width: 44, height: 44, borderRadius: 22),
              ),
              const Positioned(
                top: 12,
                right: 12,
                child: SkeletonBox(width: 44, height: 44, borderRadius: 22),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 104, borderRadius: 14),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 66, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 66, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 66, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 66, borderRadius: 12)),
                  ],
                ),
                SizedBox(height: 22),
                SkeletonBox(width: 142, height: 22),
                SizedBox(height: 10),
                SkeletonBox(height: 46, borderRadius: 14),
                SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonBox(width: 142, height: 76, borderRadius: 12),
                    SizedBox(width: 10),
                    SkeletonBox(width: 142, height: 76, borderRadius: 12),
                  ],
                ),
                SizedBox(height: 22),
                SkeletonBox(width: 92, height: 22),
                SizedBox(height: 10),
                SkeletonBox(height: 78, borderRadius: 14),
                SizedBox(height: 10),
                SkeletonBox(height: 72, borderRadius: 14),
                SizedBox(height: 20),
                SkeletonBox(height: 48, borderRadius: 16),
                SizedBox(height: 18),
                SkeletonBox(width: 126, height: 22),
                SizedBox(height: 10),
                SkeletonBox(height: 108, borderRadius: 14),
              ],
            ),
          ),
        ],
      ),
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
