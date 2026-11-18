import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

/// ¿Es un computador (Windows, Linux o macOS)?
bool get esEscritorio => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Celular: base CIFRADA (SQLCipher). La clave (256 bits aleatorios) se
/// genera la primera vez y se guarda en el almacén seguro del sistema.
/// PC: SQLite en la carpeta de datos del usuario (sin cifrar; pendiente).
Future<Database> abrirBase({
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
}) async {
  if (esEscritorio) {
    sqfliteFfiInit();
    final dir = await getApplicationSupportDirectory();
    return databaseFactoryFfi.openDatabase(p.join(dir.path, 'vertex.db'),
        options: OpenDatabaseOptions(version: version, onCreate: onCreate, onUpgrade: onUpgrade));
  }
  const storage = FlutterSecureStorage();
  var key = await storage.read(key: 'db_key');
  if (key == null) {
    final r = Random.secure();
    key = base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
    await storage.write(key: 'db_key', value: key);
  }
  final path = p.join(await cipher.getDatabasesPath(), 'vertex.db');
  return cipher.openDatabase(path,
      password: key, version: version, onCreate: onCreate, onUpgrade: onUpgrade);
}
