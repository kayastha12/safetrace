import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;
  static final List<Map<String, dynamic>> _webLogs = [];

  static Future<void> init() async {
    if (kIsWeb) {
      // Running on web, bypass SQLite initialization
      return;
    }
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'safetrace.db');

    _database = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            command_type TEXT,
            sender_number TEXT,
            location_data TEXT,
            battery_percentage INTEGER,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  // Get all logs sorted by timestamp descending
  static Future<List<Map<String, dynamic>>> getLogs() async {
    if (kIsWeb) {
      return List.from(_webLogs);
    }
    try {
      if (_database == null) return [];
      return await _database!.query('logs', orderBy: 'timestamp DESC');
    } catch (e) {
      return [];
    }
  }

  // Insert a log manually if needed
  static Future<int> insertLog({
    required String commandType,
    required String senderNumber,
    required String locationData,
    required int batteryPct,
    required String timestamp,
  }) async {
    if (kIsWeb) {
      _webLogs.insert(0, {
        'id': _webLogs.length + 1,
        'command_type': commandType,
        'sender_number': senderNumber,
        'location_data': locationData,
        'battery_percentage': batteryPct,
        'timestamp': timestamp,
      });
      return _webLogs.length;
    }
    try {
      if (_database == null) return -1;
      return await _database!.insert('logs', {
        'command_type': commandType,
        'sender_number': senderNumber,
        'location_data': locationData,
        'battery_percentage': batteryPct,
        'timestamp': timestamp,
      });
    } catch (e) {
      return -1;
    }
  }

  // Clear all logs
  static Future<void> clearLogs() async {
    if (kIsWeb) {
      _webLogs.clear();
      return;
    }
    try {
      if (_database == null) return;
      await _database!.delete('logs');
    } catch (e) {}
  }
}

