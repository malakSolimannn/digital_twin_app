import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'models/vital_reading.dart';
import 'vitals_repository.dart';

class HeartRateDetailsPage extends StatelessWidget {
  const HeartRateDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (VitalsRepository.client == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: _StateMessage(
              text: VitalsRepository.configError,
              isError: true,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: Padding(
              padding: AppLayout.pagePadding,
              child: StreamBuilder<List<VitalReading>>(
                stream: VitalsRepository.readingsStream(limit: 50),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _StateMessage(
                      text: 'Failed to load live vitals.\n${snapshot.error}',
                      isError: true,
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.text),
                    );
                  }

                  final readings = snapshot.data ?? const <VitalReading>[];
                  if (readings.isEmpty) {
                    return const _StateMessage(
                      text: 'No vitals found yet. Waiting for incoming readings.',
                    );
                  }

                  final latest = readings.first;
                  final history = readings.take(50).toList().reversed.toList();

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TopBar(title: 'Heart Rate Details'),
                        const SizedBox(height: 16),
                        _HeartHeroCard(latest: latest),
                        const SizedBox(height: 12),
                        _PredictionCard(latest: latest),
                        const SizedBox(height: 12),
                        _TrendChartCard(
                          title: 'Heart Rate Trend',
                          subtitle: 'Recent ${history.length} readings',
                          color: AppColors.blueInk,
                          unit: 'bpm',
                          spots: _buildSpots(history, (v) => v.heartRate),
                        ),
                        const SizedBox(height: 12),
                        _TrendChartCard(
                          title: 'RR Interval Trend',
                          subtitle: latest.rrStatusText,
                          color: AppColors.greenInk,
                          unit: 'ms',
                          spots: _buildSpots(history, (v) => v.rrInterval),
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          title: 'AI Reading Context',
                          text:
                              latest.stateSummaryText.isNotEmpty
                                  ? latest.stateSummaryText
                                  : 'RR interval represents the time between two consecutive heartbeats.',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<FlSpot> _buildSpots(
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleAction(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 24,
              letterSpacing: -0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatefulWidget {
  const _CircleAction({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_CircleAction> createState() => _CircleActionState();
}

class _CircleActionState extends State<_CircleAction> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: _hovering
              ? const [
                  BoxShadow(
                    color: AppColors.glowBlue,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: AppColors.navUnselected,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(widget.icon, size: 20, color: AppColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartHeroCard extends StatelessWidget {
  const _HeartHeroCard({required this.latest});

  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    final showAlert = latest.alertTriggered || latest.isHeartRateRelatedAnomaly;
    final headerColor = showAlert ? AppColors.softOrange : AppColors.pastelBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(
        headerColor,
        radius: 30,
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monitor_heart_rounded,
                  size: 28,
                  color: showAlert ? const Color(0xFFA4561F) : AppColors.blueInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.patientStateText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 26,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest.rrStatusText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: showAlert
                            ? const Color(0xFF8F5B26)
                            : const Color(0xFF456073),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest.heartRateText,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 58,
                  height: 0.95,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'bpm',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.blueInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              _MiniPill(
                label: 'RR ${latest.rrText} ms',
                color: AppColors.background,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat('EEE, d MMM - hh:mm a').format(latest.createdAt.toLocal()),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (showAlert) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                latest.friendlyAnomalyMessage.isNotEmpty
                    ? latest.friendlyAnomalyMessage
                    : 'Heart-rate related anomaly detected.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF7E4B18),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.latest});

  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    String asText(double? value, {int decimals = 3}) =>
        value == null ? '--' : value.toStringAsFixed(decimals);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(
        AppColors.pastelGrey,
        radius: 28,
        shadows: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.blueInk,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'LSTM Prediction',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: 'actual', value: asText(latest.actualHrScaled)),
              _MetricPill(
                label: 'predicted',
                value: asText(latest.predictedHrScaled),
              ),
              _MetricPill(label: 'error', value: asText(latest.error)),
              _MetricPill(label: 'threshold', value: asText(latest.threshold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSoft,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.unit,
    required this.spots,
  });

  final String title;
  final String subtitle;
  final Color color;
  final String unit;
  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final point in spots) {
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    if ((maxY - minY).abs() < 1) {
      minY -= 1;
      maxY += 1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(
        AppColors.background,
        radius: 28,
        shadows: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minY: minY - ((maxY - minY) * 0.08),
                maxY: maxY + ((maxY - minY) * 0.08),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY) / 4).clamp(1, 1000),
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: color.withValues(alpha: 0.16), strokeWidth: 1),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes
                        .map(
                          (_) => TouchedSpotIndicatorData(
                            FlLine(
                              color: color.withValues(alpha: 0.45),
                              strokeWidth: 1.1,
                              dashArray: [4, 4],
                            ),
                            FlDotData(
                              getDotPainter: (_, __, ___, ____) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: AppColors.background,
                                    strokeWidth: 2,
                                    strokeColor: color,
                                  ),
                            ),
                          ),
                        )
                        .toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.text,
                    getTooltipItems: (items) {
                      return items
                          .map(
                            (item) => LineTooltipItem(
                              '${item.y.toStringAsFixed(0)} $unit',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList();
                    },
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    isStrokeCapRound: true,
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.68)],
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
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(
        const Color(0xFFF7FBFE),
        radius: 28,
        shadows: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.pastelBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.blueInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF47515E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 11),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
        decoration: softCardDecoration(
        isError ? AppColors.pastelRed : AppColors.pastelGrey,
        radius: 28,
        shadows: const [],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: isError ? const Color(0xFF8A1F1F) : AppColors.text,
        ),
      ),
    );
  }
}
