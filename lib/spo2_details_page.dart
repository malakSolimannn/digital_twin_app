import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/vital_reading.dart';

class Spo2DetailsPage extends StatefulWidget {
  const Spo2DetailsPage({super.key});

  @override
  State<Spo2DetailsPage> createState() => _Spo2DetailsPageState();
}

class _Spo2DetailsPageState extends State<Spo2DetailsPage> {
  static const int _historyLimit = 50;
  static const double _spo2Threshold = 95;

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

                        final spo2 = latest.spo2 ?? 0;
                        final lowSpo2 = spo2 > 0 && spo2 < _spo2Threshold;
                        final relatedAnomaly = latest.isSpo2RelatedAnomaly;
                        final showBanner =
                            lowSpo2 || latest.alertTriggered || relatedAnomaly;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _TopBar(title: 'SpO2 Details'),
                              const SizedBox(height: 14),
                              _MainSpo2Card(
                                latest: latest,
                                isLow: lowSpo2,
                                threshold: _spo2Threshold,
                              ),
                              if (showBanner) ...[
                                const SizedBox(height: 12),
                                _WarningBanner(
                                  strong: latest.alertTriggered,
                                  text: latest.alertTriggered
                                      ? 'Alert Triggered: ${latest.anomalyMessage ?? 'SpO2-related alert condition detected.'}'
                                      : (lowSpo2
                                            ? 'SpO2 is below threshold (95%).'
                                            : (latest.anomalyMessage ??
                                                  'SpO2-related anomaly detected.')),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _Spo2ChartCard(
                                spots: _buildSpots(history),
                                threshold: _spo2Threshold,
                              ),
                              const SizedBox(height: 12),
                              const _InfoCard(
                                text:
                                    'Values below 95% are treated as below the configured normal threshold.',
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

  List<FlSpot> _buildSpots(List<VitalReading> source) {
    final spots = <FlSpot>[];
    for (var i = 0; i < source.length; i++) {
      final value = source[i].spo2;
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

class _MainSpo2Card extends StatelessWidget {
  const _MainSpo2Card({
    required this.latest,
    required this.isLow,
    required this.threshold,
  });
  final VitalReading latest;
  final bool isLow;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF1CB),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latest.spo2Text == '--' ? '--%' : '${latest.spo2Text}%',
            style: const TextStyle(
              color: Color(0xFF16231B),
              fontSize: 42,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isLow ? 'Status: Warning (below 95%)' : 'Status: Normal',
            style: TextStyle(
              color: isLow ? const Color(0xFF9A4A19) : const Color(0xFF2D7F4A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Threshold: ${threshold.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Color(0xFF3E4A54),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.strong, required this.text});
  final bool strong;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: strong ? const Color(0xFFFFE8E5) : const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            strong
                ? Icons.notification_important_rounded
                : Icons.warning_rounded,
            color: strong ? const Color(0xFFB53E2E) : const Color(0xFF9A4A19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: strong
                    ? const Color(0xFF8D2D21)
                    : const Color(0xFF8A4417),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spo2ChartCard extends StatelessWidget {
  const _Spo2ChartCard({required this.spots, required this.threshold});
  final List<FlSpot> spots;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    minY = minY > 90 ? 90 : minY - 1;
    maxY = maxY < 100 ? 100 : maxY + 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SpO2 Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151A22),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
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
                              color: const Color(
                                0xFF4E7759,
                              ).withValues(alpha: 0.45),
                              strokeWidth: 1.2,
                              dashArray: [4, 4],
                            ),
                            FlDotData(
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: const Color(0xFFFFFFFF),
                                    strokeWidth: 2,
                                    strokeColor: const Color(0xFF5D8C6A),
                                  ),
                            ),
                          ),
                        )
                        .toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF22313A),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    getTooltipItems: (items) {
                      return items.map((item) {
                        return LineTooltipItem(
                          '${item.y.toStringAsFixed(0)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
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
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: threshold,
                      color: const Color(0xFFBE6A2D),
                      strokeWidth: 2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          color: Color(0xFF8F4612),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        labelResolver: (_) => '95%',
                      ),
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    isStrokeCapRound: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4E7759), Color(0xFF7FAD8B)],
                    ),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF5D8C6A).withValues(alpha: 0.2),
                          const Color(0xFF5D8C6A).withValues(alpha: 0.03),
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
