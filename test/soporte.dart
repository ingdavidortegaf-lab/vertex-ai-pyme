import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/data/local_db.dart';
// Las pruebas usan los métodos de LocalDb, que viven en extensiones por
// módulo (local_db_*.dart): se reexportan para que estén disponibles.
export 'package:vertex_ai_pyme/data/local_db.dart';
import 'package:vertex_ai_pyme/data/remote_api.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';

/// Abre una base nueva EN MEMORIA con el mismo esquema de la app.
/// (En pruebas se usa SQLite sin cifrar; en el celular es SQLCipher.)
Future<LocalDb> baseDePrueba() async {
  sqfliteFfiInit();
  final d = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (d, _) => LocalDb.crearEsquema(d)));
  final db = LocalDb.instance
    ..usarBase(d)
    ..reloj = DateTime.now;
  return db;
}

/// Servidor falso que se comporta como Supabase con el esquema del proyecto:
/// ventas = ON CONFLICT DO NOTHING; clientes = merge por campo.
class ServidorFalso implements RemoteApi {
  final tablas = <String, Map<String, Map<String, dynamic>>>{
    'clientes': {},
    'ventas': {},
    'productos': {},
    'inventario': {},
  };
  int envios = 0;

  /// Consultas de descarga recibidas (para medir la carga sobre la nube).
  int consultas = 0;
  int _reloj = 0;

  /// Falla con error de red al llegar a este número de envío (1 = el primero).
  int? fallarRedEnEnvio;

  /// ids que el servidor rechaza (dato inválido).
  final rechazar = <String>{};
  bool sesion = true;
  bool sesionVencida = false;
  String? respuestaIA;

  @override
  bool get haySesion => sesion;

  String _marca() =>
      DateTime.utc(2026, 1, 1).add(Duration(seconds: ++_reloj)).toIso8601String();

  @override
  Future<void> enviar(String tabla, Map<String, dynamic> fila) async {
    envios++;
    if (sesionVencida) throw const SesionVencida();
    if (fallarRedEnEnvio != null && envios == fallarRedEnEnvio) {
      throw Exception('sin red');
    }
    final id = fila['id'] as String;
    if (rechazar.contains(id)) throw const RechazoServidor('23514');
    final t = tablas[tabla]!;
    if (tabla == 'ventas' || tabla == 'inventario') {
      t.putIfAbsent(id, () => {...fila, 'recibido_at': _marca()});
    } else if (tabla == 'productos') {
      final nuevo = ProductoCampos.fromRemote(fila);
      final previo = t[id];
      final unido =
          previo == null ? nuevo : ProductoCampos.fromRemote(previo).merge(nuevo);
      t[id] = {...unido.toRemote(), 'recibido_at': _marca()};
    } else {
      final nuevo = ClienteCampos.fromRemote(fila);
      final previo = t[id];
      final unido =
          previo == null ? nuevo : ClienteCampos.fromRemote(previo).merge(nuevo);
      t[id] = {...unido.toRemote(), 'recibido_at': _marca()};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> descargar(
      String tabla, String? desde, int limite) async {
    consultas++;
    final filas = tablas[tabla]!
        .values
        .where((f) => desde == null || (f['recibido_at'] as String).compareTo(desde) > 0)
        .toList()
      ..sort((a, b) =>
          (a['recibido_at'] as String).compareTo(b['recibido_at'] as String));
    return filas.take(limite).toList();
  }

  @override
  Future<String?> asistente(Map<String, dynamic> cuerpo) async => respuestaIA;
}
