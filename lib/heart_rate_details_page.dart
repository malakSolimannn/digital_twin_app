import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/vital_reading.dart';

class HeartRateDetailsPage extends StatefulWidget {
  const HeartRateDetailsPage({super.key});

  @override
  State<HeartRateDetailsPage> createState() => _HeartRateDetailsPageState();
}

class _HeartRateDetailsPageState extends State<HeartRateDetailsPage> {
  static const int _historyLimit = 50;
  SupabaseClient? _client;
  String? _clientError;

  @override
  void initState() {
    super.initState();
    try {
      _client = Supabase.instance.client;
    } catch (_) {
      _clientError =
          'Supabase is not initialized. Add SUPABASE_URL and SUPABASE_ANON_KEY in main.dart run config.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: _clientError != null
                  ? _StateMessage(text: _clientError!, isError: true)
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _client!
                          .from('vitals')
                          .stream(primaryKey: ['id'])
                          .order('created_at', ascending: false)
                          .limit(_historyLimit),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _StateMessage(
                            text:
                                'Failed to load live vitals.\n${snapshot.error}',
                            isError: true,
                          );
                        }
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF151515),
                            ),
                          );
                        }

                        final rows = snapshot.data ?? const [];
                        if (rows.isEmpty) {
                          return const _StateMessage(
                            text:
                                'No vitals found yet. Waiting for incoming readings.',
                          );
                        }

                        final readings = rows.map(VitalReading.fromMap).toList()
                          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                        final latest = readings.first;
                        final history = readings
                            .take(50)
                            .toList()
                            .reversed
                            .toList();

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TopBar(title: 'Heart Rate Details'),
                              const SizedBox(height: 14),
                              _HeartMainCard(latest: latest),
                              const SizedBox(height: 12),
                              _PredictionCard(latest: latest),
                              const SizedBox(height: 12),
                              _LineChartCard(
                                title: 'Heart Rate Trend',
                                subtitle: 'Recent ${history.length} readings',
                                unit: 'bpm',
                                color: const Color(0xFF4A6978),
                                spots: _buildSpots(history, (v) => v.heartRate),
                              ),
                              const SizedBox(height: 12),
                              _LineChartCard(
                                title: 'RR Interval Trend',
                                subtitle: 'Recent ${history.length} readings',
                                unit: 'ms',
                                color: const Color(0xFF5D8C6A),
                                spots: _buildSpots(
                                  history,
                                  (v) => v.rrInterval,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _InfoCard(
                                text:
                                    'RR interval represents the time between two consecutive heartbeats.',
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

  List<FlSpot> _buildSpots(
    List<VitalReading> source,
    double? Function(VitalReading item) selector,
  ) {
    final spots = <FlSpot>[];
    for (var i = 0; i < source.length; i++) {
      final value = selector(source[i]);
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    return spots.isEmpty ? const [FlSpot(0, 0)] : spots;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: const Color(0xFFF2F4F7),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101218),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeartMainCard extends StatelessWidget {
  const _HeartMainCard({required this.latest});
  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    final warning = latest.alertTriggered || latest.isHeartRateRelatedAnomaly;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDEF0FA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${latest.heartRateText} bpm',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F141A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'RR interval: ${latest.rrText} ms',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF33404A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat(
              'EEE, d MMM • hh:mm a',
            ).format(latest.createdAt.toLocal()),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C6770),
            ),
          ),
          if (warning) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: latest.alertTriggered
                    ? const Color(0xFFFFECE8)
                    : const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                latest.anomalyMessage?.trim().isNotEmpty == true
                    ? latest.anomalyMessage!
                    : 'Heart-rate related anomaly detected.',
                style: const TextStyle(
                  color: Color(0xFF913924),
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
    String asText(double? v, {int decimals = 3}) =>
        v == null ? '--' : v.toStringAsFixed(decimals);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LSTM Prediction',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151A22),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KV(
                label: 'actual_hr_scaled',
                value: asText(latest.actualHrScaled),
              ),
              _KV(
                label: 'predicted_hr_scaled',
                value: asText(latest.predictedHrScaled),
              ),
              _KV(label: 'error', value: asText(latest.error)),
              _KV(label: 'threshold', value: asText(latest.threshold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.color,
    required this.spots,
  });
  final String title;
  final String subtitle;
  final String unit;
  final Color color;
  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    if ((maxY - minY).abs() < 1) {
      maxY += 1;
      minY -= 1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151A22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY - ((maxY - minY) * 0.08),
                maxY: maxY + ((maxY - minY) * 0.08),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY) / 4).clamp(1, 1000),
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: const Color(0x22000000), strokeWidth: 1),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes
                        .map(
                          (_) => TouchedSpotIndicatorData(
                            FlLine(
                              color: color.withValues(alpha: 0.45),
                              strokeWidth: 1.2,
                              dashArray: [4, 4],
                            ),
                            FlDotData(
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: const Color(0xFFFFFFFF),
                                    strokeWidth: 2,
                                    strokeColor: color,
                                  ),
                            ),
                          ),
                        )
                        .toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF212E38),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    getTooltipItems: (items) {
                      return items.map((item) {
                        return LineTooltipItem(
                          '${item.y.toStringAsFixed(0)} $unit',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    isStrokeCapRound: true,
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.95),
                        color.withValues(alpha: 0.65),
                      ],
                    ),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.22),
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
  const _InfoCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF3F4652),
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? const Color(0xFF8A1F1F) : const Color(0xFF444444),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
