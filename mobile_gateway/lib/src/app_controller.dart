import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config/app_config.dart';
import 'models/gateway_models.dart';
import 'services/gateway_api.dart';
import 'services/local_database.dart';
import 'services/secure_store.dart';
import 'services/security_manager.dart';

class AppController extends ChangeNotifier {
  AppController() : secureStore = SecureStore(), database = LocalDatabase() {
    securityManager = SecurityManager(
      secureStore: secureStore,
      database: database,
    );
    api = GatewayApi(secureStore: secureStore, database: database);
  }

  final SecureStore secureStore;
  final LocalDatabase database;
  late final SecurityManager securityManager;
  late final GatewayApi api;

  bool initialized = false;
  bool isLoggedIn = false;
  bool backendOnline = false;
  bool internetAvailable = false;
  bool scanning = false;
  bool bleConnected = false;
  bool useMockSensor = false;
  bool syncing = false;

  String backendBaseUrl = AppConfig.defaultBackendBaseUrl;
  String deviceName = AppConfig.defaultDeviceName;
  String username = '';
  String deviceSecret = '';
  String legacyApiKey = '';
  String bleStatus = 'Belum terhubung';
  String backendStatus = 'Belum dicek';
  String deviceInfo = '-';
  String connectedBleDeviceName = AppConfig.defaultBleDeviceName;
  String lastBlePayloadText = '-';
  String? lastError;

  int pendingCount = 0;
  int? batteryPercent;
  int? predictionCluster;
  String? predictionLabel;
  DateTime? lastPacketAt;
  DateTime? lastSyncAt;
  SensorPayload? lastPayload;

  List<ScanResult> scanResults = [];
  List<QueueItem> queueItems = [];
  List<SecurityEvent> securityEvents = [];
  List<HistoryRecord> historyRecords = [];

  Timer? _mockTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  BluetoothDevice? _connectedDevice;
  final _random = Random();
  int _mockSeq = 0;

