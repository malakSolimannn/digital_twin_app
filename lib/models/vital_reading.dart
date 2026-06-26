class VitalReading {
  VitalReading({
    required this.heartRate,
    required this.spo2,
    required this.hrDiff,
    required this.rrInterval,
    required this.actualHrScaled,
    required this.predictedHrScaled,
    required this.error,
    required this.threshold,
    required this.status,
    required this.patientState,
    required this.hrTrend,
    required this.spo2Trend,
    required this.rrStatus,
    required this.stateSummary,
    required this.isAnomaly,
    required this.anomalyReason,
    required this.anomalyMessage,
    required this.alertTriggered,
    required this.createdAt,
    required this.batteryVoltage,
    required this.batteryPercentage,
    required this.lowBattery,
  });

  final double? heartRate;
  final double? spo2;
  final double? hrDiff;
  final double? rrInterval;
  final double? actualHrScaled;
  final double? predictedHrScaled;
  final double? error;
  final double? threshold;
  final String? status;
  final String? patientState;
  final String? hrTrend;
  final String? spo2Trend;
  final String? rrStatus;
  final String? stateSummary;
  final bool isAnomaly;
  final String? anomalyReason;
  final String? anomalyMessage;
  final bool alertTriggered;
  final double? batteryVoltage;
  final int? batteryPercentage;
  final bool lowBattery;
  final DateTime createdAt;

  factory VitalReading.fromMap(Map<String, dynamic> map) {
    return VitalReading(
      heartRate: _asDouble(map['heart_rate']),
      spo2: _asDouble(map['spo2']),
      hrDiff: _asDouble(map['hr_diff']),
      rrInterval: _asDouble(map['rr_interval']),
      actualHrScaled: _asDouble(map['actual_hr_scaled']),
      predictedHrScaled: _asDouble(map['predicted_hr_scaled']),
      error: _asDouble(map['error']),
      threshold: _asDouble(map['threshold']),
      status: map['status']?.toString(),
      patientState: map['patient_state']?.toString(),
      hrTrend: map['hr_trend']?.toString(),
      spo2Trend: map['spo2_trend']?.toString(),
      rrStatus: map['rr_status']?.toString(),
      stateSummary: map['state_summary']?.toString(),
      isAnomaly: map['is_anomaly'] == true,
      anomalyReason: map['anomaly_reason']?.toString(),
      anomalyMessage: map['anomaly_message']?.toString(),
      alertTriggered: map['alert_triggered'] == true,
      batteryVoltage: _asDouble(map['battery_voltage']),
      batteryPercentage: (map['battery_percentage'] as num?)?.toInt(),
      lowBattery: map['low_battery'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  String get heartRateText =>
      heartRate == null ? '--' : heartRate!.toStringAsFixed(0);

  String get spo2Text => spo2 == null ? '--' : spo2!.toStringAsFixed(0);

  String get rrText =>
      rrInterval == null ? '--' : rrInterval!.toStringAsFixed(0);

  String get statusText {
    if (status == null || status!.trim().isEmpty) return 'collecting';
    return status!.trim().toLowerCase();
  }

  String get patientStateText {
    final value = patientState?.trim();
    if (value == null || value.isEmpty) return 'Collecting Data';
    return value;
  }

  String get stateSummaryText {
    final value = stateSummary?.trim();
    if (value == null || value.isEmpty) {
      return 'Waiting for the latest digital twin interpretation.';
    }
    return value;
  }

  String get rrStatusText {
    final value = rrStatus?.trim();
    if (value == null || value.isEmpty) return 'Collecting RR pattern';
    return value;
  }

  String get hrTrendText {
    final value = hrTrend?.trim();
    if (value == null || value.isEmpty) return 'collecting';
    return value.toLowerCase();
  }

  String get spo2TrendText {
    final value = spo2Trend?.trim();
    if (value == null || value.isEmpty) return 'collecting';
    return value.toLowerCase();
  }

  bool get isSpo2RelatedAnomaly {
    final reason = anomalyReason?.toLowerCase() ?? '';
    return reason.contains('spo2') || reason.contains('heart_rate_and_spo2');
  }

  bool get isHeartRateRelatedAnomaly {
    final reason = anomalyReason?.toLowerCase() ?? '';
    return reason.contains('heart_rate') ||
        reason.contains('heart_rate_and_spo2');
  }

  bool get hasRuleBasedRisk =>
      (anomalyReason?.trim().toLowerCase() ?? '') == 'rule_based_risk';

  bool get isCriticalAlert {
    if (alertTriggered) return true;
    return _criticalMessageKeys.contains(_normalizedAnomalyMessage);
  }

  bool get isWarningOnly => !isCriticalAlert && isAnomaly;

  String get friendlyAnomalyMessage {
    final mappedMessage = _friendlyMessageMap[_normalizedAnomalyMessage];
    if (mappedMessage != null) return mappedMessage;

    final mappedReason = _friendlyMessageMap[_normalizedAnomalyReason];
    if (mappedReason != null) return mappedReason;

    if (hasRuleBasedRisk && isCriticalAlert) {
      return 'Critical vital-sign risk detected.';
    }
    if (hasRuleBasedRisk) {
      return 'A rule-based risk was detected.';
    }
    if (isHeartRateRelatedAnomaly && isSpo2RelatedAnomaly) {
      return 'Heart-rate and oxygen changes need attention.';
    }
    if (isHeartRateRelatedAnomaly) {
      return 'Heart-rate changes need attention.';
    }
    if (isSpo2RelatedAnomaly) {
      return 'Oxygen levels need attention.';
    }
    if (isAnomaly || alertTriggered) {
      return 'An abnormal reading was detected.';
    }
    return '';
  }

  String get friendlyPatientSummary {
    final anomalyText = friendlyAnomalyMessage;
    if (anomalyText.isNotEmpty) return anomalyText;

    final state = patientStateText.toLowerCase();
    if (state.contains('collecting')) {
      return 'Collecting enough data for the next interpretation.';
    }
    if (state.contains('stable')) {
      return 'Vitals look stable in the latest reading.';
    }
    if (state.contains('low oxygen')) {
      return 'Oxygen levels need closer monitoring.';
    }
    if (state.contains('critical')) {
      return 'A critical change was detected.';
    }
    if (state.contains('elevated')) {
      return 'Heart rate is above the usual range.';
    }
    if (stateSummaryText ==
        'Waiting for the latest digital twin interpretation.') {
      return 'Waiting for the next digital twin interpretation.';
    }
    return stateSummaryText;
  }

  String get _normalizedAnomalyReason =>
      anomalyReason?.trim().toLowerCase() ?? '';

  String get _normalizedAnomalyMessage =>
      anomalyMessage?.trim().toLowerCase() ?? '';

  static const Map<String, String> _friendlyMessageMap = {
    'dangerously_high_heart_rate': 'Heart rate is dangerously high.',
    'dangerously_low_heart_rate': 'Heart rate is dangerously low.',
    'low_spo2': 'Oxygen level is below normal.',
    'critical_low_spo2': 'Oxygen level is critically low.',
    'dangerous_gradual_hr_increase': 'Heart rate is rising steadily.',
    'dangerous_gradual_hr_decrease': 'Heart rate is dropping steadily.',
    'dangerous_gradual_spo2_drop': 'Oxygen level is gradually decreasing.',
    'heart_rate': 'AI detected an abnormal heart-rate pattern.',
    'spo2': 'Low oxygen level detected.',
    'heart_rate_and_spo2': 'Abnormal heart-rate pattern with low oxygen.',
  };

  static const Set<String> _criticalMessageKeys = {
    'dangerously_high_heart_rate',
    'dangerously_low_heart_rate',
    'critical_low_spo2',
  };

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
