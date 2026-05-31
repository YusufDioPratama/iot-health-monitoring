import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import 'src/app_controller.dart';
import 'src/config/app_config.dart' as config;
import 'src/models/gateway_models.dart';
import 'src/theme/app_theme.dart';
import 'src/widgets/dashboard_widgets.dart';

final appProvider = ChangeNotifierProvider<AppController>((ref) {
  final controller = AppController();
  controller.init();
  return controller;
});

void main() {
  runApp(const ProviderScope(child: GatewayApp()));
}

class GatewayApp extends ConsumerWidget {
  const GatewayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Health Gateway',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;

  final pages = const [
    StatusPage(),
    LivePage(),
    BlePage(),
    QueuePage(),
    HistoryPage(),
    SecurityPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (!app.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!app.isLoggedIn) {
      return const LoginPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Health Gateway'),
        actions: [
          IconButton(
            tooltip: 'Cek backend',
            onPressed: app.checkBackend,
            icon: Icon(app.backendOnline ? Icons.cloud_done : Icons.cloud_off),
          ),
          IconButton(
            tooltip: 'Sinkronkan',
            onPressed: app.syncNow,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Status',
          ),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Live'),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'BLE',
          ),
          NavigationDestination(icon: Icon(Icons.storage), label: 'Antrean'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.security), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Setelan'),
        ],
      ),
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController baseUrlController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;
  late final TextEditingController deviceController;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    baseUrlController = TextEditingController(text: app.backendBaseUrl);
    usernameController = TextEditingController(
      text: app.username.isNotEmpty
          ? app.username
          : config.AppConfig.debugTestingUsername,
    );
    passwordController = TextEditingController(
      text: config.AppConfig.debugTestingPassword,
    );
    deviceController = TextEditingController(text: app.deviceName);
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.monitor_heart,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 36,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'IoT Health Gateway',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Gateway BLE untuk monitoring data fisiologis ESP32.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: baseUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Backend URL',
                            prefixIcon: Icon(Icons.link),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: deviceController,
                          decoration: const InputDecoration(
                            labelText: 'Device backend',
                            prefixIcon: Icon(Icons.memory),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            helperText: 'Debug/testing only',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: _required,
                        ),
                        if (app.lastError != null) ...[
                          const SizedBox(height: 12),
                          ErrorBanner(message: app.lastError!),
                        ],
                        const SizedBox(height: 18),
                        PrimaryActionButton(
                          label: 'Masuk',
                          icon: Icons.login,
                          loading: loading,
                          onPressed: _login,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await ref
          .read(appProvider)
          .login(
            baseUrl: baseUrlController.text,
            loginUsername: usernameController.text,
            password: passwordController.text,
            loginDeviceName: deviceController.text,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login gagal')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class StatusPage extends ConsumerWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final queueStats = QueueStats.from(app.queueItems);
    return RefreshIndicator(
      onRefresh: () async {
        await app.checkBackend();
        await app.refreshHistory();
      },
      child: ListView(
        padding: pagePadding,
        children: [
          if (app.lastError != null) ...[
            ErrorBanner(message: app.lastError!),
            const SizedBox(height: 12),
          ],
          StatusHero(app: app, queueStats: queueStats),
          const SectionHeader(
            title: 'Status cepat',
            subtitle: 'Ringkasan koneksi dan sinkronisasi gateway.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ConnectionBadge(
                label: app.backendOnline ? 'Backend aktif' : 'Backend error',
                connected: app.backendOnline,
                icon: Icons.cloud_done,
              ),
              ConnectionBadge(
                label: app.bleConnected
                    ? 'BLE terhubung'
                    : 'BLE belum terhubung',
                connected: app.bleConnected,
                icon: Icons.bluetooth,
              ),
              SyncStatusBadge(
                label: '${app.pendingCount} pending',
                tone: app.pendingCount == 0
                    ? StatusTone.success
                    : StatusTone.warning,
                icon: Icons.storage,
              ),
              SyncStatusBadge(
                label: 'Sync ${formatDate(app.lastSyncAt)}',
                tone: app.lastSyncAt == null
                    ? StatusTone.info
                    : StatusTone.success,
                icon: Icons.sync,
              ),
            ],
          ),
          SectionHeader(
            title: 'Metrik sensor',
            subtitle: app.lastPayload == null
                ? 'Belum ada data sensor.'
                : 'Data terakhir dari ${sourceLabel(app.lastPayload?.source)}.',
          ),
          if (app.lastPayload == null)
            EmptyStateView(
              icon: Icons.sensors_off,
              title: 'Belum ada data sensor',
              message:
                  'Hubungkan ESPP atau aktifkan Mock Sensor untuk mulai menerima data.',
              action: PrimaryActionButton(
                label: 'Aktifkan Mock',
                icon: Icons.science,
                onPressed: () => app.setMockSensor(true),
              ),
            )
          else
            ResponsiveGrid(
              minTileWidth: 156,
              children: metricCards(app.lastPayload!, app),
            ),
          const SectionHeader(title: 'Detail gateway'),
          ResponsiveGrid(
            minTileWidth: 170,
            children: [
              InfoCard(
                icon: Icons.link,
                title: 'Backend URL',
                value: app.backendBaseUrl,
                tone: StatusTone.info,
              ),
              InfoCard(
                icon: Icons.person,
                title: 'Login',
                value: app.username,
                subtitle: 'Token tersimpan aman',
                tone: StatusTone.success,
              ),
              InfoCard(
                icon: Icons.phone_android,
                title: 'Perangkat',
                value: app.deviceInfo,
                subtitle: app.batteryPercent == null
                    ? 'Baterai tidak tersedia'
                    : 'Baterai ${app.batteryPercent}%',
              ),
              InfoCard(
                icon: Icons.data_object,
                title: 'Payload terakhir',
                value: app.lastBlePayloadText,
                tone: StatusTone.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusHero extends StatelessWidget {
  const StatusHero({super.key, required this.app, required this.queueStats});

  final AppController app;
  final QueueStats queueStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.monitor_heart,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IoT Health Gateway',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Legacy API Mode | /api/predict/',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ConnectionBadge(
                  label: app.backendOnline ? 'Backend siap' : 'Backend error',
                  connected: app.backendOnline,
                  icon: Icons.cloud,
                ),
                ConnectionBadge(
                  label: app.bleConnected ? 'BLE online' : 'BLE idle',
                  connected: app.bleConnected,
                  icon: Icons.bluetooth,
                ),
                SyncStatusBadge(
                  label: '${queueStats.pending} pending',
                  tone: queueStats.pending == 0
                      ? StatusTone.success
                      : StatusTone.warning,
                  icon: Icons.pending_actions,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HeroRows(
              rows: [
                ('Backend', app.backendStatus),
                ('Device', app.deviceName),
                ('Target BLE', config.AppConfig.defaultBleDeviceName),
                ('BLE status', app.bleStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroRows extends StatelessWidget {
  const _HeroRows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    row.$1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class LivePage extends ConsumerWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final payload = app.lastPayload;
    return ListView(
      padding: pagePadding,
      children: [
        const SectionHeader(
          title: 'Live sensor',
          subtitle: 'Pembacaan fisiologis terbaru dari ESP32 atau Mock Sensor.',
        ),
        if (payload == null)
          EmptyStateView(
            icon: Icons.monitor_heart_outlined,
            title: 'Belum ada pembacaan live',
            message:
                'Hubungkan ESPP atau aktifkan Mock Sensor untuk menampilkan data live.',
            action: PrimaryActionButton(
              label: 'Aktifkan Mock',
              icon: Icons.science,
              onPressed: () => app.setMockSensor(true),
            ),
          )
        else ...[
          ResponsiveGrid(
            minTileWidth: 160,
            children: [
              MetricCard(
                title: 'Heart Rate',
                value: valueText(payload.heartRate, 0),
                unit: 'bpm',
                subtitle: sourceLabel(payload.source),
                icon: Icons.favorite,
                tone: StatusTone.error,
                prominent: true,
              ),
              MetricCard(
                title: 'SpO2',
                value: valueText(payload.spo2, 0),
                unit: '%',
                subtitle: 'Oksigen',
                icon: Icons.water_drop,
                tone: StatusTone.info,
                prominent: true,
              ),
            ],
          ),
          const SectionHeader(title: 'HRV metrics'),
          ResponsiveGrid(
            minTileWidth: 145,
            children: [
              MetricCard(
                title: 'RMSSD',
                value: valueText(payload.rmssd, 1),
                unit: 'ms',
                icon: Icons.timeline,
                tone: StatusTone.neutral,
              ),
              MetricCard(
                title: 'SDRR',
                value: valueText(payload.sdrr, 1),
                unit: 'ms',
                icon: Icons.stacked_line_chart,
                tone: StatusTone.info,
              ),
              MetricCard(
                title: 'pNN50',
                value: valueText(payload.pnn50, 1),
                unit: '%',
                icon: Icons.percent,
                tone: payload.pnn50 <= 0
                    ? StatusTone.warning
                    : StatusTone.success,
              ),
            ],
          ),
          const SectionHeader(title: 'Prediksi'),
          StatusCard(
            icon: Icons.psychology,
            title: app.predictionLabel ?? 'Belum ada prediksi',
            value: 'Cluster ${app.predictionCluster ?? '-'}',
            subtitle:
                'Paket terakhir ${formatDate(app.lastPacketAt)} | ${sourceLabel(payload.source)}',
            tone: app.predictionLabel == null
                ? StatusTone.info
                : StatusTone.success,
          ),
          const SizedBox(height: 12),
          StatusCard(
            icon: Icons.data_object,
            title: 'Payload terakhir',
            value: app.lastBlePayloadText,
            subtitle: 'Disimpan lokal dengan seq ${payload.seq}',
            tone: StatusTone.info,
          ),
        ],
      ],
    );
  }
}

class BlePage extends ConsumerWidget {
  const BlePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return ListView(
      padding: pagePadding,
      children: [
        const SectionHeader(
          title: 'BLE ESP32',
          subtitle: 'Gunakan HP Android fisik untuk tes BLE ESP32.',
        ),
        DeviceInfoCard(
          title: 'Target perangkat',
          icon: app.bleConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          rows: {
            'Nama BLE': config.AppConfig.defaultBleDeviceName,
            'Service': config.BleUuidConfig.serviceUuid,
            'Notify': config.BleUuidConfig.sensorNotifyCharacteristicUuid,
            'Status': app.bleStatus,
          },
        ),
        const SizedBox(height: 12),
        PrimaryActionButton(
          label: app.scanning ? 'Mencari perangkat BLE...' : 'Scan BLE',
          icon: Icons.bluetooth_searching,
          loading: app.scanning,
          onPressed: app.startBleScan,
        ),
        if (app.scanning) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SectionHeader(
          title: 'Perangkat ditemukan',
          subtitle:
              'ESPP akan ditandai sebagai target. Perangkat lain tetap ditampilkan.',
        ),
        if (app.scanResults.isEmpty)
          EmptyStateView(
            icon: Icons.bluetooth_disabled,
            title: 'ESPP belum ditemukan',
            message:
                'Pastikan ESP32 menyala, Bluetooth aktif, dan gunakan HP Android fisik.',
          )
        else
          ...app.scanResults.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BleDeviceCard(
                result: result,
                isTarget: app.isTargetBleDevice(result),
                title: app.scanResultTitle(result),
                onConnect: () => app.connectToDevice(result),
              ),
            ),
          ),
      ],
    );
  }
}

class BleDeviceCard extends StatelessWidget {
  const BleDeviceCard({
    super.key,
    required this.result,
    required this.isTarget,
    required this.title,
    required this.onConnect,
  });

  final ScanResult result;
  final bool isTarget;
  final String title;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final services = result.advertisementData.serviceUuids
        .map((uuid) => uuid.toString())
        .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(
                  label: isTarget ? 'Target ESPP' : 'BLE',
                  tone: isTarget ? StatusTone.success : StatusTone.info,
                  icon: isTarget ? Icons.check_circle : Icons.bluetooth,
                ),
                const Spacer(),
                Text('${result.rssi} dBm'),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              result.device.remoteId.str,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              services.isEmpty
                  ? 'Advertised services: -'
                  : 'Advertised services: $services',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link),
                label: const Text('Hubungkan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final stats = QueueStats.from(app.queueItems);
    return ListView(
      padding: pagePadding,
      children: [
        SectionHeader(
          title: 'Antrean sinkronisasi',
          subtitle: 'Data selalu masuk antrean lokal sebelum dikirim.',
          action: FilledButton.icon(
            onPressed: app.syncing ? null : app.syncNow,
            icon: const Icon(Icons.sync),
            label: const Text('Sync Now'),
          ),
        ),
        ResponsiveGrid(
          minTileWidth: 115,
          children: [
            StatusCard(
              icon: Icons.pending_actions,
              title: 'Pending',
              value: '${stats.pending}',
              tone: stats.pending == 0
                  ? StatusTone.success
                  : StatusTone.warning,
            ),
            StatusCard(
              icon: Icons.cloud_done,
              title: 'Synced',
              value: '${stats.synced}',
              tone: StatusTone.success,
            ),
            StatusCard(
              icon: Icons.error_outline,
              title: 'Failed',
              value: '${stats.failed}',
              tone: stats.failed == 0 ? StatusTone.neutral : StatusTone.error,
            ),
          ],
        ),
        const SectionHeader(title: 'Item antrean'),
        if (app.queueItems.isEmpty)
          const EmptyStateView(
            icon: Icons.inbox,
            title: 'Belum ada data antrean',
            message: 'Data BLE atau Mock Sensor akan muncul di sini.',
          )
        else
          ...app.queueItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QueueItemCard(item: item),
            ),
          ),
      ],
    );
  }
}

class QueueItemCard extends StatelessWidget {
  const QueueItemCard({super.key, required this.item});

  final QueueItem item;

  @override
  Widget build(BuildContext context) {
    final payload = tryPayload(item.payloadJson);
    final tone = statusTone(item.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.deviceId} | seq ${item.seq}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                StatusBadge(
                  label: statusLabel(item.status),
                  tone: tone,
                  icon: statusIcon(item.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatDate(item.syncedAt ?? item.createdAt)),
            if (payload != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(
                    label: 'HR ${valueText(payload.heartRate, 0)} bpm',
                    tone: StatusTone.error,
                    icon: Icons.favorite,
                  ),
                  StatusBadge(
                    label: 'SpO2 ${valueText(payload.spo2, 0)}%',
                    tone: StatusTone.info,
                    icon: Icons.water_drop,
                  ),
                ],
              ),
            ],
            if (item.label != null) ...[
              const SizedBox(height: 8),
              Text(
                'Prediksi: ${item.label} | Cluster ${item.predictedCluster ?? '-'}',
              ),
            ],
            if (item.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                item.lastError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: toneColor(context, StatusTone.error),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final records = app.historyRecords;
    return RefreshIndicator(
      onRefresh: app.refreshHistory,
      child: ListView(
        padding: pagePadding,
        children: [
          const StatusCard(
            icon: Icons.info_outline,
            title: 'Riwayat lokal',
            value: 'Riwayat ditampilkan dari data lokal yang sudah tersinkron.',
            subtitle: 'Riwayat cloud membutuhkan endpoint backend tambahan.',
            tone: StatusTone.info,
          ),
          SectionHeader(
            title: 'Grafik ringkas',
            action: TextButton.icon(
              onPressed: app.refreshHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
          if (records.length >= 2)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: 220,
                  child: HealthChart(records: records),
                ),
              ),
            )
          else
            const EmptyStateView(
              icon: Icons.show_chart,
              title: 'Belum cukup data grafik',
              message: 'Minimal dua data tersinkron dibutuhkan untuk grafik.',
            ),
          const SectionHeader(title: 'Data terbaru'),
          if (records.isEmpty)
            const EmptyStateView(
              icon: Icons.history,
              title: 'Belum ada riwayat tersinkron',
              message: 'Sinkronisasi sukses akan muncul sebagai riwayat lokal.',
            )
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HistoryRecordCard(record: record),
              ),
            ),
        ],
      ),
    );
  }
}

class HistoryRecordCard extends StatelessWidget {
  const HistoryRecordCard({super.key, required this.record});

  final HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      icon: Icons.monitor_heart,
      title: record.label ?? 'Prediksi tersimpan',
      value:
          'HR ${valueText(record.heartRate, 0)} bpm | SpO2 ${valueText(record.spo2, 0)}%',
      subtitle:
          'Cluster ${record.predictedCluster ?? '-'} | ${formatDate(record.createdAt)}',
      tone: StatusTone.success,
    );
  }
}

