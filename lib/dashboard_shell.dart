import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'alerts_page.dart';
import 'app_theme.dart';
import 'diagnostics_page.dart';
import 'heart_rate_details_page.dart';
import 'history_page.dart';
import 'models/vital_reading.dart';
import 'spo2_details_page.dart';
import 'vitals_repository.dart';

enum ShellTab { home, live, history, alerts }

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    this.batteryPercentage = 76,
    this.isDeviceConnected = true,
  });

  final int batteryPercentage;
  final bool isDeviceConnected;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  ShellTab _selectedTab = ShellTab.home;
  late final Future<VitalReading?> _latestFuture;

  @override
  void initState() {
    super.initState();
    _latestFuture = VitalsRepository.fetchLatestReading();
  }

  @override
  Widget build(BuildContext context) {
    final client = VitalsRepository.client;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                    child: client == null
                        ? const _ConfigurationMessage()
                        : IndexedStack(
                            index: _selectedTab.index,
                            children: [
                              HomeTab(
                                latestFuture: _latestFuture,
                                batteryPercentage: widget.batteryPercentage,
                                isDeviceConnected: widget.isDeviceConnected,
                              ),
                              const DiagnosticsPage(embedded: true),
                              const HistoryPage(),
                              const AlertsPage(),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: _FloatingNav(
                      selectedTab: _selectedTab,
                      onSelect: (tab) => setState(() => _selectedTab = tab),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.latestFuture,
    required this.batteryPercentage,
    required this.isDeviceConnected,
  });

  final Future<VitalReading?> latestFuture;
  final int batteryPercentage;
  final bool isDeviceConnected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VitalReading?>(
      future: latestFuture,
      builder: (context, initialSnapshot) {
        return StreamBuilder<List<VitalReading>>(
          stream: VitalsRepository.readingsStream(limit: 24),
          builder: (context, streamSnapshot) {
            final readings = streamSnapshot.data ?? const <VitalReading>[];
            final latest = readings.isNotEmpty
                ? readings.first
                : initialSnapshot.data;
            final history = readings.take(12).toList().reversed.toList();

            if (streamSnapshot.hasError) {
              return _ConfigurationMessage(
                text: 'Failed to load live vitals.\n${streamSnapshot.error}',
                isError: true,
              );
            }

            if (streamSnapshot.connectionState == ConnectionState.waiting &&
                latest == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.text),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(
                    batteryPercentage: latest?.batteryPercentage ?? 0,
                    isDeviceConnected: latest != null,
                    recentReadings: readings,
                  ),
                  const SizedBox(height: 18),
                  _MainStateCard(latest: latest),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricSparkCard(
                          title: 'Heart Rate',
                          value: latest == null
                              ? '-- bpm'
                              : '${latest.heartRateText} bpm',
                          trend: latest?.hrTrendText ?? 'collecting',
                          icon: Icons.monitor_heart_outlined,
                          points: _spots(history, (item) => item.heartRate),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HeartRateDetailsPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricSparkCard(
                          title: 'SpO2',
                          value: latest == null ? '--%' : '${latest.spo2Text}%',
                          trend: latest?.spo2TrendText ?? 'collecting',
                          icon: Icons.water_drop_outlined,
                          points: _spots(history, (item) => item.spo2),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const Spo2DetailsPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ResultsCard(latest: latest),
                  const SizedBox(height: 12),
                  _DeviceBatteryCard(
                    batteryPercentage: latest?.batteryPercentage ?? 0,
                    isDeviceConnected: latest != null,
                  ),
                  const SizedBox(height: 12),
                  _LatestReadingStrip(latest: latest),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<FlSpot> _spots(
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.batteryPercentage,
    required this.isDeviceConnected,
    required this.recentReadings,
  });

  final int batteryPercentage;
  final bool isDeviceConnected;
  final List<VitalReading> recentReadings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF6E39A),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFFEAD6BE),
                child: const Icon(
                  Icons.person_rounded,
                  size: 24,
                  color: Color(0xFF6A4E3D),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hello, Patient!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _TopBatteryIndicator(
              batteryPercentage: batteryPercentage,
              isDeviceConnected: isDeviceConnected,
            ),
            const SizedBox(width: 10),
            _NotificationBell(recentReadings: recentReadings),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Heart Health',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 50,
              height: 0.98,
              letterSpacing: -2.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.recentReadings});

  final List<VitalReading> recentReadings;

  @override
  Widget build(BuildContext context) {
    final alerts = recentReadings.where((item) => item.alertTriggered).toList();
    final warnings = recentReadings
        .where((item) => item.isAnomaly && !item.alertTriggered)
        .toList();
    final notifications = [...alerts, ...warnings]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final badgeCount = alerts.length + warnings.length;
    final hasItems = badgeCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _showNotificationsSheet(context, alerts, warnings, notifications),
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE7EAEE)),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                hasItems
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: hasItems
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFF586472),
                size: 25,
              ),
            ),
            if (hasItems)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 10.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(
    BuildContext context,
    List<VitalReading> alerts,
    List<VitalReading> warnings,
    List<VitalReading> notifications,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DDE3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                      children: [
                        _NotificationSheetHeader(
                          alertCount: alerts.length,
                          warningCount: warnings.length,
                        ),
                        const SizedBox(height: 18),
                        if (alerts.isEmpty && warnings.isEmpty)
                          const _NotificationEmptyState()
                        else ...[
                          const _NotificationSectionTitle(
                            text: 'Recent Notifications',
                          ),
                          const SizedBox(height: 10),
                          ...notifications
                              .take(4)
                              .map(
                                (reading) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _NotificationCard(
                                    reading: reading,
                                    accent: reading.alertTriggered
                                        ? AppColors.pastelRed
                                        : AppColors.softOrange,
                                    accentText: reading.alertTriggered
                                        ? const Color(0xFFB53E2E)
                                        : const Color(0xFF9A4A19),
                                    icon: reading.alertTriggered
                                        ? Icons.notifications_active_rounded
                                        : Icons.warning_amber_rounded,
                                    label: reading.alertTriggered
                                        ? 'Alert'
                                        : 'Warning',
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationSheetHeader extends StatelessWidget {
  const _NotificationSheetHeader({
    required this.alertCount,
    required this.warningCount,
  });

  final int alertCount;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                alertCount + warningCount == 0
                    ? 'No new events from your monitoring stream.'
                    : '$alertCount alerts and $warningCount warnings from recent readings.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.pastelGrey,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_rounded,
                size: 18,
                color: Color(0xFF333A44),
              ),
              const SizedBox(width: 8),
              Text(
                '${alertCount + warningCount}',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationSectionTitle extends StatelessWidget {
  const _NotificationSectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontSize: 17, letterSpacing: -0.3),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.reading,
    required this.accent,
    required this.accentText,
    required this.icon,
    required this.label,
  });

  final VitalReading reading;
  final Color accent;
  final Color accentText;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final message = reading.friendlyAnomalyMessage.isNotEmpty
        ? reading.friendlyAnomalyMessage
        : reading.stateSummaryText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E8EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentText, size: 23),
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
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 17),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: accentText,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF404A57),
                    fontSize: 13.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      DateFormat(
                        'EEE, hh:mm a',
                      ).format(reading.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${reading.heartRateText} bpm',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textSoft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${reading.spo2Text}%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.pastelGrey,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: Color(0xFF6C7682),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No active alerts or warnings right now. Your latest readings are quiet.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF495361)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBatteryIndicator extends StatelessWidget {
  const _TopBatteryIndicator({
    required this.batteryPercentage,
    required this.isDeviceConnected,
  });

  final int batteryPercentage;
  final bool isDeviceConnected;

  @override
  Widget build(BuildContext context) {
    final percentage = batteryPercentage.clamp(0, 100).toInt();
    final accent = _accentColor(percentage);
    final textColor = isDeviceConnected ? AppColors.text : AppColors.textSoft;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDeviceConnected ? Colors.white : const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDeviceConnected
              ? Colors.white.withValues(alpha: 0.95)
              : const Color(0xFFE3E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            spreadRadius: 1,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TopBatteryIcon(
            percentage: percentage,
            color: accent,
            isOffline: !isDeviceConnected,
          ),
          const SizedBox(width: 8),
          Text(
            isDeviceConnected ? '$percentage%' : '--%',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontSize: 11.5,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(int percentage) {
    if (!isDeviceConnected) return const Color(0xFF9AA4AE);
    if (percentage < 20) return const Color(0xFFC84535);
    if (percentage <= 50) return const Color(0xFFCC7A22);
    return const Color(0xFF2F9E5B);
  }
}

class _TopBatteryIcon extends StatelessWidget {
  const _TopBatteryIcon({
    required this.percentage,
    required this.color,
    required this.isOffline,
  });

  final int percentage;
  final Color color;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 12,
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            color: isOffline ? const Color(0xFFE5E9ED) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isOffline ? const Color(0xFFCAD1D8) : color,
              width: 1.2,
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: isOffline
                  ? 0.0
                  : (percentage / 100).clamp(0.16, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.4),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 2.5,
          height: 6,
          margin: const EdgeInsets.only(left: 1.8),
          decoration: BoxDecoration(
            color: isOffline ? const Color(0xFFCAD1D8) : color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _MainStateCard extends StatelessWidget {
  const _MainStateCard({required this.latest});

  final VitalReading? latest;

  @override
  Widget build(BuildContext context) {
    final state = latest?.patientStateText ?? 'Collecting Data';
    final summary = _summaryText(latest);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: softCardDecoration(
        _stateColor(state),
        radius: 40,
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            spreadRadius: 1,
            offset: Offset(0, 12),
          ),
        ],
      ), //.copyWith(border: Border.all(color: AppColors.mintStroke, width: 1.2)),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FCF6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_stateIcon(state), color: AppColors.text),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    state,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 28,
                      height: 1,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF2E2E2E),
                      fontSize: 13,
                      height: 1.32,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DiagnosticsPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF2A2A2A),
                            width: 1.4,
                          ),
                        ),
                        child: Text(
                          'Diagnostic',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 154,
            height: 214,
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset('assets/heart.png', fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }

  static String _summaryText(VitalReading? latest) {
    if (latest == null) {
      return 'Waiting for the next digital twin interpretation.';
    }

    final summary = latest.friendlyPatientSummary.trim();
    if (summary.length <= 110) return summary;

    final periodIndex = summary.indexOf('.');
    if (periodIndex > 0 && periodIndex < 96) {
      return summary.substring(0, periodIndex + 1);
    }
    return '${summary.substring(0, 96).trimRight()}...';
  }

  static Color _stateColor(String state) {
    final normalized = state.toLowerCase();
    if (normalized.contains('critical')) return AppColors.pastelRed;
    if (normalized.contains('low oxygen')) return AppColors.pastelBlue;
    if (normalized.contains('unstable')) return AppColors.pastelYellow;
    if (normalized.contains('elevated'))
      return const Color.fromARGB(255, 252, 216, 56);
    if (normalized.contains('collecting')) return AppColors.pastelGreen;
    return AppColors.pastelGreen;
  }

  static IconData _stateIcon(String state) {
    final normalized = state.toLowerCase();
    if (normalized.contains('low oxygen')) return Icons.water_drop_rounded;
    if (normalized.contains('critical')) return Icons.warning_rounded;
    if (normalized.contains('elevated')) return Icons.favorite_rounded;
    return Icons.favorite_border_rounded;
  }
}

class _MetricSparkCard extends StatelessWidget {
  const _MetricSparkCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.points,
    required this.onTap,
  });

  final String title;
  final String value;
  final String trend;
  final IconData icon;
  final List<FlSpot> points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trendStyle = _trendMeta(trend);
    return _HoverGlow(
      glowColor: trendStyle.color.withValues(alpha: 0.28),
      borderRadius: 34,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(34),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: softCardDecoration(AppColors.pastelGrey, radius: 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF3A3A3A),
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    Icon(trendStyle.icon, size: 18, color: trendStyle.color),
                  ],
                ),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: _MiniSparkline(
                    points: points,
                    color: trendStyle.color,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trendStyle.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: trendStyle.color,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF7B7F87),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _TrendMeta _trendMeta(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('increase') || value.contains('up')) {
      return const _TrendMeta(
        icon: Icons.arrow_upward_rounded,
        label: 'Increasing',
        color: Color(0xFFBC6C25),
      );
    }
    if (value.contains('decrease') || value.contains('down')) {
      return const _TrendMeta(
        icon: Icons.arrow_downward_rounded,
        label: 'Decreasing',
        color: Color(0xFF4A7C59),
      );
    }
    if (value.contains('stable')) {
      return const _TrendMeta(
        icon: Icons.horizontal_rule_rounded,
        label: 'Stable',
        color: Color(0xFF51606E),
      );
    }
    return const _TrendMeta(
      icon: Icons.more_horiz_rounded,
      label: 'Collecting',
      color: Color(0xFF808A95),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.latest});

  final VitalReading? latest;

  @override
  Widget build(BuildContext context) {
    final summary = latest?.stateSummary?.trim();
    final subtitle = summary == null || summary.isEmpty
        ? 'Collecting enough readings to analyze your state.'
        : summary;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 168, maxHeight: 176),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: softCardDecoration(
        const Color(0xFFF7F7F5),
        radius: 36,
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Image.asset('assets/circles.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Results',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Color(0xFF20243A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF444444),
                    fontSize: 12.6,
                    height: 1.22,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ResultsChip(
                      text: _patientStateChipText(latest?.patientState),
                      color: const Color(0xFFFFE57A),
                    ),
                    _ResultsChip(
                      text: _rrStatusChipText(latest?.rrStatus),
                      color: const Color(0xFFC8F3FA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _patientStateChipText(String? state) {
    final normalized = state?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return 'Collecting';
    if (normalized.contains('low oxygen')) return 'Low Oxygen';
    if (normalized.contains('unstable')) return 'Unstable';
    if (normalized.contains('elevated')) return 'Elevated HR';
    if (normalized.contains('stable')) return 'Stable';
    return state!.trim();
  }

  static String _rrStatusChipText(String? status) {
    final normalized = status?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty || normalized == 'unknown') {
      return 'RR Unknown';
    }
    if (normalized.contains('short_rr_interval')) return 'Short RR';
    if (normalized.contains('long_rr_interval')) return 'Long RR';
    if (normalized.contains('normal')) return 'Normal RR';
    return 'RR Unknown';
  }
}

class _ResultsChip extends StatelessWidget {
  const _ResultsChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.text,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              height: 1,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceBatteryCard extends StatelessWidget {
  const _DeviceBatteryCard({
    required this.batteryPercentage,
    required this.isDeviceConnected,
  });

  final int batteryPercentage;
  final bool isDeviceConnected;

  @override
  Widget build(BuildContext context) {
    final percentage = batteryPercentage.clamp(0, 100).toInt();
    final isLowBattery = isDeviceConnected && percentage < 20;
    final fillColor = _fillColor(percentage);
    final cardColor = isDeviceConnected
        ? const Color(0xFFF7F7F5)
        : const Color(0xFFF2F3F5);
    final statusText = isDeviceConnected ? 'Connected' : 'Device Offline';
    final statusColor = isDeviceConnected
        ? const Color(0xFF51606E)
        : const Color(0xFF7A8591);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Device Battery',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                  letterSpacing: -0.7,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDeviceConnected
                      ? Colors.white
                      : const Color(0xFFE7EAEE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDeviceConnected ? fillColor : statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 54,
                    letterSpacing: -2.6,
                    height: 0.96,
                    color: isDeviceConnected ? AppColors.text : statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isDeviceConnected
                      ? (isLowBattery
                            ? 'Low Battery'
                            : 'Battery level is stable')
                      : 'Device Offline',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: !isDeviceConnected
                        ? statusColor
                        : isLowBattery
                        ? const Color(0xFFBC4C2A)
                        : const Color(0xFF66707C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BatteryBar(
                  percentage: percentage / 100,
                  color: isDeviceConnected ? fillColor : statusColor,
                  isOffline: !isDeviceConnected,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isDeviceConnected
                    ? Icons.battery_6_bar_rounded
                    : Icons.portable_wifi_off_rounded,
                color: isDeviceConnected ? fillColor : statusColor,
                size: 24,
              ),
            ],
          ),
          if (isLowBattery) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFBC4C2A),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Low Battery',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFBC4C2A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _fillColor(int percentage) {
    if (percentage < 20) return const Color(0xFFC84535);
    if (percentage <= 50) return const Color(0xFFCC7A22);
    return const Color(0xFF2F9E5B);
  }
}

class _BatteryBar extends StatelessWidget {
  const _BatteryBar({
    required this.percentage,
    required this.color,
    required this.isOffline,
  });

  final double percentage;
  final Color color;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 24,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E5E8)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: isOffline
                      ? 0.0
                      : percentage.clamp(0.06, 1.0).toDouble(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.76), color],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 6,
          height: 12,
          decoration: BoxDecoration(
            color: isOffline ? const Color(0xFFCDD3D8) : color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _LatestReadingStrip extends StatelessWidget {
  const _LatestReadingStrip({required this.latest});

  final VitalReading? latest;

  @override
  Widget build(BuildContext context) {
    final items = <_ReadingItem>[
      _ReadingItem(
        'HR',
        latest == null ? '-- bpm' : '${latest!.heartRateText} bpm',
      ),
      _ReadingItem('SpO2', latest == null ? '--%' : '${latest!.spo2Text}%'),
      _ReadingItem(
        'Time',
        latest == null
            ? '--:--'
            : DateFormat('hh:mm a').format(latest!.createdAt.toLocal()),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.labelLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.selectedTab, required this.onSelect});

  final ShellTab selectedTab;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return _HoverGlow(
      glowColor: AppColors.glowDark,
      borderRadius: 36,
      child: Container(
        width: 270,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavCircle(
              icon: Icons.home_rounded,
              selected: selectedTab == ShellTab.home,
              onTap: () => onSelect(ShellTab.home),
            ),
            _NavCircle(
              icon: Icons.favorite_rounded,
              selected: selectedTab == ShellTab.live,
              onTap: () => onSelect(ShellTab.live),
            ),
            _NavCircle(
              icon: Icons.insert_chart_outlined_rounded,
              selected: selectedTab == ShellTab.history,
              onTap: () => onSelect(ShellTab.history),
            ),
            _NavCircle(
              icon: Icons.notifications_none_rounded,
              selected: selectedTab == ShellTab.alerts,
              onTap: () => onSelect(ShellTab.alerts),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCircle extends StatelessWidget {
  const _NavCircle({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverGlow(
      glowColor: selected ? AppColors.glowYellow : AppColors.glowDark,
      borderRadius: 999,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: selected ? AppColors.navSelected : AppColors.navUnselected,
            shape: BoxShape.circle,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x22FFD84D),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: selected ? AppColors.background : const Color(0xFF303030),
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.points, required this.color});

  final List<FlSpot> points;
  final Color color;

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
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.85), color],
            ),
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.16),
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

class _ConfigurationMessage extends StatelessWidget {
  const _ConfigurationMessage({
    this.text = VitalsRepository.configError,
    this.isError = false,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: softCardDecoration(
          isError ? AppColors.pastelRed : AppColors.pastelGreen,
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
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _HoverGlow(
      glowColor: AppColors.glowYellow,
      borderRadius: 999,
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 24, color: const Color(0xFF2A2A2A)),
      ),
    );
  }
}

class _HoverGlow extends StatefulWidget {
  const _HoverGlow({
    required this.child,
    required this.glowColor,
    required this.borderRadius,
  });

  final Widget child;
  final Color glowColor;
  final double borderRadius;

  @override
  State<_HoverGlow> createState() => _HoverGlowState();
}

class _HoverGlowState extends State<_HoverGlow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: widget.glowColor,
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

extension on BoxDecoration {
  BoxDecoration copyWith({
    Color? color,
    DecorationImage? image,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    BoxShape? shape,
    Gradient? gradient,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? this.color,
      image: image ?? this.image,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      shape: shape ?? this.shape,
      gradient: gradient ?? this.gradient,
      boxShadow: boxShadow ?? this.boxShadow,
    );
  }
}

class _TrendMeta {
  const _TrendMeta({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

class _ReadingItem {
  const _ReadingItem(this.label, this.value);

  final String label;
  final String value;
}
