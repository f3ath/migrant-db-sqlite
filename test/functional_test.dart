import 'package:migrant/migrant.dart';
import 'package:migrant/testing.dart';
import 'package:migrant_db_sqlite/migrant_db_sqlite.dart';
import 'package:sqflite_common/sqlite_api.dart' hide Database;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('Can apply migrations', () async {
    final source = InMemory({
      '00': 'create table test (id text not null);',
      '01': 'alter table test add column foo text;',
      '02': 'alter table test add column bar text;'
    });

    var connection =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    final gateway = SQLiteGateway(connection);
    await gateway.dropMigrations();
    await connection.execute("drop table if exists test;");
    final db = Database(gateway);
    await db.migrate(source);
    expect(await gateway.currentVersion(), equals('02'));
    await db.migrate(source); // idempotency
    expect(await gateway.currentVersion(), equals('02'));
    await connection.insert('test', {
      'id': '0000',
      'foo': 'hello',
      'bar': 'world',
    });
    expect(
        await connection.query('test'),
        equals([
          {'id': '0000', 'foo': 'hello', 'bar': 'world'}
        ]));

    await connection.close();
  });

  test('Invalid migrations', () async {
    var connection =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final gateway = SQLiteGateway(connection);
    await gateway.dropMigrations();
    await connection.execute("drop table if exists test;");

    final db = Database(gateway);
    expect(() => db.migrate(AsIs([Migration('00', 'drop table not_found;')])),
        throwsA(isA<DatabaseException>()));
    expect(await gateway.currentVersion(), isNull);
    await db.migrate(AsIs([Migration('00', 'create table test (id text);')]));
    expect(await gateway.currentVersion(), equals('00'));
    expect(() => db.migrate(AsIs([Migration('01', 'drop table not_found;')])),
        throwsA(isA<DatabaseException>()));
    expect(await gateway.currentVersion(), equals('00'));
    await connection.close();
  });
}
