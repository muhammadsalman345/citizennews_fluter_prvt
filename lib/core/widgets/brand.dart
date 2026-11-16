import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CitizenNewsBrand extends StatelessWidget {
  const CitizenNewsBrand({
    this.compact = false,
    this.showTagline = true,
    super.key,
  });

  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 36 : 41,
          height: compact ? 38 : 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 23 : 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
              ),
              children: const [
                TextSpan(text: 'C'),
                TextSpan(
                  text: '•',
                  style: TextStyle(color: AppColors.red),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 11),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 20 : 24,
                  height: 1.05,
                  letterSpacing: -1,
                ),
                children: const [
                  TextSpan(text: 'Citizen'),
                  TextSpan(
                    text: 'News',
                    style: TextStyle(color: AppColors.red),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 4),
              Text(
                'YOUR CITY. YOUR VOICE.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 6.5 : 8,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: compact ? 1.5 : 2.1,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
