import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/gateway_models.dart';

class LocalDatabase {
  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      p.join(dbPath, 'iot_health_gateway.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sensor_queue (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            payload_json TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            predicted_cluster INTEGER,
            label TEXT,
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE security_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            message TEXT NOT NULL,
            severity TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE sensor_queue ADD COLUMN predicted_cluster INTEGER',
          );
          await db.execute('ALTER TABLE sensor_queue ADD COLUMN label TEXT');
        }
      },
    );
    return _database!;
  }

  Future<int> insertQueue(
    SensorPayload payload, {
    String status = 'pending',
    String? lastError,
  }) async {
    final db = await database;
    return db.insert('sensor_queue', {
      'device_id': payload.deviceId,
      'seq': payload.seq,
      'timestamp': payload.timestamp,
      'payload_json': payload.encoded,
      'status': status,
      'retry_count': 0,
      'last_error': lastError,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<QueueItem>> queueItems({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'sensor_queue',
      orderBy: 'local_id DESC',
      limit: limit,
    );
    return rows.map(QueueItem.fromMap).toList();
  }

  Future<List<QueueItem>> pendingForSync({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'sensor_queue',
      where: "status IN ('pending', 'failed')",
      orderBy: 'local_id ASC',
      limit: limit,
    );
    return rows.map(QueueItem.fromMap).toList();
  }

  Future<int> pendingCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM sensor_queue WHERE status IN ('pending', 'failed')",
      ),
    );
    return result ?? 0;
  }

  Future<void> markSyncing(Iterable<int> ids) async {
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'sensor_queue',
        {'status': 'syncing'},
        where: 'local_id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markSynced(
    int id, {
    int? predictedCluster,
    String? label,
  }) async {
    final db = await database;
    await db.update(
      'sensor_queue',
      {
        'status': 'synced',
        'last_error': null,
        'predicted_cluster': predictedCluster,
        'label': label,
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [id],
    );
  }

  Future<List<HistoryRecord>> localSyncedHistory({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'sensor_queue',
      where: "status = 'synced'",
      orderBy: 'synced_at DESC, local_id DESC',
      limit: limit,
    );

    return rows
        .map((row) {
          final payload = SensorPayload.fromQueueJson(
            row['payload_json'] as String,
          );
          return HistoryRecord(
            heartRate: payload.heartRate,
            spo2: payload.spo2,
            rmssd: payload.rmssd,
            sdrr: payload.sdrr,
            pnn50: payload.pnn50,
            predictedCluster: row['predicted_cluster'] as int?,
            label: row['label'] as String?,
            createdAt: row['synced_at'] == null
                ? DateTime.parse(row['created_at'] as String)
                : DateTime.parse(row['synced_at'] as String),
          );
        })
        .toList(growable: false);
  }

  Future<void> markFailed(int id, String error) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE sensor_queue
      SET status = 'failed',
          retry_count = retry_count + 1,
          last_error = ?
      WHERE local_id = ?
      ''',
      [error, id],
    );
  }

  Future<void> markInvalidForSync(int id, String error) async {
    final db = await database;
    await db.update(
      'sensor_queue',
      {'status': 'invalid_for_sync', 'last_error': error},
      where: 'local_id = ?',
      whereArgs: [id],
    );
  }

  Future<void> logSecurity(
    String type,
    String message, {
    String severity = 'warning',
  }) async {
    final db = await database;
    await db.insert('security_log', {
      'type': type,
      'message': message,
      'severity': severity,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<SecurityEvent>> securityEvents({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'security_log',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(SecurityEvent.fromMap).toList();
  }
}
