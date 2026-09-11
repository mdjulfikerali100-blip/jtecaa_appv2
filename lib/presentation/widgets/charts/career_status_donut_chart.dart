// lib/presentation/widgets/charts/career_status_donut_chart.dart
//
// Architecture Appendix F.6.O — clickable donut chart, center total,
// legend below, haptic feedback + filter navigation on segment tap.
//
// ⚠️ SPEC CONTRADICTION RESOLVED: Appendix F.6.O's prose describes "5
// segments: 5 career categories" with 5 distinct colors, but Architecture
// §8.3's own actual runnable code computes `DashboardStats.careerStatus`
// as only 3 buckets — `{'Employed', 'Unemployed', 'Higher Studies'}` —
// bucketing the 5 raw CareerStatusCategories down to 3 to keep the
// `.count()` query total low (3 queries instead of 5). §8.3's concrete,
// wired-up code (`home_screen.dart` snippet passing `stats.careerStatus`
// straight into this widget) is the source of truth followed here, not
// F.6.O's narrative-only "5 segments" description — a 5-segment chart
// would need data this app never actually computes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

class CareerStatusDonutChart extends StatelessWidget {
  /// Exactly the 3 keys DashboardStats.careerStatus produces (§8.3):
  /// 'Employed', 'Unemployed', 'Higher Studies'.
  final Map<String, int> data;
  final ValueChanged<String> onSegmentTap;
  final VoidCallback? onCenterTap;

  const CareerStatusDonutChart({
    super.key,
    required this.data,
    required this.onSegmentTap,
    this.onCenterTap,
  });

  /// Colors approximate the design-system palette (Appendix F.2) for the
  /// raw category each bucket represents: 'Employed' ≈ 'Job Holder'
  /// (Primary Navy), 'Unemployed' ≈ 'Looking for a Job' (Warning Amber),
  /// 'Higher Studies' represents the merged Higher-Studies-family bucket
  /// (Tertiary Teal).
  static const Map<String, Color> _bucketColors = {
    'Employed': Color(0xFF1A365D),
    'Unemployed': Color(0xFFD97706),
    'Higher Studies': Color(0xFF0F766E),
  };

  bool get _isAllZero => data.values.every((v) => v == 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Architecture Master Prompt Phase 4: "Animation: 600ms scale + fade".
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.9 + (0.1 * t), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Career Overview',
                        style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap a segment to filter',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: _buildSections(theme),
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) {
                            return;
                          }
                          if (_isAllZero) {
                            return; // nothing meaningful to filter by yet
                          }
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          if (index == null ||
                              index < 0 ||
                              index >= data.length) {
                            return;
                          }
                          HapticFeedback.lightImpact(); // Appendix F.6.O step 1
                          onSegmentTap(data.keys.elementAt(index)); // steps 2–3
                        },
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCenterTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${data.values.fold<int>(0, (a, b) => a + b)}',
                          style: theme.textTheme.headlineMedium,
                        ),
                        Text('Total', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isAllZero)
              Text(
                'Building the alumni network…',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: data.entries.map((e) {
                  final color = _bucketColors[e.key] ??
                      theme.colorScheme.onSurfaceVariant;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('${e.key} (${e.value})',
                          style: theme.textTheme.labelSmall),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(ThemeData theme) {
    // Architecture §8.3: "treat an all-zero data map as a valid, drawable
    // state — render three equal, muted-gray placeholder segments...
    // instead of an empty canvas."
    if (_isAllZero) {
      return List.generate(
        3,
        (i) => PieChartSectionData(
          value: 1,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          radius: 40,
          showTitle: false,
        ),
      );
    }
    return data.entries.map((e) {
      final color = _bucketColors[e.key] ?? theme.colorScheme.onSurfaceVariant;
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        radius: 40,
        showTitle: false,
      );
    }).toList();
  }
}