  Future<void> init() async {
    backendBaseUrl = await secureStore.backendBaseUrl();
    deviceName = await secureStore.deviceName();
    username = await secureStore.username() ?? '';
    deviceSecret = await secureStore.deviceSecret() ?? '';
    legacyApiKey = await secureStore.legacyApiKey();
    useMockSensor = await secureStore.mockMode();
    isLoggedIn = (await secureStore.accessToken()) != null;
    _mockSeq = max(1, await securityManager.nextSeq(deviceName));
    api.configure(backendBaseUrl);

    await _refreshLocalState();
    await _refreshBattery();
    await _loadDeviceInfo();
    await _refreshConnectivity(await Connectivity().checkConnectivity());
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _refreshConnectivity(results);
    });

    if (useMockSensor) {
      _startMockTimer();
    }
    if (isLoggedIn) {
      unawaited(checkBackend());
      unawaited(syncNow());
      unawaited(refreshHistory());
    }

    initialized = true;
    notifyListeners();
  }

  Future<void> login({
    required String baseUrl,
    required String loginUsername,
    required String password,
    required String loginDeviceName,
  }) async {
    lastError = null;
    backendBaseUrl = baseUrl.trim();
    deviceName = loginDeviceName.trim().isEmpty
        ? AppConfig.defaultDeviceName
        : loginDeviceName.trim();
    api.configure(backendBaseUrl);
    notifyListeners();

    try {
      final data = await api.login(
        baseUrl: backendBaseUrl,
        username: loginUsername.trim(),
        password: password,
      );
      final access = data['access']?.toString();
      final refresh = data['refresh']?.toString();
      if (access == null || refresh == null) {
        throw StateError('Login response did not include JWT tokens.');
      }

      username = data['username']?.toString() ?? loginUsername.trim();
      await secureStore.saveSession(
        access: access,
        refresh: refresh,
        username: username,
        deviceName: deviceName,
        baseUrl: backendBaseUrl,
      );
      await api.setActiveUser(deviceName);

      final warning = data['warning']?.toString();
      if (warning != null && warning.isNotEmpty) {
        lastError = warning;
      }

      isLoggedIn = true;
      backendOnline = true;
      backendStatus = GatewayApi.backendLegacyModeMessage;
      _mockSeq = max(1, await securityManager.nextSeq(deviceName));
      await _refreshLocalState();
      await syncNow();
      await refreshHistory();
    } catch (error) {
      lastError = GatewayApi.readableError(error);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await secureStore.clearSession();
    await stopMockMode();
    await disconnectBle();
    isLoggedIn = false;
    backendOnline = false;
    backendStatus = 'Logout';
    username = '';
    predictionCluster = null;
    predictionLabel = null;
    notifyListeners();
  }

  Future<void> saveSettings({
    required String baseUrl,
    required String activeDeviceName,
    required String secret,
    required String legacyKey,
  }) async {
    backendBaseUrl = baseUrl.trim();
    deviceName = activeDeviceName.trim().isEmpty
        ? AppConfig.defaultDeviceName
        : activeDeviceName.trim();
    deviceSecret = secret.trim();
    legacyApiKey = legacyKey.trim();
    await secureStore.saveBaseUrl(backendBaseUrl);
    await secureStore.saveDeviceName(deviceName);
    await secureStore.saveDeviceSecret(deviceSecret);
    await secureStore.saveLegacyApiKey(legacyApiKey);
    api.configure(backendBaseUrl);
    _mockSeq = max(1, await securityManager.nextSeq(deviceName));
    await checkBackend();
    notifyListeners();
  }

  Future<void> setMockSensor(bool enabled) async {
    useMockSensor = enabled;
    await secureStore.saveMockMode(enabled);
    if (enabled) {
      _startMockTimer();
    } else {
      await stopMockMode();
    }
    notifyListeners();
  }

  Future<void> stopMockMode() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    useMockSensor = false;
    await secureStore.saveMockMode(false);
  }

  Future<void> checkBackend() async {
    if (!isLoggedIn) return;
    try {
      await api.setActiveUser(deviceName);
      backendOnline = true;
      backendStatus = GatewayApi.backendLegacyModeMessage;
    } catch (error) {
      backendOnline = false;
      backendStatus = GatewayApi.readableError(error);
      lastError = backendStatus;
    }
    notifyListeners();
  }

  Future<void> handleBleBytes(List<int> value) async {
    try {
      final text = utf8.decode(value).trim();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('BLE notification is not a JSON object.');
      }
      lastBlePayloadText = text;
      await processEsp32Payload(decoded, source: 'ble');
    } catch (error) {
      await database.logSecurity('invalid JSON', error.toString());
      lastError = 'Invalid JSON from BLE: $error';
      await _refreshLocalState();
      notifyListeners();
    }
  }

  Future<void> processEsp32Payload(
    Map<String, dynamic> payload, {
    required String source,
  }) async {
    final sensorPayload = SensorPayload.fromEsp32Payload(
      payload,
      deviceId: deviceName,
      seq: _mockSeq++,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      source: source,
    );
    await processIncomingPayload(sensorPayload);
  }

  Future<void> processIncomingPayload(SensorPayload payload) async {
    final metricError = payload.validateMetrics();
    if (metricError != null) {
      lastError = metricError;
      await database.logSecurity('invalid payload', metricError);
      await _refreshLocalState();
      notifyListeners();
      return;
    }

    final security = await securityManager.validate(
      payload: payload,
      activeDevice: deviceName,
    );
    if (!security.accepted) {
      lastError = security.message;
      await _refreshLocalState();
      notifyListeners();
      return;
    }

    final predictError = payload.validatePredictReady();
    await database.insertQueue(
      payload,
      status: predictError == null ? 'pending' : 'invalid_for_sync',
      lastError: predictError,
    );
    lastPayload = payload;
    lastPacketAt = DateTime.now();
    lastError = predictError;
    await _refreshLocalState();
    notifyListeners();

    if (predictError == null && internetAvailable && isLoggedIn) {
      await syncNow();
    }
  }

  Future<void> syncNow() async {
    if (syncing || !isLoggedIn || !internetAvailable) {
      return;
    }

    final items = await database.pendingForSync();
    if (items.isEmpty) {
      await _refreshLocalState();
      return;
    }

    syncing = true;
    lastError = null;
    notifyListeners();

    await database.markSyncing(items.map((item) => item.localId));
    try {
      await _syncOneByOne(items);
    } catch (error) {
      final message = GatewayApi.readableError(error);
      for (final item in items) {
        await database.markFailed(item.localId, message);
      }
      await database.logSecurity('backend rejected payload', message);
      lastError = message;
    } finally {
      syncing = false;
      await _refreshLocalState();
      notifyListeners();
    }
  }

  Future<void> refreshHistory() async {
    try {
      historyRecords = await database.localSyncedHistory(limit: 50);
      lastError = null;
    } catch (error) {
      lastError = error.toString();
    }
    notifyListeners();
  }

  Future<void> startBleScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();

    scanResults = [];
    scanning = true;
    lastError = null;
    notifyListeners();

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) {
        scanResults = _sortScanResults(results);
        notifyListeners();
      },
      onError: (Object error) {
        lastError = 'BLE scan failed: $error';
        scanning = false;
        notifyListeners();
      },
    );

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidUsesFineLocation: true,
      );
      Future<void>.delayed(const Duration(seconds: 8), () {
        scanning = false;
        notifyListeners();
      });
    } catch (error) {
      scanning = false;
      lastError = 'BLE scan failed: $error';
      notifyListeners();
    }
  }

  Future<void> connectToDevice(ScanResult result) async {
    final device = result.device;
    await disconnectBle();
    bleStatus = 'Menghubungkan ${_deviceLabel(result)}';
    notifyListeners();

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
      );
      _connectedDevice = device;
      connectedBleDeviceName = _deviceLabel(result);
      _connectionSub = device.connectionState.listen((state) async {
        bleConnected = state == BluetoothConnectionState.connected;
        bleStatus = bleConnected ? 'Terhubung' : 'Terputus';
        if (!bleConnected) {
          await database.logSecurity(
            'BLE disconnected',
            'BLE device ${device.remoteId} disconnected.',
          );
          await _refreshLocalState();
        }
        notifyListeners();
      });

      final services = await device.discoverServices();
      final notifyCharacteristic = services
          .where(
            (service) => service.serviceUuid == Guid(BleUuidConfig.serviceUuid),
          )
          .expand((service) => service.characteristics)
          .where(
            (characteristic) =>
                characteristic.characteristicUuid ==
                Guid(BleUuidConfig.sensorNotifyCharacteristicUuid),
          )
          .cast<BluetoothCharacteristic?>()
          .firstWhere(
            (characteristic) => characteristic != null,
            orElse: () => null,
          );

      if (notifyCharacteristic == null) {
        throw StateError('Sensor notify characteristic not found.');
      }

      await _notifySub?.cancel();
      _notifySub = notifyCharacteristic.onValueReceived.listen(handleBleBytes);
      await notifyCharacteristic.setNotifyValue(true);
      bleConnected = true;
      bleStatus = 'Terhubung dan menerima notifikasi';
    } catch (error) {
      bleConnected = false;
      bleStatus = 'Gagal terhubung';
      lastError = 'BLE connect failed: $error';
      await database.logSecurity('BLE disconnected', lastError!);
    } finally {
      await _refreshLocalState();
      notifyListeners();
    }
  }

  Future<void> disconnectBle() async {
    await _notifySub?.cancel();
    await _connectionSub?.cancel();
    _notifySub = null;
    _connectionSub = null;
    final device = _connectedDevice;
    _connectedDevice = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    bleConnected = false;
    bleStatus = 'Belum terhubung';
    notifyListeners();
  }

  String scanResultTitle(ScanResult result) => _deviceLabel(result);

  Future<void> _syncOneByOne(List<QueueItem> items) async {
    for (final item in items) {
      try {
        final payload = SensorPayload.fromQueueJson(item.payloadJson);
        final predictError = payload.validatePredictReady();
        if (predictError != null) {
          await database.markInvalidForSync(item.localId, predictError);
          lastError = predictError;
          continue;
        }
        final response = await api.predict(payload);
        predictionCluster = response['predicted_cluster'] as int?;
        predictionLabel = response['label']?.toString();
        await database.markSynced(
          item.localId,
          predictedCluster: predictionCluster,
          label: predictionLabel,
        );
        lastSyncAt = DateTime.now();
        backendOnline = true;
        backendStatus = 'Sync /api/predict/ berhasil';
      } catch (error) {
        final message = GatewayApi.readableError(error);
        await database.markFailed(item.localId, message);
        await database.logSecurity('backend rejected payload', message);
        lastError = message;
        backendOnline = false;
        backendStatus = message;
      }
    }
    await refreshHistory();
  }

  void _startMockTimer() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_emitMockPayload());
    });
    unawaited(_emitMockPayload());
  }

  Future<void> _emitMockPayload() async {
    final payload = {
      'bpm': 72 + _random.nextInt(22),
      'spo2': min(100, 95 + _random.nextInt(4)),
      'rmssd': double.parse(
        (32 + _random.nextInt(24) + _random.nextDouble()).toStringAsFixed(2),
      ),
      'sdrr': double.parse(
        (42 + _random.nextInt(28) + _random.nextDouble()).toStringAsFixed(2),
      ),
      'pnn50': 12 + _random.nextInt(18),
    };
    lastBlePayloadText = jsonEncode(payload);
    await processEsp32Payload(payload, source: 'mock');
  }

  Future<void> _refreshLocalState() async {
    pendingCount = await database.pendingCount();
    queueItems = await database.queueItems();
    securityEvents = await database.securityEvents();
  }

  Future<void> _refreshConnectivity(List<ConnectivityResult> results) async {
    internetAvailable = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (internetAvailable && isLoggedIn) {
      unawaited(syncNow());
    }
    notifyListeners();
  }

  Future<void> _refreshBattery() async {
    try {
      batteryPercent = await Battery().batteryLevel;
    } catch (_) {
      batteryPercent = null;
    }
  }

  Future<void> _loadDeviceInfo() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await DeviceInfoPlugin().androidInfo;
        deviceInfo =
            '${info.manufacturer} ${info.model} (SDK ${info.version.sdkInt})';
      } else {
        deviceInfo = defaultTargetPlatform.name;
      }
    } catch (_) {
      deviceInfo = '-';
    }
  }

  String _deviceLabel(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.device.advName;
    return name.isEmpty ? result.device.remoteId.str : name;
  }

  bool isTargetBleDevice(ScanResult result) {
    return _deviceLabel(result) == AppConfig.defaultBleDeviceName;
  }

  String scanResultSubtitle(ScanResult result) {
    final prefix = isTargetBleDevice(result) ? 'Target ESPP | ' : '';
    return '$prefix${result.device.remoteId.str}';
  }

  List<ScanResult> _sortScanResults(List<ScanResult> results) {
    final sorted = [...results];
    sorted.sort((a, b) {
      final aTarget = isTargetBleDevice(a);
      final bTarget = isTargetBleDevice(b);
      if (aTarget != bTarget) return aTarget ? -1 : 1;
      return _deviceLabel(a).compareTo(_deviceLabel(b));
    });
    return sorted;
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    _connectivitySub?.cancel();
    _scanSub?.cancel();
    _notifySub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}
