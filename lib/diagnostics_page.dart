import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'heart_rate_details_page.dart';
import 'models/vital_reading.dart';
import 'spo2_details_page.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
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
                            .take(20)
                            .toList()
                            .reversed
                            .toList();
                        final preview = readings.take(10).toList();

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TopHeader(latest: latest),
                              const SizedBox(height: 14),
                              if (latest.isAnomaly ||
                                  latest.alertTriggered) ...[
                                _AlertBanner(latest: latest),
                                const SizedBox(height: 12),
                              ],
                              _TappableCard(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const HeartRateDetailsPage(),
                                    ),
                                  );
                                },
                                child: _HeartbeatCard(
                                  latest: latest,
                                  hrSpots: _spots(history, (v) => v.heartRate),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _TappableCard(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const Spo2DetailsPage(),
                                    ),
                                  );
                                },
                                child: _Spo2Card(latest: latest),
                              ),
                              const SizedBox(height: 12),
                              _ResultsCard(latest: latest),
                              const SizedBox(height: 12),
                              _RecentPreviewCard(
                                items: preview,
                                hrSpots: _spots(history, (v) => v.heartRate),
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

  List<FlSpot> _spots(
    List<VitalReading> source,
    double? Function(VitalReading row) selector,
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

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.latest});
  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CircleAction(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            const _CircleAction(icon: Icons.description_outlined),
            const SizedBox(width: 10),
            const _CircleAction(icon: Icons.north_rounded),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Diagnostics',
          style: TextStyle(
            color: Color(0xFF101218),
            fontWeight: FontWeight.w800,
            fontSize: 44,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEE, d MMM - hh:mm a').format(latest.createdAt.toLocal()),
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, size: 23, color: const Color(0xFF262B36)),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.latest});
  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    final strong = latest.alertTriggered;
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
              strong
                  ? 'Alert Triggered: ${latest.anomalyMessage ?? 'Critical reading detected.'}'
                  : (latest.anomalyMessage ??
                        'Anomaly detected in latest reading.'),
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

class _TappableCard extends StatelessWidget {
  const _TappableCard({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: child,
    );
  }
}

class _HeartbeatCard extends StatelessWidget {
  const _HeartbeatCard({required this.latest, required this.hrSpots});
  final VitalReading latest;
  final List<FlSpot> hrSpots;

  @override
  Widget build(BuildContext context) {
    double minY = hrSpots.first.y;
    double maxY = hrSpots.first.y;
    for (final s in hrSpots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    if ((maxY - minY).abs() < 1) {
      minY -= 2;
      maxY += 2;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFBEEAF6),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
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
                  color: Color(0xFFFFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monitor_heart_rounded, size: 26),
              ),
              const SizedBox(width: 10),
              const Text(
                'Heartbeat',
                style: TextStyle(
                  color: Color(0xFF1E2A33),
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF2E4758)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest.heartRateText,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F141A),
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 9),
                child: Text(
                  'bpm',
                  style: TextStyle(
                    color: Color(0xFF1F2A33),
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes
                        .map(
                          (_) => TouchedSpotIndicatorData(
                            FlLine(
                              color: const Color(
                                0xFF2F4756,
                              ).withValues(alpha: 0.35),
                              strokeWidth: 1.2,
                              dashArray: [4, 4],
                            ),
                            FlDotData(
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 3.8,
                                    color: const Color(0xFFFFFFFF),
                                    strokeWidth: 2,
                                    strokeColor: const Color(0xFF4A6978),
                                  ),
                            ),
                          ),
                        )
                        .toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF24343F),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(0)} bpm',
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
                minY: minY - 5,
                maxY: maxY + 5,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0xFF3C5967).withValues(alpha: 0.18),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: hrSpots,
                    isCurved: true,
                    isStrokeCapRound: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF314B5A), Color(0xFF5D7E8E)],
                    ),
                    barWidth: 2.4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF4A6978).withValues(alpha: 0.22),
                          const Color(0xFF4A6978).withValues(alpha: 0.02),
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

class _Spo2Card extends StatelessWidget {
  const _Spo2Card({required this.latest});
  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD7EDC3),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop_rounded, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latest.spo2Text == '--' ? '--%' : '${latest.spo2Text}%',
                  style: const TextStyle(
                    color: Color(0xFF16231B),
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Blood Oxygen',
                  style: TextStyle(
                    color: Color(0xFF2B4235),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF2E4A3A)),
        ],
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.latest});
  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _Chip(text: latest.statusText, color: _statusColor(latest.statusText)),
    ];
    if (latest.anomalyReason?.trim().isNotEmpty == true) {
      chips.add(
        _Chip(text: latest.anomalyReason!, color: const Color(0xFFE9F4FF)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
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
          const Text(
            'Results / Status',
            style: TextStyle(
              color: Color(0xFF101218),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latest.anomalyMessage?.trim().isNotEmpty == true
                ? latest.anomalyMessage!
                : 'No anomaly message for the latest reading.',
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return const Color(0xFFE6F5EA);
      case 'warning':
        return const Color(0xFFFFF1DD);
      case 'critical':
        return const Color(0xFFFFE8E5);
      default:
        return const Color(0xFFE9F4FF);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RecentPreviewCard extends StatelessWidget {
  const _RecentPreviewCard({required this.items, required this.hrSpots});
  final List<VitalReading> items;
  final List<FlSpot> hrSpots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Readings',
            style: TextStyle(
              color: Color(0xFF111318),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes
                        .map(
                          (_) => TouchedSpotIndicatorData(
                            FlLine(
                              color: const Color(
                                0xFF4F6E80,
                              ).withValues(alpha: 0.3),
                              strokeWidth: 1,
                            ),
                            FlDotData(
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 3.2,
                                    color: const Color(0xFFFFFFFF),
                                    strokeWidth: 1.8,
                                    strokeColor: const Color(0xFF6D8FA1),
                                  ),
                            ),
                          ),
                        )
                        .toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF24343F),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    getTooltipItems: (items) {
                      return items
                          .map(
                            (item) => LineTooltipItem(
                              '${item.y.toStringAsFixed(0)} bpm',
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
                gridData: FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: hrSpots,
                    isCurved: true,
                    isStrokeCapRound: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5A7B8D), Color(0xFF8FB3C5)],
                    ),
                    barWidth: 2.2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF6D8FA1).withValues(alpha: 0.25),
                          const Color(0xFF6D8FA1).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final row = items[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: Text(
                    '${row.heartRateText} bpm - ${row.spo2Text}%',
                    style: const TextStyle(
                      color: Color(0xFF404757),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
