import '../domain/asistente_local.dart';
import '../domain/formato.dart';
import '../domain/privacidad.dart';
import '../domain/resumen.dart';
import 'local_db.dart';
import 'remote_api.dart';

class RespuestaAsistente {
  final String texto;

  /// true = respondió la IA del servidor; false = respuesta local.
  final bool esIA;

  /// La pregunta quedó guardada para que la IA la responda con señal.
  final bool enCola;
  final String? telefono;
  final String? mensajeWhatsApp;
  const RespuestaAsistente(this.texto,
      {this.esIA = false, this.enCola = false, this.telefono, this.mensajeWhatsApp});
}

/// Asistente del negocio:
/// - Preguntas sobre los datos («¿cuánto vendí?», «¿quién me debe?»): se
///   responden SIEMPRE en el celular, exactas y sin señal.
/// - Preguntas abiertas («¿cómo voy?», «¿qué hago para vender más?»): con
///   señal las responde la IA del servidor; sin señal se da el resumen local
///   y la pregunta queda en cola para la IA.
/// Minimización (Ley 1581): a la IA solo van totales y la pregunta sin
/// nombres, teléfonos ni correos.
class AsistenteService {
  static Future<RespuestaAsistente> preguntar(
    String pregunta, {
    required RemoteApi? api,
    required Future<bool> Function() hayRed,
    LocalDb? db,
  }) async {
    final base = db ?? LocalDb.instance;
    final datos = await base.datosAsistente();
    final local = responderLocal(pregunta, datos);
    final intencion = detectarIntencion(pregunta);
    if (intencion != Intencion.general && intencion != Intencion.resumen) {
      return RespuestaAsistente(local.texto,
          telefono: local.telefono, mensajeWhatsApp: local.mensajeWhatsApp);
    }
    if (api == null) return RespuestaAsistente(local.texto);

    if (api.haySesion && await _red(hayRed)) {
      try {
        final r = await api.asistente(cuerpoConsejo(pregunta, datos));
        if (r != null) {
          await base.guardarPreguntaIA(pregunta, respuesta: r);
          return RespuestaAsistente(r, esIA: true);
        }
      } catch (_) {
        // sin respuesta: sigue con el respaldo local
      }
    }
    await base.guardarPreguntaIA(pregunta);
    return RespuestaAsistente(
      '${local.texto}\n\nCuando haya señal, la IA también responderá esta '
      'pregunta; lo verás abajo en «Consejos con IA».',
      enCola: true,
    );
  }

  static Future<bool> _red(Future<bool> Function() hayRed) async {
    try {
      return await hayRed();
    } catch (_) {
      return false;
    }
  }

  /// Lo único que viaja al servidor para un consejo.
  static Map<String, dynamic> cuerpoConsejo(String pregunta, DatosAsistente d) =>
      {
        'modo': 'consejo',
        'pregunta': anonimizarPregunta(pregunta, d.clientes.map((c) => c.nombre)),
        'ingresos': d.mes.ingresos,
        'egresos': d.mes.egresos,
        'nIngresos': d.mes.nIngresos,
        'nEgresos': d.mes.nEgresos,
        'porCobrar': d.mes.porCobrar,
        'nDeudores': d.mes.nDeudores,
        'ventasSemana': d.ventasSemana,
      };

  /// Responde las preguntas que quedaron en cola (lo llama la sincronización).
  static Future<void> procesarPendientes(RemoteApi api, LocalDb db) async {
    final pendientes = await db.preguntasIAPendientes();
    if (pendientes.isEmpty) return;
    final datos = await db.datosAsistente();
    for (final p in pendientes) {
      final r = await api.asistente(cuerpoConsejo(p['pregunta'] as String, datos));
      if (r == null) return; // el servidor no responde: se intenta después
      await db.responderPreguntaIA(p['id'] as String, r);
    }
  }

  /// Mensaje sugerido para WhatsApp. Con señal lo redacta la IA usando el
  /// marcador {nombre} (el nombre real NUNCA sale del celular); sin señal se
  /// usa la plantilla local.
  static Future<(String, bool)> mensajeParaCliente(
    ClienteSaldo c, {
    required RemoteApi? api,
    required Future<bool> Function() hayRed,
  }) async {
    final respaldo = mensajeSugerido(c);
    if (api == null || !api.haySesion || !await _red(hayRed)) {
      return (respaldo, false);
    }
    try {
      final r = await api.asistente({
        'modo': 'mensaje',
        'saldo': c.saldo > 0 ? c.saldo : 0,
      });
      if (r == null) return (respaldo, false);
      final nombre = primerNombre(c.nombre);
      var texto = r.contains('{nombre}')
          ? r.replaceAll('{nombre}', nombre)
          : 'Hola $nombre, $r';
      if (texto.length > 600) texto = texto.substring(0, 600);
      return (texto, true);
    } catch (_) {
      return (respaldo, false);
    }
  }

  /// Promoción redactada por la IA en la nube (solo viajan nombres de
  /// productos, precios, estilo y ocasión). Sin señal o sin IA activa
  /// devuelve null y la app usa el redactor local.
  static Future<String?> promocionIA(
    Map<String, dynamic> cuerpo, {
    required RemoteApi? api,
    required Future<bool> Function() hayRed,
  }) async {
    if (api == null || !api.haySesion || !await _red(hayRed)) return null;
    try {
      final r = await api.asistente(cuerpo);
      if (r == null || r.trim().isEmpty) return null;
      return r.length > 1200 ? r.substring(0, 1200) : r.trim();
    } catch (_) {
      return null;
    }
  }
}
