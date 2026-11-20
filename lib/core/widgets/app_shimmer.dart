import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final travel = bounds.width * 2.2;
            final left = (_controller.value * travel) - bounds.width;
            return const LinearGradient(
              colors: [
                Color(0xFFE8ECEF),
                Color(0xFFF9FAFB),
                Color(0xFFE8ECEF),
              ],
              stops: [.32, .5, .68],
            ).createShader(
              Rect.fromLTWH(left, 0, bounds.width * 1.8, bounds.height),
            );
          },
          child: child,
        ),
      );
}

class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    required this.width,
    required this.height,
    this.radius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
