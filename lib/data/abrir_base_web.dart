import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// En el navegador no es un computador de escritorio "nativo".
bool get esEscritorio => false;

/// Versión web (por ejemplo, en un iPhone con Safari): SQLite compilada a
/// WebAssembly; los datos quedan guardados en el navegador de ese equipo
/// (IndexedDB). Funciona sin internet una vez abierta.
Future<Database> abrirBase({
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
}) =>
    databaseFactoryFfiWeb.openDatabase('vertex.db',
        options: OpenDatabaseOptions(version: version, onCreate: onCreate, onUpgrade: onUpgrade));
