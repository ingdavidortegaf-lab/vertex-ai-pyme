import 'package:supabase_flutter/supabase_flutter.dart';

/// El servidor rechazó el registro (dato inválido, permiso, etc.).
/// Se reintenta con espera creciente y luego se aparta, sin borrarlo.
class RechazoServidor implements Exception {
  final String codigo;
  const RechazoServidor(this.codigo);
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
      throw RechazoServidor(e.code ?? 'servidor');
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
