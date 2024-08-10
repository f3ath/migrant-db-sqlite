import 'package:migrant/migrant.dart';
import 'package:migrant/testing.dart';
import 'package:migrant_db_sqlite/migrant_db_sqlite.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

/// To run locally, start postgres:
/// `docker run -d -p 5432:5432 --name my-postgres -e POSTGRES_PASSWORD=postgres postgres`
void main() {
  group('Happy path', () {
    late Database db;
    late sqlite.Database connection;
    late SQLiteGateway gateway;

    setUp(() async {
      connection = await _createConnection();
      gateway = SQLiteGateway(connection);
      db = Database(gateway);
    });

    tearDown(() async {
      await connection.close();
    });

    test('Single migration', () async {
      final source = InMemory([
        Migration('0', ['create table test (id text);'])
      ]);
      expect(await gateway.currentVersion(), isNull);
      await db.upgrade(source);
      expect(await gateway.currentVersion(), equals('0'));
      await connection.insert('test', {
        'id': '0000',
      });
      final result = await connection.query('test');
      expect(
          result,
          equals([
            {'id': '0000'}
          ]));
    });

    test('Single migration, idempotency', () async {
      final source = InMemory([
        Migration('0', ['create table test (id text);'])
      ]);
      expect(await gateway.currentVersion(), isNull);
      await db.upgrade(source);
      // await db.upgrade(source); // idempotency
      expect(await gateway.currentVersion(), equals('0'));
      await connection.insert('test', {
        'id': '0000',
      });
      final result = await connection.query('test');
      expect(
          result,
          equals([
            {'id': '0000'}
          ]));
    });

    test('Multiple migrations', () async {
      final source = InMemory([
        Migration('0', ['create table test (id text);']),
        Migration('1', ['alter table test add column foo text;']),
        Migration('2', ['alter table test add column bar text;'])
      ]);
      expect(await gateway.currentVersion(), isNull);
      await db.upgrade(source);
      expect(await gateway.currentVersion(), equals('2'));
      await connection.insert('test', {
        'id': '0000',
        'foo': 'hello',
        'bar': 'world',
      });
      final result = await connection.query('test');
      expect(
          result,
          equals([
            {'id': '0000', 'foo': 'hello', 'bar': 'world'}
          ]));
    });

    test('Multiple migrations, idempotency', () async {
      final source = InMemory([
        Migration('0', ['create table test (id text);']),
        Migration('1', ['alter table test add column foo text;']),
        Migration('2', ['alter table test add column bar text;'])
      ]);
      expect(await gateway.currentVersion(), isNull);
      await db.upgrade(source);
      await db.upgrade(source); // idempotency
      expect(await gateway.currentVersion(), equals('2'));
      await connection.insert('test', {
        'id': '0000',
        'foo': 'hello',
        'bar': 'world',
      });
      final result = await connection.query('test');
      expect(
          result,
          equals([
            {'id': '0000', 'foo': 'hello', 'bar': 'world'}
          ]));
    });
  });

  group('Failures', () {
    late Database db;
    late sqlite.Database connection;
    late SQLiteGateway gateway;

    setUp(() async {
      connection = await _createConnection();
      gateway = SQLiteGateway(connection);
      db = Database(gateway);
    });

    tearDown(() async {
      await connection.close();
    });

    test('initialize() detects RC', () async {
      await gateway.initialize(Migration('1', ['create table foo (id text);']));

      await expectLater(
          () => gateway
              .initialize(Migration('0', ['create table bar (id text);'])),
          throwsA(isA<RaceCondition>().having((it) => it.message, 'message',
              equals('Unexpected history: [0, 1]'))));

      expect(await gateway.currentVersion(), equals('1'));
    });

    test('upgrade() detects RC', () async {
      await gateway.initialize(Migration('1', ['create table foo (id text);']));

      await expectLater(
          () => gateway.upgrade(
              '0', Migration('2', ['create table bar (id text);'])),
          throwsA(isA<RaceCondition>().having((it) => it.message, 'message',
              equals('Unexpected history: [1, 2]'))));

      expect(await gateway.currentVersion(), equals('1'));
    });

    test('Single invalid migration not applied', () async {
      final source = InMemory([
        Migration('0', ['drop table not_exists;'])
      ]);

      expect(() => db.upgrade(source), throwsException);
      expect(await gateway.currentVersion(), isNull);
    });

    test('Migrations get applied until the first failure', () async {
      final source = InMemory([
        Migration('0', ['create table test (id text);']),
        Migration('1', ['alter table test add column c1 text;']),
        Migration('2', ['alter table test add column c2 text;']),
        Migration('3', ['alter table test_oops add column c3 text;']),
        Migration('4', ['alter table test add column c4 text;']),
      ]);

      await expectLater(() => db.upgrade(source), throwsException);
      expect(await gateway.currentVersion(), equals('2'));
    });
  });

  test('RaceCondition toString', () {
    final rc = RaceCondition('Foo');
    expect(rc.toString(), equals('Foo'));
  });
}

Future<sqlite.Database> _createConnection() =>
    ffi.databaseFactoryFfi.openDatabase(sqlite.inMemoryDatabasePath);
