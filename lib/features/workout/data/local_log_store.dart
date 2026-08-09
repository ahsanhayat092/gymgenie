import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:gymgenie/features/workout/domain/workout_log.dart';

/// Local SQLite store used as an offline write-ahead queue for workout logs.
///
/// Firestore remains the canonical store. When a finish-write fails because
/// the device is offline, the log is saved here and retried later.
class LocalLogStore {
  LocalLogStore._();

  static final LocalLogStore _instance = LocalLogStore._();
  factory LocalLogStore() => _instance;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'gymgenie_logs.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            firestoreId TEXT,
            createdAt INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Inserts a log that has not yet been synced to Firestore.
  /// Returns the local id.
  Future<int> insertPendingLog(WorkoutLog log) async {
    final db = await database;
    return db.insert('pending_logs', {
      'payload': jsonEncode(log.toMap()),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });
  }

  /// Returns all logs that are still waiting to be synced.
  Future<List<PendingLogEntry>> pendingLogs() async {
    final db = await database;
    final rows = await db.query(
      'pending_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'createdAt ASC',
    );
    return rows.map(_rowToEntry).toList();
  }

  /// Marks a pending log as synced and stores its Firestore id.
  Future<void> markSynced(int localId, String firestoreId) async {
    final db = await database;
    await db.update(
      'pending_logs',
      {'synced': 1, 'firestoreId': firestoreId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Deletes all logs that have already been synced.
  Future<void> deleteSynced() async {
    final db = await database;
    await db.delete(
      'pending_logs',
      where: 'synced = ?',
      whereArgs: [1],
    );
  }

  /// Deletes a pending log by its local ID.
  Future<void> deletePendingLog(int localId) async {
    final db = await database;
    await db.delete(
      'pending_logs',
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  PendingLogEntry _rowToEntry(Map<String, dynamic> row) {
    final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    return PendingLogEntry(
      localId: row['id'] as int,
      log: WorkoutLog.fromMap(payload, 'pending_${row['id']}'),
    );
  }
}

class PendingLogEntry {
  const PendingLogEntry({required this.localId, required this.log});

  final int localId;
  final WorkoutLog log;
}

final localLogStoreProvider = Provider<LocalLogStore>(
  (ref) => LocalLogStore(),
);