class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return ListView(
      padding: pagePadding,
      children: [
        const SectionHeader(
          title: 'Security log',
          subtitle:
              'Log validasi lokal tanpa menampilkan password, token, atau API key.',
        ),
        if (app.securityEvents.isEmpty)
          const EmptyStateView(
            icon: Icons.security,
            title: 'Belum ada log',
            message: 'Event keamanan dan validasi akan muncul di sini.',
          )
        else
          ...app.securityEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StatusCard(
                icon: severityIcon(event.severity),
                title: event.type,
                value: event.message,
                subtitle: formatDate(event.createdAt),
                tone: severityTone(event.severity),
                trailing: StatusBadge(
                  label: event.severity,
                  tone: severityTone(event.severity),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController baseUrlController;
  late final TextEditingController deviceController;
  late final TextEditingController apiKeyController;
  late final TextEditingController secretController;

  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    baseUrlController = TextEditingController(text: app.backendBaseUrl);
    deviceController = TextEditingController(text: app.deviceName);
    apiKeyController = TextEditingController(text: app.legacyApiKey);
    secretController = TextEditingController(text: app.deviceSecret);
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    deviceController.dispose();
    apiKeyController.dispose();
    secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return ListView(
      padding: pagePadding,
      children: [
        const SectionHeader(
          title: 'Backend',
          subtitle:
              'Mode backend legacy menggunakan /api/predict/ dengan X-API-KEY.',
        ),
        TextField(
          controller: baseUrlController,
          decoration: const InputDecoration(
            labelText: 'Backend URL',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: apiKeyController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Legacy API key',
            helperText: 'Disimpan lokal di secure storage, jangan commit key.',
            prefixIcon: Icon(Icons.vpn_key),
          ),
        ),
        const SizedBox(height: 12),
        DeviceInfoCard(
          title: 'Legacy API',
          icon: Icons.cloud_sync,
          rows: const {
            'Endpoint': '/api/predict/',
            'Header': 'X-API-KEY',
            'API key': '***************',
          },
        ),
        const SectionHeader(title: 'Device'),
        TextField(
          controller: deviceController,
          decoration: const InputDecoration(
            labelText: 'Device backend',
            prefixIcon: Icon(Icons.memory),
          ),
        ),
        const SectionHeader(title: 'BLE'),
        DeviceInfoCard(
          title: 'Target ESP32',
          icon: Icons.bluetooth,
          rows: const {
            'Nama': config.AppConfig.defaultBleDeviceName,
            'Service': config.BleUuidConfig.serviceUuid,
            'Notify': config.BleUuidConfig.sensorNotifyCharacteristicUuid,
            'Write': 'Tidak digunakan',
          },
        ),
        const SectionHeader(title: 'Mock Sensor'),
        SwitchListTile(
          value: app.useMockSensor,
          onChanged: app.setMockSensor,
          title: const Text('Use Mock Sensor Data'),
          subtitle: const Text(
            'Meniru payload ESP32: bpm, spo2, rmssd, sdrr, pnn50.',
          ),
          secondary: const Icon(Icons.science),
        ),
        const SectionHeader(title: 'Security'),
        TextField(
          controller: secretController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Device secret opsional',
            helperText: 'Kosongkan untuk mode development tanpa tanda tangan.',
            prefixIcon: Icon(Icons.key),
          ),
        ),
        const SectionHeader(title: 'About'),
        DeviceInfoCard(
          title: 'Gateway',
          icon: Icons.info,
          rows: {
            'Aplikasi': 'IoT Health Gateway',
            'Backend': 'Legacy API Mode',
            'Riwayat': 'Lokal tersinkron',
            'Perangkat': app.deviceInfo,
          },
        ),
        const SizedBox(height: 16),
        PrimaryActionButton(
          label: 'Simpan Setelan',
          icon: Icons.save,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await app.saveSettings(
              baseUrl: baseUrlController.text,
              activeDeviceName: deviceController.text,
              secret: secretController.text,
              legacyKey: apiKeyController.text,
            );
            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Setelan disimpan')),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: app.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class HealthChart extends StatelessWidget {
  const HealthChart({super.key, required this.records});

  final List<HistoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestFirst = records.take(20).toList();
    final ordered = latestFirst.reversed.toList();
    final heart = <FlSpot>[];
    final spo2 = <FlSpot>[];
    for (var i = 0; i < ordered.length; i++) {
      heart.add(FlSpot(i.toDouble(), ordered[i].heartRate));
      spo2.add(FlSpot(i.toDouble(), ordered[i].spo2));
    }

    return LineChart(
      LineChartData(
        minY: 50,
        maxY: 140,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: heart,
            isCurved: true,
            color: AppTheme.heart,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spo2,
            isCurved: true,
            color: AppTheme.oxygen,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 160,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minTileWidth).floor().clamp(
          1,
          4,
        );
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class QueueStats {
  const QueueStats({
    required this.pending,
    required this.synced,
    required this.failed,
  });

  factory QueueStats.from(List<QueueItem> items) {
    var pending = 0;
    var synced = 0;
    var failed = 0;
    for (final item in items) {
      switch (item.status) {
        case 'synced':
          synced++;
        case 'failed':
          failed++;
        case 'pending':
        case 'syncing':
          pending++;
      }
    }
    return QueueStats(pending: pending, synced: synced, failed: failed);
  }

  final int pending;
  final int synced;
  final int failed;
}

const pagePadding = EdgeInsets.fromLTRB(14, 8, 14, 18);

List<Widget> metricCards(SensorPayload payload, AppController app) {
  return [
    MetricCard(
      title: 'Heart Rate',
      value: valueText(payload.heartRate, 0),
      unit: 'bpm',
      subtitle: 'dari bpm',
      icon: Icons.favorite,
      tone: StatusTone.error,
    ),
    MetricCard(
      title: 'SpO2',
      value: valueText(payload.spo2, 0),
      unit: '%',
      icon: Icons.water_drop,
      tone: StatusTone.info,
    ),
    MetricCard(
      title: 'RMSSD',
      value: valueText(payload.rmssd, 1),
      unit: 'ms',
      icon: Icons.timeline,
      tone: StatusTone.neutral,
    ),
    MetricCard(
      title: 'SDRR',
      value: valueText(payload.sdrr, 1),
      unit: 'ms',
      icon: Icons.stacked_line_chart,
      tone: StatusTone.info,
    ),
    MetricCard(
      title: 'pNN50',
      value: valueText(payload.pnn50, 1),
      unit: '%',
      icon: Icons.percent,
      tone: payload.pnn50 <= 0 ? StatusTone.warning : StatusTone.success,
    ),
    MetricCard(
      title: 'Prediksi',
      value: app.predictionLabel ?? '-',
      unit: '',
      subtitle: 'Cluster ${app.predictionCluster ?? '-'}',
      icon: Icons.psychology,
      tone: app.predictionLabel == null ? StatusTone.info : StatusTone.success,
    ),
  ];
}

SensorPayload? tryPayload(String payloadJson) {
  try {
    return SensorPayload.fromQueueJson(payloadJson);
  } catch (_) {
    return null;
  }
}

String valueText(num? value, int digits) {
  if (value == null) return '-';
  return value.toStringAsFixed(digits);
}

String formatDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('dd MMM HH:mm').format(date.toLocal());
}

String sourceLabel(String? source) {
  return switch (source) {
    'ble' => 'BLE',
    'mock' => 'Mock',
    _ => 'Local',
  };
}

String statusLabel(String status) {
  return switch (status) {
    'synced' => 'Synced',
    'syncing' => 'Syncing',
    'failed' => 'Failed',
    'invalid_for_sync' => 'Invalid',
    _ => 'Pending',
  };
}

IconData statusIcon(String status) {
  return switch (status) {
    'synced' => Icons.cloud_done,
    'syncing' => Icons.sync,
    'failed' => Icons.error_outline,
    'invalid_for_sync' => Icons.warning_amber,
    _ => Icons.schedule,
  };
}

StatusTone statusTone(String status) {
  return switch (status) {
    'synced' => StatusTone.success,
    'failed' => StatusTone.error,
    'invalid_for_sync' => StatusTone.warning,
    'syncing' => StatusTone.info,
    _ => StatusTone.warning,
  };
}

StatusTone severityTone(String severity) {
  final normalized = severity.toLowerCase();
  if (normalized.contains('error')) return StatusTone.error;
  if (normalized.contains('success')) return StatusTone.success;
  if (normalized.contains('info')) return StatusTone.info;
  return StatusTone.warning;
}

IconData severityIcon(String severity) {
  final normalized = severity.toLowerCase();
  if (normalized.contains('error')) return Icons.error_outline;
  if (normalized.contains('success')) return Icons.check_circle;
  if (normalized.contains('info')) return Icons.info_outline;
  return Icons.warning_amber;
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) return 'Wajib diisi';
  return null;
}
