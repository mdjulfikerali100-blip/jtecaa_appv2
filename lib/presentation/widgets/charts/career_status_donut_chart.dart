// lib/presentation/widgets/charts/career_status_donut_chart.dart
//
// Architecture Appendix F.6.O — clickable donut chart, center total,
// legend below, haptic feedback + filter navigation on segment tap.
//
// ⚠️ INTERACTION MODEL: donut segments are NOT tappable (thin-ring taps
//   are imprecise on a phone). All filtering is routed through the
//   legend rows below. Center total tap → Directory.
//
// ⚠️ BIGGER CHART + REAL-DEVICE TUNING (this revision):
//   • Chart container is now responsive: height scales with the ambient
//     text scale and clamps to a comfortable band (200–260dp) so a
//     small phone with large font still shows a clear ring, and a
//     tablet doesn't get a grotesque donut.
//   • Ring thickness raised 40 → 52 so the slice colors read from
//     across the room.
//   • Center hole raised 50 → 62 so the "2 / Total" block has room.
//   • Total number uses `headlineLarge` + w800 for real prominence.
//   • Padding around the chart scales with the same factor so nothing
//     ever crowds the ring against the card edge.

import 'dart:math' as math;

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

  int get _total => data.values.fold<int>(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    // ⚠️ REAL-DEVICE SIZING:
    //   • shortest-side based scale — a 320dp phone stays at 1.0x,
    //     anything larger grows up to 1.15x.
    //   • chart height clamps to 200–260 so it stays a proper donut
    //     without eating the whole screen on small phones.
    final shortest = math.min(media.size.width, media.size.height);
    final scale = (shortest / 375.0).clamp(0.85, 1.15);

    // textScaler capped at 1.20 so a giant accessibility font doesn't
    // push the ring off-screen; the center text below also uses this.
    final ts = media.textScaler.scale(1.0).clamp(0.85, 1.20);
    final chartHeight = (200.0 * scale * ts).clamp(200.0, 260.0);

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
        padding: EdgeInsets.all(18 * scale),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Career Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isAllZero)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.30),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$_total total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Tap a row to filter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12 * scale),

            // ── Donut (bigger) ──────────────────────────────────
            SizedBox(
              height: chartHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      // ⚠️ Bigger center hole so the total text has
                      // real breathing room (was 50).
                      centerSpaceRadius: 62 * scale,
                      sections: _buildSections(theme, scale),
                      pieTouchData: PieTouchData(enabled: false),
                    ),
                  ),
                  // Center tap target — sized relative to the hole.
                  GestureDetector(
                    onTap: onCenterTap,
                    child: Container(
                      width: 118 * scale,
                      height: 118 * scale,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$_total',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16 * scale),

            // ── Legend ──────────────────────────────────────────
            if (_isAllZero)
              Text(
                'Building the alumni network…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              _Legend(
                data: data,
                total: _total,
                onTap: (key) {
                  HapticFeedback.selectionClick();
                  onSegmentTap(key);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(ThemeData theme, double scale) {
    // ⚠️ Ring radius raised 40 → 52 so the slice colors are more
    // prominent. Real device reading distance matters here.
    final radius = 52.0 * scale;

    if (_isAllZero) {
      return List.generate(
        CareerStatusCategories.all.length,
        (i) => PieChartSectionData(
          value: 1,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          radius: radius,
          showTitle: false,
        ),
      );
    }
    return data.entries.map((e) {
      final color = CareerStatusCategories.getColor(e.key);
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        radius: radius,
        showTitle: false,
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Legend — ranked list of tappable rows.
// ─────────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Map<String, int> data;
  final int total;
  final ValueChanged<String> onTap;

  const _Legend({
    required this.data,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: entries.map((e) {
        final color = CareerStatusCategories.getColor(e.key);
        final count = e.value;
        final isEmpty = count == 0;
        final fraction = total == 0 ? 0.0 : count / total;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: isEmpty ? null : () => onTap(e.key),
              borderRadius: BorderRadius.circular(10),
              splashColor: color.withValues(alpha: 0.12),
              highlightColor: color.withValues(alpha: 0.06),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35)
                            : color,
                        boxShadow: isEmpty
                            ? null
                            : [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        CareerStatusCategories.getDisplayLabel(e.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isEmpty
                              ? theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.55)
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 26),
                      decoration: BoxDecoration(
                        color: isEmpty
                            ? theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: isDark ? 0.4 : 0.6)
                            : color.withValues(alpha: isDark ? 0.25 : 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isEmpty
                              ? theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6)
                              : color,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 5,
                          backgroundColor: theme
                              .colorScheme.surfaceContainerHighest
                              .withValues(alpha: isDark ? 0.5 : 0.8),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isEmpty
                                ? theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.25)
                                : color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 34,
                      child: Text(
                        total > 0
                            ? '${(fraction * 100).toStringAsFixed(0)}%'
                            : '—',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isEmpty
                              ? theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.55)
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.30)
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
