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

class HomeScreenSkeleton extends StatefulWidget {
  const HomeScreenSkeleton({super.key});

  @override
  State<HomeScreenSkeleton> createState() => _HomeScreenSkeletonState();
}

class _HomeScreenSkeletonState extends State<HomeScreenSkeleton>
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final turn = _controller.value * 6.283;
                    final pulse =
                        1 + 0.05 * (1 - (2 * _controller.value - 1).abs());
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
                                    FlixieColors.primary
                                        .withValues(alpha: 0.28),
                                    FlixieColors.primary
                                        .withValues(alpha: 0.04),
                                  ],
                                ),
                                border: Border.all(
                                  color: FlixieColors.primary
                                      .withValues(alpha: 0.32),
                                ),
                              ),
                              child: const Icon(
                                Icons.local_movies_rounded,
                                color: FlixieColors.primary,
                                size: 58,
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: turn,
                            child: const Align(
                              alignment: Alignment.topCenter,
                              child: _LoadingSpark(
                                icon: Icons.auto_awesome_rounded,
                                color: FlixieColors.tertiary,
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: turn + 2.1,
                            child: const Align(
                              alignment: Alignment.topCenter,
                              child: _LoadingSpark(
                                icon: Icons.favorite_rounded,
                                color: Colors.pinkAccent,
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: turn + 4.2,
                            child: const Align(
                              alignment: Alignment.topCenter,
                              child: _LoadingSpark(
                                icon: Icons.people_alt_rounded,
                                color: FlixieColors.success,
                              ),
                            ),
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
                    final index =
                        (_controller.value * _messages.length).floor() %
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
                const SizedBox(height: 28),
                const _LoadingPreview(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingSpark extends StatelessWidget {
  const _LoadingSpark({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Icon(icon, color: color, size: 18),
      );
}

class _LoadingPreview extends StatelessWidget {
  const _LoadingPreview();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          SkeletonBox(width: 170, height: 12, borderRadius: 5),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 92, borderRadius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 92, borderRadius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 92, borderRadius: 14)),
            ],
          ),
        ],
      );
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                SkeletonBox(width: 44, height: 44, borderRadius: 22),
                Spacer(),
                SkeletonBox(width: 44, height: 44, borderRadius: 22),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 128,
                  child: Column(
                    children: [
                      SkeletonBox(height: 192, borderRadius: 12),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SkeletonBox(height: 6, borderRadius: 3),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: SkeletonBox(height: 6, borderRadius: 3),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: SkeletonBox(height: 6, borderRadius: 3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 116, height: 26, borderRadius: 13),
                        SizedBox(height: 14),
                        SkeletonBox(width: double.infinity, height: 30),
                        SizedBox(height: 8),
                        SkeletonBox(width: 182, height: 30),
                        SizedBox(height: 14),
                        SkeletonBox(width: 160, height: 14, borderRadius: 5),
                        SizedBox(height: 10),
                        SkeletonBox(width: 212, height: 14, borderRadius: 5),
                        SizedBox(height: 10),
                        SkeletonBox(width: 188, height: 14, borderRadius: 5),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SkeletonBox(
                                width: 62, height: 28, borderRadius: 14),
                            SkeletonBox(
                                width: 72, height: 28, borderRadius: 14),
                            SkeletonBox(
                                width: 54, height: 28, borderRadius: 14),
                          ],
                        ),
                        SizedBox(height: 16),
                        SkeletonBox(width: 148, height: 18, borderRadius: 6),
                        SizedBox(height: 8),
                        SkeletonBox(width: 92, height: 14, borderRadius: 5),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Row(
                children: [
                  Expanded(child: SkeletonBox(height: 46, borderRadius: 23)),
                  SizedBox(width: 1),
                  SizedBox(height: 34, child: VerticalDivider(width: 1)),
                  SizedBox(width: 1),
                  SkeletonBox(width: 46, height: 46, borderRadius: 23),
                  SizedBox(width: 10),
                  SkeletonBox(width: 46, height: 46, borderRadius: 23),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SkeletonBox(width: 138, height: 22),
            const SizedBox(height: 10),
            const SkeletonBox(height: 104, borderRadius: 16),
            const SizedBox(height: 12),
            const SkeletonBox(height: 94, borderRadius: 16),
            const SizedBox(height: 22),
            const SkeletonBox(width: 90, height: 22),
            const SizedBox(height: 10),
            const SkeletonBox(height: 110, borderRadius: 16),
          ],
        ),
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
