import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/data/local_db.dart';
// Las pruebas usan los métodos de LocalDb, que viven en extensiones por
// módulo (local_db_*.dart): se reexportan para que estén disponibles.
export 'package:vertex_ai_pyme/data/local_db.dart';
import 'package:vertex_ai_pyme/data/remote_api.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';
import 'package:vertex_ai_pyme/domain/invitaciones.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';

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
  // La instancia es única: el rol de una prueba no debe pasar a la siguiente.
  db.equipo.value = const ContextoEquipo();
  db.perfilActivo.value = null;
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

  /// Lo que responde mi_contexto (null: como un servidor sin la función).
  Map<String, dynamic>? contextoRemoto;

  /// De qué tabla o vista se descargó, en orden.
  final descargasDe = <String>[];

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
    // Como el servidor: lo que llega queda en la empresa de quien lo envía.
    if (_miEmpresa != null) fila = {...fila, 'empresa_id': _miEmpresa};
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
    descargasDe.add(tabla);
    // Las vistas operativas son las mismas filas sin las columnas de costo.
    final vista = {'productos_operativos': 'productos', 'inventario_operativo': 'inventario'}[tabla];
    final origen = tablas[vista ?? tabla]!.values.map((f) => vista == null
        ? f
        : (Map<String, dynamic>.of(f)
          ..remove('costo')
          ..remove('costo_ts')
          ..remove('costo_unit')));
    final filas = origen
        .where((f) => _miEmpresa == null || f['empresa_id'] == _miEmpresa) // RLS
        .where((f) => desde == null || (f['recibido_at'] as String).compareTo(desde) > 0)
        .toList()
      ..sort((a, b) =>
          (a['recibido_at'] as String).compareTo(b['recibido_at'] as String));
    return filas.take(limite).toList();
  }

  @override
  Future<String?> asistente(Map<String, dynamic> cuerpo) async => respuestaIA;

  @override
  Future<Map<String, dynamic>?> contexto() async {
    if (sesionVencida) throw const SesionVencida();
    if (contextoRemoto != null) return contextoRemoto;
    final m = miembros[yo];
    if (m == null) return null;
    return {'empresa_id': m.empresa, 'rol': m.rol, 'empresa': 'Mi empresa', 'despachador_fia': fia[m.empresa] ?? false};
  }

  // ------------------------------------------------------- equipo simulado
  // Mismas reglas que las funciones del servidor (migración de roles); las
  // pruebas SQL de supabase/tests comprueban que el servidor real las cumple.

  /// Usuario con la sesión abierta.
  String yo = 'u-duena';
  final miembros = <String, ({String empresa, String rol, String correo})>{};
  final invitaciones = <String, ({String empresa, String rol, bool usado})>{};
  final fia = <String, bool>{};

  /// Empresas que ya tienen datos en la nube (unirse las rechaza).
  final empresasConDatos = <String>{};

  /// Como un servidor sin la migración de roles.
  bool sinFuncionesEquipo = false;

  /// Las funciones del equipo fallan como sin internet.
  bool sinRed = false;
  int _n = 0;

  /// Agrega a alguien a una empresa (para preparar la prueba).
  void miembro(String user, String empresa, Rol rol, [String? correo]) =>
      miembros[user] = (empresa: empresa, rol: rolATexto(rol), correo: correo ?? '$user@correo.co');

  void _puedo() {
    if (sesionVencida) throw const SesionVencida();
    if (sinRed) throw Exception('sin red');
    if (sinFuncionesEquipo) {
      throw const RechazoServidor('PGRST202', 'Could not find the function in the schema cache');
    }
  }

  Never _no(String codigo, String m) => throw RechazoServidor(codigo, m);
  String? get _miRol => miembros[yo]?.rol;
  String? get _miEmpresa => miembros[yo]?.empresa;

  @override
  Future<String> crearInvitacion(Rol rol, {int dias = diasInvitacion}) async {
    _puedo();
    if (_miRol != 'dueno') _no('42501', 'Solo el dueño puede invitar empleados');
    if (!rolesInvitables.contains(rol)) _no('22023', 'Rol no válido para una invitación');
    if (dias < 1 || dias > 30) _no('22023', 'La invitación debe durar entre 1 y 30 días');
    final i = _n++;
    final c = 'ABCDEF${alfabetoCodigo[i ~/ alfabetoCodigo.length]}${alfabetoCodigo[i % alfabetoCodigo.length]}';
    invitaciones[c] = (empresa: _miEmpresa!, rol: rolATexto(rol), usado: false);
    return c;
  }

  @override
  Future<Map<String, dynamic>> unirseConCodigo(String codigo) async {
    _puedo();
    final inv = invitaciones[codigo.trim().toUpperCase()];
    if (inv == null || inv.usado) _no('22023', 'El código no es válido, ya se usó o se venció');
    final vieja = _miEmpresa;
    if (vieja == inv.empresa) _no('22023', 'Ya perteneces a este negocio');
    if (vieja != null) {
      final otros = miembros.entries.where((e) => e.key != yo && e.value.empresa == vieja);
      if (otros.isNotEmpty || empresasConDatos.contains(vieja)) {
        _no('22023', 'Esta cuenta ya tiene un negocio con datos o empleados; usa otra cuenta para unirte');
      }
    }
    miembros[yo] = (empresa: inv.empresa, rol: inv.rol, correo: miembros[yo]?.correo ?? '$yo@correo.co');
    invitaciones[codigo.trim().toUpperCase()] = (empresa: inv.empresa, rol: inv.rol, usado: true);
    return {'empresa_id': inv.empresa, 'rol': inv.rol};
  }

  @override
  Future<List<MiembroEquipo>> equipo() async {
    _puedo();
    if (_miRol != 'dueno' && _miRol != 'administrador') {
      _no('42501', 'Solo el dueño o el administrador ven el equipo');
    }
    final l = miembros.entries.where((e) => e.value.empresa == _miEmpresa).toList()
      ..sort((a, b) {
        final r = (a.value.rol == 'dueno' ? 0 : 1).compareTo(b.value.rol == 'dueno' ? 0 : 1);
        return r != 0 ? r : a.value.correo.compareTo(b.value.correo);
      });
    return [
      for (final e in l)
        MiembroEquipo(userId: e.key, correo: e.value.correo, rol: rolDesdeTexto(e.value.rol))
    ];
  }

  @override
  Future<void> cambiarRol(String usuario, Rol rol) async {
    _puedo();
    if (_miRol != 'dueno') _no('42501', 'Solo el dueño puede cambiar roles');
    if (usuario == yo) _no('22023', 'No puedes cambiar tu propio rol');
    if (!rolesInvitables.contains(rol)) _no('22023', 'Rol no válido');
    final m = miembros[usuario];
    if (m == null || m.empresa != _miEmpresa || m.rol == 'dueno') {
      _no('22023', 'Esa persona no es empleada de tu negocio');
    }
    miembros[usuario] = (empresa: m.empresa, rol: rolATexto(rol), correo: m.correo);
  }

  @override
  Future<void> quitarMiembro(String usuario) async {
    _puedo();
    if (_miRol != 'dueno') _no('42501', 'Solo el dueño puede quitar empleados');
    if (usuario == yo) _no('22023', 'No puedes quitarte a ti mismo');
    final m = miembros[usuario];
    if (m == null || m.empresa != _miEmpresa || m.rol == 'dueno') {
      _no('22023', 'Esa persona no es empleada de tu negocio');
    }
    miembros[usuario] = (empresa: 'e-propia-${_n++}', rol: 'dueno', correo: m.correo);
  }

  @override
  Future<void> definirDespachadorFia(bool valor) async {
    _puedo();
    if (_miRol != 'dueno') _no('42501', 'Solo el dueño puede cambiar esta opción');
    fia[_miEmpresa!] = valor;
  }
}
