import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'heart_rate_details_page.dart';
import 'models/vital_reading.dart';
import 'spo2_details_page.dart';
import 'vitals_repository.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (VitalsRepository.client == null) {
      return const _StateMessage(
        text: VitalsRepository.configError,
        isError: true,
      );
    }

    final body = StreamBuilder<List<VitalReading>>(
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
        final history = readings.take(20).toList().reversed.toList();
        final preview = readings.take(10).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopHeader(latest: latest, embedded: embedded),
              const SizedBox(height: 14),
              if (latest.isAnomaly || latest.alertTriggered) ...[
                _AlertBanner(latest: latest),
                const SizedBox(height: 12),
              ],
              _TappableCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HeartRateDetailsPage(),
                    ),
                  );
                },
                child: _HeartbeatCard(
                  latest: latest,
                  hrSpots: _spots(history, (v) => v.heartRate),
                ),
              ),
              const SizedBox(height: 12),
              _RrBreathingRingCard(latest: latest),
              const SizedBox(height: 12),
              _TappableCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Spo2DetailsPage()),
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
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: Padding(padding: AppLayout.pagePadding, child: body),
          ),
        ),
      ),
    );
  }

  static List<FlSpot> _spots(
    List<VitalReading> source,
    double? Function(VitalReading row) selector,
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

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.latest, required this.embedded});

  final VitalReading latest;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!embedded)
              _CircleAction(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              )
            else
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: AppColors.navUnselected,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.text,
                ),
              ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),
        Text('Diagnostics', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEE, d MMM - hh:mm a').format(latest.createdAt.toLocal()),
          style: Theme.of(context).textTheme.bodyLarge,
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
      color: AppColors.navUnselected,
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
    final message = latest.friendlyAnomalyMessage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: strong ? AppColors.pastelRed : AppColors.softOrange,
        borderRadius: BorderRadius.circular(22),
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
                  ? 'Alert Triggered: ${message.isNotEmpty ? message : 'Critical reading detected.'}'
                  : (message.isNotEmpty
                        ? message
                        : 'Anomaly detected in latest reading.'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      borderRadius: BorderRadius.circular(38),
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
    for (final point in hrSpots) {
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    if ((maxY - minY).abs() < 1) {
      minY -= 2;
      maxY += 2;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: softCardDecoration(AppColors.pastelBlue, radius: 38),
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
                child: const Icon(Icons.monitor_heart_rounded, size: 26),
              ),
              const SizedBox(width: 10),
              Text(
                'Heartbeat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 28,
                  color: const Color(0xFF1E2A33),
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
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 56,
                  color: const Color(0xFF0F141A),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  'bpm',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF1F2A33),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: _SparkChart(
              points: hrSpots,
              color: const Color(0xFF4A6978),
              unit: 'bpm',
            ),
          ),
        ],
      ),
    );
  }
}

class _RrBreathingRingCard extends StatefulWidget {
  const _RrBreathingRingCard({required this.latest});

  final VitalReading latest;

  @override
  State<_RrBreathingRingCard> createState() => _RrBreathingRingCardState();
}

class _RrBreathingRingCardState extends State<_RrBreathingRingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _meta.duration,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RrBreathingRingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_meta.duration != _durationFor(oldWidget.latest)) {
      _controller.duration = _meta.duration;
      _controller
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _RrVisualMeta get _meta => _metaFor(widget.latest);

