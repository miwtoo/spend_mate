import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';
import 'package:spend_mate/domain/models/auto_import_state.dart';

class AutoImportRepository {
  AutoImportRepository._(this._db);

  final Database _db;

  static const _kDbName = 'spend_mate.db';
  static const _kStateTable = 'auto_import_state';
  static const _kFoldersTable = 'auto_import_folders';
  static const _kAssetsTable = 'auto_import_assets';
  static const _kDraftsTable = 'auto_import_drafts';
  static const _kProcessedTable = 'auto_import_processed';

  static Future<AutoImportRepository> create() async {
    final dbPath = path.join(await getDatabasesPath(), _kDbName);
    final db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_kStateTable (
            id INTEGER PRIMARY KEY,
            enabled INTEGER NOT NULL,
            lastScanAt TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE $_kFoldersTable (
            path TEXT PRIMARY KEY
          );
        ''');
        await db.execute('''
          CREATE TABLE $_kAssetsTable (
            folderPath TEXT PRIMARY KEY,
            assetAccount TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE $_kDraftsTable (
            id TEXT PRIMARY KEY,
            sourcePath TEXT NOT NULL,
            sourceHash TEXT,
            fireflyTransactionId TEXT,
            fireflyTransactionJournalId TEXT,
            detectedAt TEXT NOT NULL,
            status TEXT NOT NULL,
            merchant TEXT,
            amount REAL,
            currency TEXT,
            date TEXT,
            note TEXT,
            categoryName TEXT,
            type TEXT,
            confidence REAL,
            assetAccountName TEXT,
            errorMessage TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE $_kProcessedTable (
            value TEXT PRIMARY KEY
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_kDraftsTable ADD COLUMN categoryName TEXT;',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $_kDraftsTable ADD COLUMN fireflyTransactionId TEXT;',
          );
          await db.execute(
            'ALTER TABLE $_kDraftsTable ADD COLUMN fireflyTransactionJournalId TEXT;',
          );
        }
      },
    );

    return AutoImportRepository._(db);
  }

  Future<AutoImportState> load() async {
    final stateRows = await _db.query(
      _kStateTable,
      where: 'id = ?',
      whereArgs: const [1],
      limit: 1,
    );
    final stateRow = stateRows.isEmpty ? null : stateRows.first;
    final enabledRaw = stateRow?['enabled'];
    final enabled = enabledRaw == 1 || enabledRaw == true;
    final lastScanAt = DateTime.tryParse(
      stateRow?['lastScanAt']?.toString() ?? '',
    );

    final folders = await _db.query(
      _kFoldersTable,
      columns: const ['path'],
      orderBy: 'path ASC',
    );
    final folderPaths = folders
        .map((row) => row['path']?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);

    final assets = await _db.query(_kAssetsTable);
    final assetAccountByFolder = <String, String>{};
    for (final row in assets) {
      final folder = row['folderPath']?.toString() ?? '';
      final account = row['assetAccount']?.toString() ?? '';
      if (folder.trim().isEmpty || account.trim().isEmpty) continue;
      assetAccountByFolder[folder] = account;
    }

    final draftsRows = await _db.query(_kDraftsTable);
    final drafts = draftsRows
        .map((row) => AutoImportDraft.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);

    final processedRows = await _db.query(
      _kProcessedTable,
      columns: const ['value'],
    );
    final processedFiles = processedRows
        .map((row) => row['value']?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);

    return AutoImportState(
      enabled: enabled,
      folderPaths: folderPaths,
      assetAccountByFolder: assetAccountByFolder,
      drafts: drafts,
      processedFiles: processedFiles,
      lastScanAt: lastScanAt,
    );
  }

  Future<void> save(AutoImportState state) async {
    await _db.transaction((txn) async {
      await txn.delete(_kStateTable);
      await txn.insert(
        _kStateTable,
        {
          'id': 1,
          'enabled': state.enabled ? 1 : 0,
          'lastScanAt': state.lastScanAt?.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(_kFoldersTable);
      for (final folder in state.folderPaths) {
        final value = folder.trim();
        if (value.isEmpty) continue;
        await txn.insert(
          _kFoldersTable,
          {'path': value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      await txn.delete(_kAssetsTable);
      for (final entry in state.assetAccountByFolder.entries) {
        final folder = entry.key;
        final account = entry.value;
        final folderValue = folder.trim();
        final accountValue = account.trim();
        if (folderValue.isEmpty || accountValue.isEmpty) continue;
        await txn.insert(
          _kAssetsTable,
          {
            'folderPath': folderValue,
            'assetAccount': accountValue,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.delete(_kDraftsTable);
      for (final draft in state.drafts) {
        await txn.insert(
          _kDraftsTable,
          draft.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.delete(_kProcessedTable);
      for (final entry in state.processedFiles) {
        final value = entry.trim();
        if (value.isEmpty) continue;
        await txn.insert(
          _kProcessedTable,
          {'value': value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}
