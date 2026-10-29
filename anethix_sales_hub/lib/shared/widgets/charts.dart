import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';

/// One labelled value. Charts here take these rather than raw numbers so the
/// label travels with the datum and can be direct-labelled or tabulated.
class ChartDatum {
  const ChartDatum({required this.label, required this.value, this.color});

  final String label;
  final double value;

  /// Set only where the entity already owns a colour app-wide (pipeline
  /// stages); otherwise the chart assigns from the validated palette.
  final Color? color;
}

/// Card chrome shared by every chart: title, optional caption, fixed height.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.height = 200,
    this.legend,
  });

  final String title;
  final String? caption;
  final Widget child;
  final double height;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
          if (legend != null) ...[
            const SizedBox(height: 14),
            legend!,
          ],
        ],
      ),
    );
  }
}

/// Horizontal magnitude comparison. One series, so one hue - length carries
/// the comparison and colour carries nothing.
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.data,
    this.useDatumColors = false,
  });

  final List<ChartDatum> data;
  final bool useDatumColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppColors.chartAccent(theme.brightness);
    final max = data.fold<double>(1, (m, d) => d.value > m ? d.value : m);

    if (data.isEmpty) return const _NoData();

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final datum = data[index];
        final color = useDatumColors ? (datum.color ?? accent) : accent;

        return Row(
          children: [
            SizedBox(
              width: 78,
              child: Text(
                datum.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (datum.value / max).clamp(0.0, 1.0),
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 28,
              child: Text(
                '${datum.value.toInt()}',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Vertical bars for a single series over a small number of buckets.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.data});

  final List<ChartDatum> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _NoData();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppColors.chartAccent(theme.brightness);
    final max = data.fold<double>(1, (m, d) => d.value > m ? d.value : m);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: max * 1.25,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${data[group.x].label}\n',
              theme.textTheme.labelSmall!
                  .copyWith(color: scheme.onInverseSurface),
              children: [
                TextSpan(
                  text: '${rod.toY.toInt()}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.onInverseSurface),
                ),
              ],
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (max / 3).ceilToDouble().clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval:
                  (max / 3).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[index].label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].value,
                  width: 16,
                  color: data[i].color ?? accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Single-series trend line. 2px stroke, soft fill, touch crosshair.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.data});

  final List<ChartDatum> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _NoData();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppColors.chartAccent(theme.brightness);
    final max = data.fold<double>(1, (m, d) => d.value > m ? d.value : m);
    // Label every nth point so the axis never collides with itself.
    final labelStep = (data.length / 6).ceil();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: max * 1.25,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${data[spot.x.toInt()].label}\n${spot.y.toInt()}',
                  theme.textTheme.labelMedium!
                      .copyWith(color: scheme.onInverseSurface),
                ),
            ],
          ),
          getTouchedSpotIndicator: (barData, indices) => [
            for (final _ in indices)
              TouchedSpotIndicatorData(
                FlLine(color: accent.withValues(alpha: 0.5), strokeWidth: 1),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 5,
                    color: accent,
                    strokeWidth: 2,
                    strokeColor: scheme.surface,
                  ),
                ),
              ),
          ],
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (max / 3).ceilToDouble().clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (max / 3).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 ||
                    index >= data.length ||
                    index % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[index].label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i].value),
            ],
            isCurved: true,
            curveSmoothness: 0.28,
            color: accent,
            barWidth: 2,
            dotData: FlDotData(
              show: data.length <= 10,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: accent,
                strokeWidth: 2,
                strokeColor: scheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: accent.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Part-to-whole donut. Categories beyond the palette are folded into "Other"
/// by the caller; every slice is named in the legend with its value, which is
/// also the relief for the light-mode contrast warning on some slots.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.data,
    this.centreLabel,
    this.centreValue,
  });

  final List<ChartDatum> data;
  final String? centreLabel;
  final String? centreValue;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const _NoData();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = AppColors.chartSeries(theme.brightness);
    final total = widget.data.fold<double>(0, (sum, d) => sum + d.value);

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 52,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  _touchedIndex = response?.touchedSection == null
                      ? -1
                      : response!.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            sections: [
              for (var i = 0; i < widget.data.length; i++)
                PieChartSectionData(
                  value: widget.data[i].value,
                  color: widget.data[i].color ?? palette[i % palette.length],
                  radius: _touchedIndex == i ? 30 : 26,
                  showTitle: false,
                  borderSide: BorderSide(color: scheme.surface, width: 2),
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.centreValue ?? '${total.toInt()}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            Text(
              _touchedIndex >= 0 && _touchedIndex < widget.data.length
                  ? widget.data[_touchedIndex].label
                  : (widget.centreLabel ?? 'Total'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Legend for a categorical chart. Always shown alongside a donut, and it
/// carries the values so identity is never colour-alone.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.data});

  final List<ChartDatum> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppColors.chartSeries(theme.brightness);

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (var i = 0; i < data.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: data[i].color ?? palette[i % palette.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${data[i].label} ${data[i].value.toInt()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Not enough data yet',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Folds a long category list down to the palette limit, summing the tail into
/// a single "Other" slice so hues are never cycled.
List<ChartDatum> foldToPalette(
  List<ChartDatum> data, {
  int max = AppColors.maxChartCategories,
  Brightness brightness = Brightness.light,
}) {
  final sorted = [...data]..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.length <= max) return sorted;

  final head = sorted.take(max - 1).toList();
  final tail = sorted.skip(max - 1);
  final otherTotal = tail.fold<double>(0, (sum, d) => sum + d.value);

  return [
    ...head,
    ChartDatum(
      label: 'Other',
      value: otherTotal,
      color: AppColors.chartOther(brightness),
    ),
  ];
}
