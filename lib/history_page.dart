import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'models/vital_reading.dart';
import 'vitals_repository.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (VitalsRepository.client == null) {
      return const _HistoryMessage(
        text: VitalsRepository.configError,
        isError: true,
      );
    }

    return StreamBuilder<List<VitalReading>>(
      stream: VitalsRepository.readingsStream(limit: 30),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _HistoryMessage(
            text: 'Failed to load history.\n${snapshot.error}',
            isError: true,
          );
        }

        final readings = snapshot.data ?? const <VitalReading>[];
        final history = readings.reversed.toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('History', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 10),
              Text(
                'Historical trends will appear here',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: softCardDecoration(AppColors.pastelBlue, radius: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Heart Rhythm',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: _HistoryChart(
                        points: _spots(history, (item) => item.heartRate),
                        color: const Color(0xFF4A6978),
                        unit: 'bpm',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: softCardDecoration(AppColors.pastelGrey, radius: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Timeline',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      Text(
                        'Waiting for readings from Supabase.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    else
                      ...history.reversed.take(8).map(
                        (reading) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat(
                                    'EEE, hh:mm a',
                                  ).format(reading.createdAt.toLocal()),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '${reading.heartRateText} bpm',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${reading.spo2Text}%',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<FlSpot> _spots(
    List<VitalReading> source,
    double? Function(VitalReading item) selector,
  ) {
    final points = <FlSpot>[];
    for (var i = 0; i < source.length; i++) {
      final value = selector(source[i]);
      if (value != null) {
        points.add(FlSpot(i.toDouble(), value));
      }
    }
    return points.isEmpty ? const [FlSpot(0, 0)] : points;
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({
    required this.points,
    required this.color,
    required this.unit,
  });

  final List<FlSpot> points;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    double minY = points.first.y;
    double maxY = points.first.y;
    for (final point in points) {
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    if ((maxY - minY).abs() < 1) {
      minY -= 1;
      maxY += 1;
    }

    return LineChart(
      LineChartData(
        minY: minY - 2,
        maxY: maxY + 2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: color.withValues(alpha: 0.18), strokeWidth: 1),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.text,
            getTooltipItems: (items) => items
                .map(
                  (item) => LineTooltipItem(
                    '${item.y.toStringAsFixed(0)} $unit',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            isStrokeCapRound: true,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
            ),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.20),
                  color.withValues(alpha: 0.03),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: softCardDecoration(
          isError ? AppColors.pastelRed : AppColors.pastelGrey,
          radius: 28,
          shadows: const [],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
