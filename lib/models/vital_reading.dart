class VitalReading {
  VitalReading({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.hrDiff,
    required this.rrInterval,
    required this.actualHrScaled,
    required this.predictedHrScaled,
    required this.error,
    required this.threshold,
    required this.status,
    required this.isAnomaly,
    required this.anomalyReason,
    required this.anomalyMessage,
    required this.alertTriggered,
    required this.createdAt,
  });

  final double? heartRate;
  final double? spo2;
  final double? temperature;
  final double? hrDiff;
  final double? rrInterval;
  final double? actualHrScaled;
  final double? predictedHrScaled;
  final double? error;
  final double? threshold;
  final String? status;
  final bool isAnomaly;
  final String? anomalyReason;
  final String? anomalyMessage;
  final bool alertTriggered;
  final DateTime createdAt;

  factory VitalReading.fromMap(Map<String, dynamic> map) {
    return VitalReading(
      heartRate: _asDouble(map['heart_rate']),
      spo2: _asDouble(map['spo2']),
      temperature: _asDouble(map['temperature']),
      hrDiff: _asDouble(map['hr_diff']),
      rrInterval: _asDouble(map['rr_interval']),
      actualHrScaled: _asDouble(map['actual_hr_scaled']),
      predictedHrScaled: _asDouble(map['predicted_hr_scaled']),
      error: _asDouble(map['error']),
      threshold: _asDouble(map['threshold']),
      status: map['status']?.toString(),
      isAnomaly: map['is_anomaly'] == true,
      anomalyReason: map['anomaly_reason']?.toString(),
      anomalyMessage: map['anomaly_message']?.toString(),
      alertTriggered: map['alert_triggered'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  String get heartRateText =>
      heartRate == null ? '--' : heartRate!.toStringAsFixed(0);
  String get spo2Text => spo2 == null ? '--' : spo2!.toStringAsFixed(0);
  String get rrText => rrInterval == null ? '--' : rrInterval!.toStringAsFixed(0);

  String get statusText {
    if (status == null || status!.trim().isEmpty) return 'collecting';
    return status!.trim().toLowerCase();
  }

  bool get isSpo2RelatedAnomaly {
    final reason = anomalyReason?.toLowerCase() ?? '';
    return reason.contains('spo2') || reason.contains('heart_rate_and_spo2');
  }

  bool get isHeartRateRelatedAnomaly {
    final reason = anomalyReason?.toLowerCase() ?? '';
    return reason.contains('heart_rate') || reason.contains('heart_rate_and_spo2');
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
