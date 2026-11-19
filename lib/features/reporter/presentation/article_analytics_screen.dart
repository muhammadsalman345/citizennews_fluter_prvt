import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/article_analytics_repository.dart';
import '../domain/article_analytics.dart';

class ArticleAnalyticsScreen extends StatefulWidget {
  const ArticleAnalyticsScreen({required this.postId, super.key});

  final String postId;

  @override
  State<ArticleAnalyticsScreen> createState() =>
      _ArticleAnalyticsScreenState();
}

class _ArticleAnalyticsScreenState extends State<ArticleAnalyticsScreen> {
  ArticleAnalyticsRepository? _repository;
  ArticleAnalyticsData? _data;
  int _days = 30;
  int _loadVersion = 0;
  bool _initialized = false;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final client = AuthScope.read(context).service.client;
    if (client == null) {
      _loading = false;
      _error = 'Supabase is not configured.';
      return;
    }
    _repository = ArticleAnalyticsRepository(client);
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository!.load(
        postId: widget.postId,
        days: _days,
      );
      if (mounted && version == _loadVersion) setState(() => _data = data);
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = AppError.message(error));
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 70),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.contentMax,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.backOr('/my-stories'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('My stories'),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'OWNER-ONLY PERFORMANCE',
                                  style: TextStyle(
                                    color: AppColors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  'Article analytics',
                                  style:
                                      Theme.of(context).textTheme.headlineLarge,
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<int>(
                            value: _days,
                            items: const [
                              DropdownMenuItem(value: 7, child: Text('7 days')),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 days'),
                              ),
                              DropdownMenuItem(
                                value: 365,
                                child: Text('1 year'),
                              ),
                            ],
                            onChanged: _loading
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _days = value);
                                    _load();
                                  },
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _AnalyticsNotice(message: _error!),
                      ],
                      const SizedBox(height: 18),
                      if (_loading && _data == null)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_data != null) ...[
                        if (_loading) const LinearProgressIndicator(),
                        _metrics(_data!),
                        const SizedBox(height: 14),
                        _chartCard(_data!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _metrics(ArticleAnalyticsData data) {
    final values = [
      ('Views', data.views, Icons.visibility_outlined),
      ('Verified views', data.verifiedViews, Icons.verified_outlined),
      ('Likes', data.likes, Icons.thumb_up_outlined),
      ('Dislikes', data.dislikes, Icons.thumb_down_outlined),
      ('Comments', data.comments, Icons.comment_outlined),
      ('Points', data.points, Icons.stars_outlined),
      ('Approval', data.approvalPercent, Icons.percent_rounded),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final value in values)
          SizedBox(
            width: 178,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(value.$3, color: AppColors.red),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${value.$2}${value.$1 == 'Approval' ? '%' : ''}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            value.$1,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chartCard(ArticleAnalyticsData data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Daily readership',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              const Wrap(
                spacing: 14,
                children: [
                  _Legend(color: AppColors.red, label: 'All views'),
                  _Legend(color: AppColors.focus, label: 'Verified views'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: data.daily.isEmpty
                    ? const Center(child: Text('No readership in this period.'))
                    : CustomPaint(
                        painter: _AnalyticsChartPainter(_dailyRows(data)),
                        child: const SizedBox.expand(),
                      ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _EngagementBar(
                    label: 'Likes',
                    value: data.likes,
                    maximum: max(1, max(data.likes, max(data.dislikes, data.comments))),
                    color: AppColors.success,
                  ),
                  _EngagementBar(
                    label: 'Dislikes',
                    value: data.dislikes,
                    maximum: max(1, max(data.likes, max(data.dislikes, data.comments))),
                    color: AppColors.red,
                  ),
                  _EngagementBar(
                    label: 'Comments',
                    value: data.comments,
                    maximum: max(1, max(data.likes, max(data.dislikes, data.comments))),
                    color: AppColors.focus,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Verified views are authenticated readership signals. Analytics and points are calculated by the existing server RPC, not by the app.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      );

  List<ArticleAnalyticsDay> _dailyRows(ArticleAnalyticsData data) {
    final byDay = {
      for (final row in data.daily) _dayKey(row.day): row,
    };
    final today = DateTime.now().toUtc();
    final start = DateTime.utc(today.year, today.month, today.day)
        .subtract(Duration(days: _days - 1));
    return [
      for (var index = 0; index < _days; index++)
        byDay[_dayKey(start.add(Duration(days: index)))] ??
            ArticleAnalyticsDay(
              day: start.add(Duration(days: index)),
              views: 0,
              verifiedViews: 0,
            ),
    ];
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _AnalyticsChartPainter extends CustomPainter {
  const _AnalyticsChartPainter(this.rows);
  final List<ArticleAnalyticsDay> rows;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    const bottom = 24.0;
    final area = Rect.fromLTRB(left, 8, size.width - 8, size.height - bottom);
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = area.top + area.height * index / 4;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
    }
    final maximum = max(
      1,
      rows.fold<int>(0, (value, row) => max(value, row.views)),
    );
    Path path(int Function(ArticleAnalyticsDay) value) {
      final result = Path();
      for (var index = 0; index < rows.length; index++) {
        final x = rows.length == 1
            ? area.center.dx
            : area.left + area.width * index / (rows.length - 1);
        final y = area.bottom - area.height * value(rows[index]) / maximum;
        if (index == 0) {
          result.moveTo(x, y);
        } else {
          result.lineTo(x, y);
        }
      }
      return result;
    }

    canvas.drawPath(
      path((row) => row.views),
      Paint()
        ..color = AppColors.red
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path((row) => row.verifiedViews),
      Paint()
        ..color = AppColors.focus
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final label = TextPainter(
      text: TextSpan(
        text: '$maximum',
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, const Offset(0, 3));
    final first = _day(rows.first.day);
    final last = _day(rows.last.day);
    _paintLabel(canvas, first, Offset(area.left, area.bottom + 5));
    final lastPainter = _labelPainter(last);
    lastPainter.paint(
      canvas,
      Offset(area.right - lastPainter.width, area.bottom + 5),
    );
  }

  TextPainter _labelPainter(String value) => TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _paintLabel(Canvas canvas, String value, Offset offset) =>
      _labelPainter(value).paint(canvas, offset);

  String _day(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(covariant _AnalyticsChartPainter oldDelegate) =>
      oldDelegate.rows != rows;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 18, height: 3, color: color),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _EngagementBar extends StatelessWidget {
  const _EngagementBar({
    required this.label,
    required this.value,
    required this.maximum,
    required this.color,
  });

  final String label;
  final int value;
  final int maximum;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: $value'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: value / maximum,
              color: color,
              backgroundColor: AppColors.border,
            ),
          ],
        ),
      );
}

class _AnalyticsNotice extends StatelessWidget {
  const _AnalyticsNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.red.withValues(alpha: .22)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red),
            const SizedBox(width: 9),
            Expanded(child: Text(message)),
          ],
        ),
      );
}
