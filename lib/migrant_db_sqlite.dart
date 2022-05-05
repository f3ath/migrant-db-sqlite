import 'package:migrant/migrant.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqlite;

class SQLiteGateway implements DatabaseGateway {
  SQLiteGateway(this._db, {String tablePrefix = '_migrations'})
      : _table = '${tablePrefix}_v$_version';

  /// Internal version.
  static const _version = '1';

  final sqlite.Database _db;
  final String _table;

  @override
  Future<String?> currentVersion() async {
    await _init();
    final result = await _db.rawQuery('select max(version) as v from $_table;');
    return result.first['v'] as String?;
  }

  @override
  Future<void> apply(Migration migration) async {
    await _init();
    await _db.transaction((ctx) async {
      await ctx.insert(_table, {
        'version': migration.version,
        'created_at': DateTime.now().toIso8601String()
      });
      await ctx.execute(migration.statement);
    });
  }

  /// Drops the migrations table.
  Future<void> dropMigrations() => _db.execute('drop table if exists $_table;');

  Future<void> _init() => _db.execute(
      'create table if not exists $_table (version text primary key, created_at text not null);');
}
