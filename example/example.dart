import 'dart:io';

import 'package:migrant/migrant.dart';
import 'package:migrant/testing.dart';
import 'package:migrant_db_sqlite/migrant_db_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  // These are the migrations. We are using a simple in-memory source,
  // but you may read them from other sources: local filesystem, network, etc.
  // More options at https://pub.dev/packages/migrant
  final migrations = InMemory({
    '0001': 'CREATE TABLE foo (id TEXT NOT NULL PRIMARY KEY);',
    '0002': 'ALTER TABLE foo ADD COLUMN message TEXT;',
    // Try adding more stuff here and running this example again.
  });

  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
  }

  print("Database path:" + await databaseFactoryFfi.getDatabasesPath());

  // The SQLite connection. We're using a local file.
  var connection = await databaseFactoryFfi.openDatabase('example.db');

  // The gateway is provided by this package.
  final gateway = SQLiteGateway(connection);

  // Extra capabilities may be added like this. See the implementation below.
  final loggingGateway = LoggingGatewayWrapper(gateway);

  // Applying migrations.
  await Database(loggingGateway).migrate(migrations);

  // At this point the table "foo" is ready. We're done.
}

// Compose everything!
class LoggingGatewayWrapper implements DatabaseGateway {
  LoggingGatewayWrapper(this.gateway);

  final DatabaseGateway gateway;

  @override
  Future<void> apply(Migration migration) async {
    print('Applying version ${migration.version}...');
    gateway.apply(migration);
    print('Version ${migration.version} has been applied.');
  }

  @override
  Future<String?> currentVersion() async {
    final version = await gateway.currentVersion();
    print('The database is at version $version.');
    return version;
  }
}
