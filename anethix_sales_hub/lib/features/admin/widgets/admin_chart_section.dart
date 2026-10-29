import 'package:flutter/material.dart';

import '../../../core/constants/lead_status.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/charts.dart';
import '../providers/admin_dashboard_provider.dart';

class AdminChartSection extends StatelessWidget {
  const AdminChartSection({super.key, required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Statuses beyond the palette limit fold into "Other" rather than cycling
    // hues, and every slice is named with its value in the legend.
    final statusSlices = foldToPalette(
      [
        for (final status in LeadStatus.values)
          if ((data.leadsByStatus[status] ?? 0) > 0)
            ChartDatum(
              label: status.label,
              value: (data.leadsByStatus[status] ?? 0).toDouble(),
              color: status.color,
            ),
      ],
      brightness: brightness,
    );

    return Column(
      children: [
        ChartCard(
          title: 'Leads by stage',
          caption: 'Every lead in the company',
          height: 168,
          legend: ChartLegend(data: statusSlices),
          child: DonutChart(
            data: statusSlices,
            centreLabel: 'Total leads',
            centreValue: '${data.totalLeads}',
          ),
        ),
        const SizedBox(height: 12),
        ChartCard(
          title: 'Calls by day',
          caption: 'Last 7 days, company-wide',
          height: 170,
          child: SimpleBarChart(
            data: [
              for (final (day, count) in data.callsByDay)
                ChartDatum(
                  label: AppDate.chartLabel(day),
                  value: count.toDouble(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ChartCard(
          title: 'Top performers',
          caption: 'Score this month',
          height: 160,
          child: HorizontalBarChart(
            data: [
              for (final entry in data.topPerformers)
                ChartDatum(
                  label: entry.employeeName.split(' ').first,
                  value: entry.score.toDouble(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ChartCard(
          title: 'Conversions over time',
          caption: 'Leads marked won, last 30 days',
          height: 170,
          child: TrendLineChart(
            data: [
              for (final (day, count) in data.conversionsByDay)
                ChartDatum(
                  label: AppDate.chartLabel(day),
                  value: count.toDouble(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
