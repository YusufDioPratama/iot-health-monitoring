import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/gateway_models.dart';
import 'local_database.dart';
import 'secure_store.dart';

class SecurityManager {
  SecurityManager({
    required SecureStore secureStore,
    required LocalDatabase database,
  }) : _secureStore = secureStore,
       _database = database;

  final SecureStore _secureStore;
  final LocalDatabase _database;

  Future<SecurityResult> validate({
    required SensorPayload payload,
    required String activeDevice,
  }) async {
    if (payload.deviceId != activeDevice) {
      await _database.logSecurity(
        'unknown device',
        'Payload device ${payload.deviceId} does not match active device $activeDevice.',
      );
      return const SecurityResult.rejected('Unknown device.');
    }

    final lastSeq = await _secureStore.lastSeq(activeDevice);
    if (payload.seq <= lastSeq) {
      await _database.logSecurity(
        'replay detected',
        'Replay detected for $activeDevice. seq=${payload.seq}, last=$lastSeq.',
      );
      return const SecurityResult.rejected('Replay detected.');
    }

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if ((nowSeconds - payload.timestamp).abs() > 600) {
      await _database.logSecurity(
        'invalid timestamp',
        'Timestamp ${payload.timestamp} is outside the 10 minute acceptance window.',
      );
      return const SecurityResult.rejected('Invalid timestamp.');
    }

    final secret = await _secureStore.deviceSecret();
    if (secret == null || secret.isEmpty) {
      await _database.logSecurity(
        'Unsigned development payload',
        'Unsigned development payload',
      );
    } else if (!_hasValidSignature(payload, secret)) {
      await _database.logSecurity(
        'invalid signature',
        'HMAC signature mismatch for $activeDevice seq=${payload.seq}.',
      );
      return const SecurityResult.rejected('Invalid signature.');
    }

    await _secureStore.saveLastSeq(activeDevice, payload.seq);
    return const SecurityResult.accepted();
  }

  Future<int> nextSeq(String activeDevice) async {
    return (await _secureStore.lastSeq(activeDevice)) + 1;
  }

  bool _hasValidSignature(SensorPayload payload, String secret) {
    final signature = payload.signature;
    if (signature == null || signature.isEmpty) return false;

    final canonical = SplayTreeMap<String, dynamic>.from(payload.toJson())
      ..remove('signature');
    final digest = Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(jsonEncode(canonical))).toString();
    return digest.toLowerCase() == signature.toLowerCase();
  }
}

class SecurityResult {
  const SecurityResult._(this.accepted, this.message);
  const SecurityResult.accepted() : this._(true, null);
  const SecurityResult.rejected(String message) : this._(false, message);

  final bool accepted;
  final String? message;
}
