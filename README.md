SQLite gateway for [migrant](https://pub.dev/packages/migrant).

Example:

```dart
import 'package:migrant/migrant.dart';
import 'package:migrant/testing.dart';
import 'package:migrant_db_sqlite/migrant_db_sqlite.dart';
import 'package:sqflite_common/sqlite_api.dart' show inMemoryDatabasePath;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;

Future<void> main() async {
  // These are the migrations. We are using a simple in-memory source,
  // but you may read them from other sources: local filesystem, network, etc.
  // More options at https://pub.dev/packages/migrant
  final migrations = InMemory([
    Migration('0001', ['CREATE TABLE foo (id TEXT NOT NULL PRIMARY KEY);']),
    Migration('0002', ['ALTER TABLE foo ADD COLUMN message TEXT;']),
    // Try adding more stuff here and running this example again.
  ]);

  // The SQLite connection. We're using a local file.
  var connection = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

  // The gateway is provided by this package.
  final gateway = SQLiteGateway(connection);

  // Applying migrations.
  await Database(gateway).upgrade(migrations);
  // At this point the table "foo" is ready.
}
```