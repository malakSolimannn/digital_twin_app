import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'models/vital_reading.dart';
import 'vitals_repository.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (VitalsRepository.client == null) {
      return const _AlertsMessage(
        text: VitalsRepository.configError,
        isError: true,
      );
    }

    return StreamBuilder<List<VitalReading>>(
      stream: VitalsRepository.readingsStream(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AlertsMessage(
            text: 'Failed to load alerts.\n${snapshot.error}',
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
        final alerts = readings.where((item) => item.alertTriggered).toList();

        final warningCount = readings
            .where((item) => item.isAnomaly && !item.alertTriggered)
            .length;

        final criticalCount = alerts.length;
        final latestAlert = alerts.isEmpty ? null : alerts.first;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AlertsHeader(
                totalAlerts: alerts.length,
                criticalCount: criticalCount,
                warningCount: warningCount,
                latestAlert: latestAlert,
              ),
              const SizedBox(height: 18),
              if (alerts.isEmpty)
                const _EmptyStateCard()
              else ...[
                _MetricsRow(
                  criticalCount: criticalCount,
                  warningCount: warningCount,
                  streamCount: readings.length,
                ),
                const SizedBox(height: 18),
                ...List.generate(
                  alerts.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == alerts.length - 1 ? 0 : 14,
                    ),
                    child: _AlertCard(
                      reading: alerts[index],
                      isLatest: index == 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AlertsHeader extends StatelessWidget {
  const _AlertsHeader({
    required this.totalAlerts,
    required this.criticalCount,
    required this.warningCount,
    required this.latestAlert,
  });

  final int totalAlerts;
  final int criticalCount;
  final int warningCount;
  final VitalReading? latestAlert;

  @override
  Widget build(BuildContext context) {
    final hasAlerts = totalAlerts > 0;
    final tone = hasAlerts ? _AlertVisual.critical() : _AlertVisual.stable();
    final subtitle = hasAlerts
        ? '$criticalCount confirmed alerts. $warningCount warnings monitored separately.'
        : 'No active anomalies in recent monitoring.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE8E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tone.softColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(tone.icon, color: tone.strongColor, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerts',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 30, letterSpacing: -1.1),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasAlerts ? 'Active monitoring' : 'All systems normal',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _CapsuleTag(
                text: hasAlerts ? '$totalAlerts Active' : 'Clear',
                background: tone.softColor,
                foreground: tone.strongColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4A5562)),
          ),
          if (latestAlert != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE9EAEE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: tone.strongColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestAlert!.patientStateText,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat(
                            'EEE, d MMM - hh:mm a',
                          ).format(latestAlert!.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(text: latestAlert!.statusText),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.criticalCount,
    required this.warningCount,
    required this.streamCount,
  });

  final int criticalCount;
  final int warningCount;
  final int streamCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Critical',
            value: '$criticalCount',
            accent: const Color(0xFFC84535),
            background: const Color(0xFFFFF2F0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Warning',
            value: '$warningCount',
            accent: const Color(0xFFB26A18),
            background: const Color(0xFFFFF7EC),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Stream',
            value: '$streamCount',
            accent: const Color(0xFF46607A),
            background: const Color(0xFFF3F6F9),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.background,
  });

  final String label;
  final String value;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 16),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 24, letterSpacing: -0.8),
          ),
          const SizedBox(height: 8),
          Container(
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _widthFactor(value),
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _widthFactor(String value) {
    final parsed = int.tryParse(value) ?? 0;
    return (parsed / 10).clamp(0.18, 1.0);
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.reading, required this.isLatest});

  final VitalReading reading;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final visual = _AlertVisual.critical();
    final message = reading.friendlyAnomalyMessage.isNotEmpty
        ? reading.friendlyAnomalyMessage
        : 'An alert condition was detected for this reading.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE8E8EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: visual.softColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(visual.icon, color: visual.strongColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reading.patientStateText,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontSize: 22, letterSpacing: -0.6),
                          ),
                        ),
                        if (isLatest)
                          _CapsuleTag(
                            text: 'Latest',
                            background: const Color(0xFFF2F3F5),
                            foreground: const Color(0xFF57606C),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat(
                        'EEE, d MMM - hh:mm a',
                      ).format(reading.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatusPill(text: reading.statusText),
              const SizedBox(width: 8),
              if (reading.anomalyReason?.trim().isNotEmpty == true)
                _CapsuleTag(
                  text: _formatReason(reading.anomalyReason!),
                  background: visual.softColor,
                  foreground: visual.strongColor,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF414B57)),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _VitalStat(
                    label: 'Heart Rate',
                    value: '${reading.heartRateText} bpm',
                  ),
                ),
                Expanded(
                  child: _VitalStat(
                    label: 'SpO2',
                    value: '${reading.spo2Text}%',
                  ),
                ),
                Expanded(
                  child: _VitalStat(
                    label: 'RR',
                    value: _rrShortText(reading.rrStatus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _rrShortText(String? status) {
    final value = status?.trim().toLowerCase();
    if (value == null || value.isEmpty || value == 'unknown') {
      return 'Unknown';
    }
    if (value.contains('short_rr_interval')) return 'Short';
    if (value.contains('long_rr_interval')) return 'Long';
    if (value.contains('normal')) return 'Normal';
    return 'Unknown';
  }

  static String _formatReason(String reason) {
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
}

class _VitalStat extends StatelessWidget {
  const _VitalStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 11,
            color: const Color(0xFF7A8591),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontSize: 13, color: AppColors.text),
        ),
      ],
    );
  }
}

class _CapsuleTag extends StatelessWidget {
  const _CapsuleTag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontSize: 11, color: foreground),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final status = text.toLowerCase();
    Color background;
    Color foreground;
    if (status == 'critical') {
      background = const Color(0xFFFFF2F0);
      foreground = const Color(0xFFC84535);
    } else if (status == 'warning') {
      background = const Color(0xFFFFF7EC);
      foreground = const Color(0xFFB26A18);
    } else if (status == 'normal') {
      background = const Color(0xFFEFF8F0);
      foreground = const Color(0xFF2F7B46);
    } else {
      background = const Color(0xFFF2F3F5);
      foreground = const Color(0xFF66707C);
    }

    return _CapsuleTag(
      text: _titleCase(text),
      background: background,
      foreground: foreground,
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE8E8EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF2F7B46),
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No active alerts',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 28,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The monitoring stream is stable and no current readings are flagged as anomalous.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4A5562)),
          ),
        ],
      ),
    );
  }
}

class _AlertsMessage extends StatelessWidget {
  const _AlertsMessage({required this.text, this.isError = false});

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

String _titleCase(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return value;
  return normalized
      .split(RegExp(r'[\s_]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _AlertVisual {
  const _AlertVisual({
    required this.softColor,
    required this.strongColor,
    required this.icon,
  });

  final Color softColor;
  final Color strongColor;
  final IconData icon;

  factory _AlertVisual.critical() {
    return const _AlertVisual(
      softColor: Color(0xFFFFF2F0),
      strongColor: Color(0xFFC84535),
      icon: Icons.notifications_active_rounded,
    );
  }

  factory _AlertVisual.warning() {
    return const _AlertVisual(
      softColor: Color(0xFFFFF7EC),
      strongColor: Color(0xFFB26A18),
      icon: Icons.warning_amber_rounded,
    );
  }

  factory _AlertVisual.stable() {
    return const _AlertVisual(
      softColor: Color(0xFFEFF8F0),
      strongColor: Color(0xFF2F7B46),
      icon: Icons.verified_rounded,
    );
  }
}
