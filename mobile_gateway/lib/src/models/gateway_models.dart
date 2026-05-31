import 'dart:convert';
import 'dart:math';

class SensorPayload {
  const SensorPayload({
    required this.deviceId,
    required this.seq,
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    required this.rmssd,
    required this.sdrr,
    required this.pnn50,
    this.source = 'unknown',
    this.rawPayload,
    this.signature,
  });

  final String deviceId;
  final int seq;
  final int timestamp;
  final double heartRate;
  final double spo2;
  final double rmssd;
  final double sdrr;
  final double pnn50;
  final String source;
  final Map<String, dynamic>? rawPayload;
  final String? signature;

  factory SensorPayload.fromJson(Map<String, dynamic> json) {
    final rrIntervals = _asNumList(json['rr_intervals']);
    final hasDerivedMetrics =
        json['rmssd'] != null && json['sdrr'] != null && json['pnn50'] != null;

    if (!hasDerivedMetrics && rrIntervals == null) {
      throw const FormatException(
        'Payload must include rmssd, sdrr, pnn50 or rr_intervals.',
      );
    }

    final metrics = hasDerivedMetrics
        ? (
            rmssd: _asDouble(json['rmssd'], 'rmssd'),
            sdrr: _asDouble(json['sdrr'], 'sdrr'),
            pnn50: _asDouble(json['pnn50'], 'pnn50'),
          )
        : _deriveHrv(rrIntervals!);

    return SensorPayload(
      deviceId: _asString(json['device_id'], 'device_id'),
      seq: _asInt(json['seq'], 'seq'),
      timestamp: _normalizeTimestamp(_asInt(json['timestamp'], 'timestamp')),
      heartRate: _asDouble(json['heart_rate'], 'heart_rate'),
      spo2: _asDouble(json['spo2'], 'spo2'),
      rmssd: metrics.rmssd,
      sdrr: metrics.sdrr,
      pnn50: metrics.pnn50,
      source: json['source']?.toString() ?? 'unknown',
      rawPayload: json['raw_payload'] is Map<String, dynamic>
          ? json['raw_payload'] as Map<String, dynamic>
          : null,
      signature: json['signature']?.toString(),
    );
  }

  factory SensorPayload.fromEsp32Payload(
    Map<String, dynamic> json, {
    required String deviceId,
    required int seq,
    required int timestamp,
    required String source,
  }) {
    return SensorPayload(
      deviceId: deviceId,
      seq: seq,
      timestamp: _normalizeTimestamp(timestamp),
      heartRate: _asDouble(json['bpm'], 'bpm'),
      spo2: _asDouble(json['spo2'], 'spo2'),
      rmssd: _asDouble(json['rmssd'], 'rmssd'),
      sdrr: _asDouble(json['sdrr'], 'sdrr'),
      pnn50: _asDouble(json['pnn50'], 'pnn50'),
      source: source,
      rawPayload: Map<String, dynamic>.from(json),
    );
  }

