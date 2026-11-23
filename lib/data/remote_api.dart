import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/invitaciones.dart';
import '../domain/roles.dart';

/// El servidor rechazó el registro (dato inválido, permiso, etc.).
/// Se reintenta con espera creciente y luego se aparta, sin borrarlo.
class RechazoServidor implements Exception {
  final String codigo;

  /// Explicación del servidor, cuando la da (las funciones del equipo
  /// responden en español: «El código no es válido…»).
  final String mensaje;
  const RechazoServidor(this.codigo, [this.mensaje = '']);
  @override
  String toString() => 'RechazoServidor($codigo)';
}

/// No hay sesión o venció: hay que iniciar sesión otra vez.
class SesionVencida implements Exception {
  const SesionVencida();
}

// Cualquier otra excepción se trata como problema de red: la cola queda
// intacta y se reintenta después.

/// Lo que la app necesita de la nube. Se abstrae para poder probar la cola
/// de sincronización sin servidor.
abstract class RemoteApi {
  bool get haySesion;

  /// Envía un registro de forma idempotente (upsert por id).
  Future<void> enviar(String tabla, Map<String, dynamic> fila);

  /// Cambios hechos en otros celulares de la misma empresa.
  Future<List<Map<String, dynamic>>> descargar(
      String tabla, String? desde, int limite);

  /// Llama al asistente de IA del servidor. Devuelve null si no respondió.
  Future<String?> asistente(Map<String, dynamic> cuerpo);

  /// Rol y empresa de este usuario (función mi_contexto del servidor).
  /// Null si el servidor todavía no la tiene.
  Future<Map<String, dynamic>?> contexto();

  // ------------------------------------------------ equipo (necesitan red)
  /// Crea un código de un solo uso para entrar al negocio con [rol].
  Future<String> crearInvitacion(Rol rol, {int dias = diasInvitacion});

  /// Une esta cuenta al negocio del código. Devuelve empresa_id y rol.
  Future<Map<String, dynamic>> unirseConCodigo(String codigo);

  Future<List<MiembroEquipo>> equipo();
  Future<void> cambiarRol(String usuario, Rol rol);
  Future<void> quitarMiembro(String usuario);
  Future<void> definirDespachadorFia(bool valor);
  Future<void> definirDescuentoMaximo(double pct);
}

class SupabaseRemote implements RemoteApi {
  SupabaseRemote(this._sb);
  final SupabaseClient _sb;
  static const _timeout = Duration(seconds: 20);

  @override
  bool get haySesion => _sb.auth.currentSession != null;

  static bool _esSesion(PostgrestException e) =>
      e.code == 'PGRST301' ||
      e.code == 'PGRST302' ||
      e.code == '401' ||
      e.message.toLowerCase().contains('jwt');

  Never _traducir(Object e) {
    if (e is PostgrestException) {
      if (_esSesion(e)) throw const SesionVencida();
      throw RechazoServidor(e.code ?? 'servidor', e.message);
    }
    if (e is AuthException) throw const SesionVencida();
    throw e; // red / timeout
  }

  @override
  Future<void> enviar(String tabla, Map<String, dynamic> fila) async {
    try {
      // ventas: ON CONFLICT DO NOTHING (solo se agregan, sin duplicados).
      // clientes: ON CONFLICT DO UPDATE; el trigger merge_cliente conserva
      // el campo más reciente.
      // inventario también solo se agrega; productos se une por campo
      // (trigger merge_producto).
      await _sb
          .from(tabla)
          .upsert(fila,
              onConflict: 'id',
              ignoreDuplicates: tabla == 'ventas' || tabla == 'inventario')
          .timeout(_timeout);
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> descargar(
      String tabla, String? desde, int limite) async {
    try {
      var q = _sb.from(tabla).select();
      if (desde != null) q = q.gt('recibido_at', desde);
      final r = await q
          .order('recibido_at', ascending: true)
          .limit(limite)
          .timeout(_timeout);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<Map<String, dynamic>?> contexto() async {
    try {
      final r = await _sb.rpc('mi_contexto').timeout(_timeout);
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (e) {
      _traducir(e);
    }
  }

  Future<dynamic> _rpc(String fn, [Map<String, dynamic>? params]) async {
    try {
      return await _sb.rpc(fn, params: params).timeout(_timeout);
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<String> crearInvitacion(Rol rol, {int dias = diasInvitacion}) async =>
      (await _rpc('crear_invitacion', {'p_rol': rolATexto(rol), 'p_dias': dias})) as String;

  @override
  Future<Map<String, dynamic>> unirseConCodigo(String codigo) async =>
      Map<String, dynamic>.from(
          (await _rpc('unirse_con_codigo', {'p_codigo': normalizarCodigo(codigo)})) as Map);

  @override
  Future<List<MiembroEquipo>> equipo() async => [
        for (final f in (await _rpc('equipo')) as List)
          MiembroEquipo.desdeServidor(Map<String, dynamic>.from(f as Map))
      ];

  @override
  Future<void> cambiarRol(String usuario, Rol rol) =>
      _rpc('cambiar_rol', {'p_usuario': usuario, 'p_rol': rolATexto(rol)});

  @override
  Future<void> quitarMiembro(String usuario) => _rpc('quitar_miembro', {'p_usuario': usuario});

  @override
  Future<void> definirDespachadorFia(bool valor) =>
      _rpc('definir_despachador_fia', {'p_valor': valor});

  @override
  Future<void> definirDescuentoMaximo(double pct) =>
      _rpc('definir_descuento_maximo', {'p_pct': pct});

  @override
  Future<String?> asistente(Map<String, dynamic> cuerpo) async {
    final res =
        await _sb.functions.invoke('asistente', body: cuerpo).timeout(_timeout);
    final d = res.data;
    if (res.status == 200 && d is Map && d['respuesta'] is String) {
      final t = (d['respuesta'] as String).trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }
}
