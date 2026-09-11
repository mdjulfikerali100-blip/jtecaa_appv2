// lib/presentation/widgets/charts/career_status_donut_chart.dart
//
// Architecture Appendix F.6.O — clickable donut chart, center total,
// legend below, haptic feedback + filter navigation on segment tap.
//
// ⚠️ UPDATE — REVERSES an earlier resolution: this widget originally
// shipped with only 3 segments because Architecture §8.3's own runnable
// code only computed 3 career-status buckets. Per explicit user request,
// StatsRepository (Phase 2) now runs 5 separate `.count()` queries
// instead — one per raw CareerStatusCategories value — so
// DashboardStats.careerStatus carries all 5 keys again, matching
// Appendix F.6.O's original "5 segments: 5 career categories" spec. This
// widget was updated to match.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/utils/career_status_categories.dart';

class CareerStatusDonutChart extends StatelessWidget {
  /// The 5 raw CareerStatusCategories.all keys → their counts.
  final Map<String, int> data;
  final ValueChanged<String> onSegmentTap;
  final VoidCallback? onCenterTap;

  const CareerStatusDonutChart({
    super.key,
    required this.data,
    required this.onSegmentTap,
    this.onCenterTap,
  });

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
              // ⚠️ Appendix K.3 overflow-safety pattern applied here too:
              // with all 5 raw categories now shown (including the long
              // "Preparing for a Government Job"), each legend entry uses
              // the SHORT display label (CareerStatusCategories.
              // getDisplayLabel) plus maxLines:1 + ellipsis, so a long
              // category name can never push the Wrap into an ugly
              // horizontal overflow on a narrow device.
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: data.entries.map((e) {
                  final color = CareerStatusCategories.getColor(e.key);
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${CareerStatusCategories.getDisplayLabel(e.key)} (${e.value})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
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
    // state — render equal, muted-gray placeholder segments instead of an
    // empty canvas." Uses CareerStatusCategories.all.length (5) rather
    // than a hardcoded 3, so this stays correct if the category count
    // ever changes.
    if (_isAllZero) {
      return List.generate(
        CareerStatusCategories.all.length,
        (i) => PieChartSectionData(
          value: 1,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          radius: 40,
          showTitle: false,
        ),
      );
    }
    return data.entries.map((e) {
      final color = CareerStatusCategories.getColor(e.key);
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        radius: 40,
        showTitle: false,
      );
    }).toList();
  }
}