  factory SensorPayload.fromQueueJson(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Queued payload is not a JSON object.');
    }
    return SensorPayload.fromJson(decoded);
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'seq': seq,
      'timestamp': timestamp,
      'heart_rate': heartRate,
      'spo2': spo2,
      'rmssd': rmssd,
      'sdrr': sdrr,
      'pnn50': pnn50,
      'source': source,
      if (rawPayload != null) 'raw_payload': rawPayload,
      if (signature != null && signature!.isNotEmpty) 'signature': signature,
    };
  }

  Map<String, dynamic> toPredictJson() {
    return {
      'rmssd': rmssd,
      'sdrr': sdrr,
      'pnn50': pnn50,
      'heart_rate': heartRate,
      'spo2': spo2,
    };
  }

  String get encoded => jsonEncode(toJson());

  String? validateMetrics() {
    if (heartRate < 30 || heartRate > 220) {
      return 'heart_rate must be between 30 and 220.';
    }
    if (spo2 < 70 || spo2 > 100) {
      return 'spo2 must be between 70 and 100.';
    }
    if (rmssd <= 0) return 'rmssd must be greater than 0.';
    if (sdrr <= 0) return 'sdrr must be greater than 0.';
    if (pnn50 < 0) return 'pnn50 must be greater than or equal to 0.';
    return null;
  }

  String? validatePredictReady() {
    if (pnn50 <= 0) {
      return 'pNN50 bernilai 0, belum bisa dikirim ke backend ML.';
    }
    return null;
  }

  static int _normalizeTimestamp(int value) {
    if (value > 9999999999) {
      return value ~/ 1000;
    }
    return value;
  }

  static ({double rmssd, double sdrr, double pnn50}) _deriveHrv(
    List<double> rrIntervals,
  ) {
    if (rrIntervals.length < 2) {
      throw const FormatException(
        'rr_intervals must contain at least 2 values.',
      );
    }

    final diffs = <double>[];
    for (var i = 1; i < rrIntervals.length; i++) {
      diffs.add(rrIntervals[i] - rrIntervals[i - 1]);
    }

    final rmssd = sqrt(
      diffs.map((diff) => diff * diff).reduce((a, b) => a + b) / diffs.length,
    );
    final mean =
        rrIntervals.reduce((a, b) => a + b) / rrIntervals.length.toDouble();
    final variance =
        rrIntervals
            .map((rr) => pow(rr - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        max(1, rrIntervals.length - 1);
    final pnn50 =
        diffs.where((diff) => diff.abs() > 50).length / diffs.length * 100;

    return (rmssd: rmssd, sdrr: sqrt(variance), pnn50: pnn50);
  }

  static String _asString(dynamic value, String field) {
    if (value == null || value.toString().trim().isEmpty) {
      throw FormatException('$field is required.');
    }
    return value.toString();
  }

  static int _asInt(dynamic value, String field) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (number == null) throw FormatException('$field must be a number.');
    return number.toInt();
  }

  static double _asDouble(dynamic value, String field) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (number == null) throw FormatException('$field must be a number.');
    return number.toDouble();
  }

  static List<double>? _asNumList(dynamic value) {
    if (value == null) return null;
    if (value is! List) {
      throw const FormatException('rr_intervals must be a list.');
    }
    return value
        .map((item) => _asDouble(item, 'rr_intervals item'))
        .toList(growable: false);
  }
}

class QueueItem {
  const QueueItem({
    required this.localId,
    required this.deviceId,
    required this.seq,
    required this.timestamp,
    required this.payloadJson,
    required this.status,
    required this.retryCount,
    this.lastError,
    this.predictedCluster,
    this.label,
    required this.createdAt,
    this.syncedAt,
  });

  final int localId;
  final String deviceId;
  final int seq;
  final int timestamp;
  final String payloadJson;
  final String status;
  final int retryCount;
  final String? lastError;
  final int? predictedCluster;
  final String? label;
  final DateTime createdAt;
  final DateTime? syncedAt;

  factory QueueItem.fromMap(Map<String, Object?> map) {
    return QueueItem(
      localId: map['local_id'] as int,
      deviceId: map['device_id'] as String,
      seq: map['seq'] as int,
      timestamp: map['timestamp'] as int,
      payloadJson: map['payload_json'] as String,
      status: map['status'] as String,
      retryCount: map['retry_count'] as int,
      lastError: map['last_error'] as String?,
      predictedCluster: map['predicted_cluster'] as int?,
      label: map['label'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] == null
          ? null
          : DateTime.parse(map['synced_at'] as String),
    );
  }
}

class HistoryRecord {
  const HistoryRecord({
    required this.heartRate,
    required this.spo2,
    required this.rmssd,
    required this.sdrr,
    required this.pnn50,
    required this.predictedCluster,
    required this.label,
    required this.createdAt,
  });

  final double heartRate;
  final double spo2;
  final double rmssd;
  final double sdrr;
  final double pnn50;
  final int? predictedCluster;
  final String? label;
  final DateTime createdAt;

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      heartRate: _num(json['heart_rate']),
      spo2: _num(json['spo2']),
      rmssd: _num(json['rmssd']),
      sdrr: _num(json['sdrr']),
      pnn50: _num(json['pnn50']),
      predictedCluster:
          (json['predicted_cluster'] ?? json['predict_cluster']) as int?,
      label: json['label']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  static double _num(dynamic value) {
    return value is num ? value.toDouble() : double.parse(value.toString());
  }
}

class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.severity,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String message;
  final String severity;
  final DateTime createdAt;

  factory SecurityEvent.fromMap(Map<String, Object?> map) {
    return SecurityEvent(
      id: map['id'] as int,
      type: map['type'] as String,
      message: map['message'] as String,
      severity: map['severity'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
