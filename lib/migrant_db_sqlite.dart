import 'package:migrant/migrant.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqlite;

class SQLiteGateway implements DatabaseGateway {
  SQLiteGateway(this._db, {String tablePrefix = '_migrations'})
      : _table = '${tablePrefix}_v$_version';

  /// Internal version.
  static const _version = 1;

  final sqlite.Database _db;
  final String _table;

  @override
  Future<void> initialize(Migration migration) async {
    await _init();
    await _db.transaction((ctx) async {
      final history = await _apply(migration, ctx);
      if (history.length != 1 || history.first != migration.version) {
        throw RaceCondition('Unexpected history: $history');
      }
    });
  }

  @override
  Future<void> upgrade(String version, Migration migration) async {
    await _init();
    await _db.transaction((ctx) async {
      final history = await _apply(migration, ctx);
      if (history.length < 2 ||
          history.last != migration.version ||
          history[history.length - 2] != version) {
        throw RaceCondition('Unexpected history: $history');
      }
    });
  }

  @override
  Future<String?> currentVersion() async {
    await _init();
    final result = await _db.rawQuery('select max(version) as v from $_table;');
    return result.first['v'] as String?;
  }

  Future<void> _register(String version, sqlite.Transaction tx) => tx.insert(
      _table,
      {'version': version, 'created_at': DateTime.now().toIso8601String()});

  /// Applies the migration and returns the applied versions, ascending.
  Future<List<String>> _apply(
      Migration migration, sqlite.Transaction tx) async {
    for (final statement in migration.statements) {
      await tx.execute(statement);
    }
    await _register(migration.version, tx);
    final result = await tx.query(_table, orderBy: 'version asc');
    return result.map((row) => row['version'] as String).toList();
  }

  Future<void> _init() => _db.execute(
      'create table if not exists $_table (version text primary key, created_at text not null);');
}

/// Thrown when the gateway detects a race condition during migration.
class RaceCondition implements Exception {
  const RaceCondition(this.message);

  final String message;

  @override
  String toString() => message;
}