  @override
  Widget build(BuildContext context) {
    final rrText = widget.latest.rrInterval == null
        ? '-- ms'
        : '${widget.latest.rrInterval!.toStringAsFixed(0)} ms';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(
        const Color(0xFFF7F7F5),
        radius: 36,
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            spreadRadius: 1,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse = Curves.easeInOut.transform(_controller.value);
              final outerScale = _lerpDouble(0.94, _meta.outerScale, pulse);
              final middleScale = _lerpDouble(0.98, _meta.middleScale, pulse);
              final outerOpacity = _lerpDouble(
                0.18,
                _meta.outerOpacity,
                pulse,
              );

              return SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: outerScale,
                      child: Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _meta.color.withValues(alpha: outerOpacity),
                          boxShadow: [
                            BoxShadow(
                              color: _meta.color.withValues(alpha: 0.16),
                              blurRadius: 24,
                              spreadRadius: 4,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: middleScale,
                      child: Container(
                        width: 98,
                        height: 98,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _meta.color.withValues(alpha: 0.95),
                              _meta.color.withValues(alpha: 0.58),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.background,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _meta.icon,
                        color: _meta.iconColor,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'RR Rhythm',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rrText,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 34,
                    color: AppColors.text,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _meta.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF54606E),
                    fontSize: 13,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 12),
                _Chip(text: _meta.label, color: _meta.pillColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Duration _durationFor(VitalReading latest) => _metaFor(latest).duration;

  static _RrVisualMeta _metaFor(VitalReading latest) {
    final status = latest.rrStatus?.trim().toLowerCase() ?? 'unknown';
    switch (status) {
      case 'normal':
        return const _RrVisualMeta(
          color: Color(0xFF7BC48A),
          pillColor: AppColors.pastelGreen,
          iconColor: Color(0xFF2D6A3A),
          icon: Icons.favorite_rounded,
          label: 'Normal',
          subtitle: 'Regular heart rhythm',
          duration: Duration(milliseconds: 2200),
          outerScale: 1.1,
          middleScale: 1.04,
          outerOpacity: 0.28,
        );
      case 'short_rr_interval':
        return const _RrVisualMeta(
          color: Color(0xFFE3AF42),
          pillColor: AppColors.softOrange,
          iconColor: Color(0xFF9B5A16),
          icon: Icons.graphic_eq_rounded,
          label: 'Short RR',
          subtitle: 'Short RR interval detected',
          duration: Duration(milliseconds: 1200),
          outerScale: 1.16,
          middleScale: 1.06,
          outerOpacity: 0.34,
        );
      case 'long_rr_interval':
        return const _RrVisualMeta(
          color: Color(0xFF89C6EA),
          pillColor: AppColors.pastelBlue,
          iconColor: Color(0xFF2D6685),
          icon: Icons.favorite_outline_rounded,
          label: 'Long RR',
          subtitle: 'Long RR interval detected',
          duration: Duration(milliseconds: 2800),
          outerScale: 1.08,
          middleScale: 1.03,
          outerOpacity: 0.26,
        );
      default:
        return const _RrVisualMeta(
          color: Color(0xFFCDD5DF),
          pillColor: AppColors.pastelGrey,
          iconColor: Color(0xFF7A8795),
          icon: Icons.favorite_border_rounded,
          label: 'Collecting',
          subtitle: 'Collecting rhythm data',
          duration: Duration(milliseconds: 2400),
          outerScale: 1.04,
          middleScale: 1.02,
          outerOpacity: 0.18,
        );
    }
  }

  static double _lerpDouble(double begin, double end, double t) {
    return begin + (end - begin) * t;
  }
}

class _Spo2Card extends StatelessWidget {
  const _Spo2Card({required this.latest});

  final VitalReading latest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(AppColors.pastelGreen, radius: 34),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.background,
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF16231B),
                    fontSize: 36,
                  ),
                ),
                Text(
                  'Blood Oxygen',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF2B4235),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softCardDecoration(AppColors.background, radius: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Results / Status',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            latest.friendlyAnomalyMessage.isNotEmpty
                ? latest.friendlyAnomalyMessage
                : latest.stateSummaryText,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF374151)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                text: latest.statusText,
                color: _statusColor(latest.statusText),
              ),
              if (latest.anomalyReason?.trim().isNotEmpty == true)
                _Chip(
                  text: _reasonLabel(latest.anomalyReason!),
                  color: AppColors.pastelBlue,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _reasonLabel(String reason) {
    switch (reason.trim().toLowerCase()) {
      case 'heart_rate':
        return 'Heart Rate';
      case 'spo2':
        return 'SpO2';
      case 'heart_rate_and_spo2':
        return 'HR + SpO2';
      case 'rule_based_risk':
        return 'Rule-Based Risk';
      default:
        return reason
            .split('_')
            .where((part) => part.isNotEmpty)
            .map(
              (part) =>
                  '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return AppColors.pastelGreen;
      case 'warning':
        return AppColors.softOrange;
      case 'critical':
        return AppColors.pastelRed;
      default:
        return AppColors.pastelGrey;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: const Color(0xFF334155)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pastelGrey,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Readings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: _SparkChart(
              points: hrSpots,
              color: const Color(0xFF6D8FA1),
              unit: 'bpm',
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
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE7EAF0)),
                  ),
                  child: Text(
                    '${row.heartRateText} bpm - ${row.spo2Text}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF404757),
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

class _SparkChart extends StatelessWidget {
  const _SparkChart({
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
      minY -= 2;
      maxY += 2;
    }

    return LineChart(
      LineChartData(
        minY: minY - 2,
        maxY: maxY + 2,
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF24343F),
            getTooltipItems: (items) => items
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
                .toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: color.withValues(alpha: 0.18), strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            isStrokeCapRound: true,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.95),
                color.withValues(alpha: 0.65),
              ],
            ),
            barWidth: 2.4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.02),
                ],
              ),
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

class _RrVisualMeta {
  const _RrVisualMeta({
    required this.color,
    required this.pillColor,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.duration,
    required this.outerScale,
    required this.middleScale,
    required this.outerOpacity,
  });

  final Color color;
  final Color pillColor;
  final Color iconColor;
  final IconData icon;
  final String label;
  final String subtitle;
  final Duration duration;
  final double outerScale;
  final double middleScale;
  final double outerOpacity;
}
