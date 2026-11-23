import '../domain/roles.dart';
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'asistente_service.dart';
import 'local_db.dart';
import 'remote_api.dart';

enum EstadoSync {
  soloLocal,
  sinConexion,
  sinSesion,
  sesionVencida,
  sincronizando,
  sincronizado,
  reintentando,
  conErrores,
  servidorNoResponde,
}

/// Texto de la barra de estado (lo que ve el usuario).
String textoEstado(EstadoSync e, int pendientes, int errores) {
  switch (e) {
    case EstadoSync.soloLocal:
      return 'Modo local · todo se guarda en este celular';
    case EstadoSync.sinConexion:
      return 'Sin conexión · $pendientes pendientes';
    case EstadoSync.sinSesion:
      return 'Inicia sesión para sincronizar · $pendientes pendientes';
    case EstadoSync.sesionVencida:
      return 'Tu sesión venció, inicia sesión · $pendientes pendientes';
    case EstadoSync.sincronizando:
      return 'Sincronizando…';
    case EstadoSync.sincronizado:
      return 'Sincronizado';
    case EstadoSync.reintentando:
      return 'Se reintentará en un momento · $pendientes pendientes';
    case EstadoSync.conErrores:
      return '$errores sin enviar · toca para reintentar';
    case EstadoSync.servidorNoResponde:
      return 'El servidor no responde · $pendientes pendientes';
  }
}

/// Envía la cola en orden cuando hay conexión y luego descarga los cambios
/// de otros celulares de la empresa.
/// - Envío idempotente (upsert por id): si la app se cierra después de que
///   el servidor guardó pero antes de borrar de la cola, al reenviar no se
///   duplica nada.
/// - Error de red: la cola queda intacta y se reintenta (cada 30 s y al
///   volver la red).
/// - Rechazo del servidor: ese registro espera (15 s, 30 s, 1 min…) y tras
///   5 intentos queda apartado como "error", sin bloquear al resto ni
///   borrarse.
class SyncService {
  SyncService._();
  static final instance = SyncService._();

  LocalDb db = LocalDb.instance;
  RemoteApi? remoto;
  Future<bool> Function() hayRed = _hayRedReal;

  final estado = ValueNotifier<EstadoSync>(EstadoSync.soloLocal);
  final pendientes = ValueNotifier<int>(0);
  final errores = ValueNotifier<int>(0);

  /// Registros subidos desde la última vez que el usuario miró la barra.
  /// Se queda a la vista hasta que la toca.
  final subidos = ValueNotifier<int>(0);
  void verSubidos() => subidos.value = 0;

  bool _syncing = false;
  bool _otraVez = false;
  bool _porTiempo = false;

  /// Descarga adaptativa (para que muchas tiendas no saturen la nube): si no
  /// llega nada nuevo de otros celulares, la siguiente consulta automática
  /// espera el doble (30 s, 1, 2, 4… hasta 5 min). Cuando llega algo, vuelve
  /// a 30 s. Lo que el tendero guarda se sube siempre de inmediato, y al
  /// volver la señal o abrir la app se descarga enseguida.
  static const pullMin = Duration(seconds: 30);
  static const pullMax = Duration(minutes: 5);
  Duration pullCada = pullMin;
  DateTime _proximoPull = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime Function() reloj = DateTime.now;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  static Future<bool> _hayRedReal() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((x) => x != ConnectivityResult.none);
  }

  void start() {
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((_) => sync());
    _timer?.cancel();
    _timer = Timer.periodic(pullMin, (_) => sync(porTiempo: true));
    sync();
  }

  void stop() {
    _sub?.cancel();
    _timer?.cancel();
  }

  Future<void> reintentarErrores() async {
    await db.reintentarErrores();
    await sync();
  }

  /// Si ya hay una sincronización corriendo, se repite al terminar (así un
  /// registro guardado durante el envío no espera al siguiente ciclo).
  /// [porTiempo]: llamada del reloj de 30 s; solo descarga si ya toca.
  Future<void> sync({bool porTiempo = false}) async {
    if (_syncing) {
      _otraVez = true;
      return;
    }
    _syncing = true;
    try {
      _porTiempo = porTiempo;
      do {
        _otraVez = false;
        await _ciclo();
        _porTiempo = false;
      } while (_otraVez);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _contar() async {
    try {
      pendientes.value = await db.pendientes();
      errores.value = await db.conError();
    } catch (_) {}
  }

  Future<void> _ciclo() async {
    try {
      await _contar();
      final api = remoto;
      if (api == null) {
        estado.value = EstadoSync.soloLocal;
        return;
      }
      bool red;
      try {
        red = await hayRed();
      } catch (_) {
        red = false;
      }
      if (!red) {
        estado.value = EstadoSync.sinConexion;
        return;
      }
      if (!api.haySesion) {
        estado.value = EstadoSync.sinSesion;
        return;
      }
      // Primero el rol y el negocio: si esta cuenta ya no es de este negocio,
      // lo pendiente no debe subirse al nuevo.
      await _actualizarContexto(api);
      final cola = await db.colaLista();
      if (cola.isNotEmpty) estado.value = EstadoSync.sincronizando;
      for (final item in cola) {
        final n = item['n'] as int;
        final tabla = item['tabla'] as String;
        final id = item['registro_id'] as String;
        final fila = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
        try {
          await api.enviar(tabla, fila);
          await db.confirmarEnvio(n, tabla, id);
          subidos.value++;
        } on RechazoServidor catch (e) {
          await db.marcarFallo(n, tabla, id, item['intentos'] as int, e.codigo);
        }
        await _contar();
      }
      if (!_porTiempo || !reloj().isBefore(_proximoPull)) {
        final llegaron = await _descargar(api);
        pullCada = llegaron > 0
            ? pullMin
            : Duration(seconds: (pullCada.inSeconds * 2).clamp(pullMin.inSeconds, pullMax.inSeconds));
        _proximoPull = reloj().add(pullCada);
      }
      await _contar();
      if (errores.value > 0) {
        estado.value = EstadoSync.conErrores;
      } else if (pendientes.value > 0) {
        estado.value = EstadoSync.reintentando;
      } else {
        estado.value = EstadoSync.sincronizado;
      }
      // Lo que necesita internet y quedó en cola (preguntas a la IA).
      try {
        await AsistenteService.procesarPendientes(api, db);
      } catch (_) {}
    } on SesionVencida {
      estado.value = EstadoSync.sesionVencida;
    } catch (_) {
      estado.value = EstadoSync.servidorNoResponde;
    } finally {
      await _contar();
    }
  }

  static const _lote = 500;

  /// Pregunta al servidor el rol de este usuario. Si el servidor todavía no
  /// tiene la función (o la rechaza), se sigue con el rol que ya se sabía.
  /// Si la cuenta ya es de otro negocio (el dueño la quitó del equipo), lo
  /// del negocio anterior se borra de este celular.
  Future<void> _actualizarContexto(RemoteApi api) async {
    try {
      final c = await api.contexto();
      if (c == null) return;
      final nuevo = ContextoEquipo.desdeServidor(c);
      final antes = db.equipo.value.empresaId;
      if (antes.isNotEmpty && nuevo.empresaId.isNotEmpty && antes != nuevo.empresaId) {
        await db.cambiarDeNegocio(nuevo);
      } else {
        await db.guardarContexto(nuevo);
      }
    } on RechazoServidor {
      // Servidor sin la función mi_contexto: no cambia nada.
    }
  }

  /// Devuelve cuántos registros nuevos llegaron. Cada rol baja solo lo que
  /// puede ver (despachador y bodeguero, desde las vistas sin costos).
  Future<int> _descargar(RemoteApi api) async {
    var total = 0;
    for (final (tabla, fuente) in fuentesDescarga(db.equipo.value)) {
      var cursor = await db.ajuste('pull_$tabla');
      while (true) {
        final filas = await api.descargar(fuente, cursor, _lote);
        if (filas.isEmpty) break;
        total += filas.length;
        switch (tabla) {
          case 'clientes':
            await db.aplicarClientesRemotos(filas);
          case 'ventas':
            await db.aplicarVentasRemotas(filas);
          case 'productos':
            await db.aplicarProductosRemotos(filas);
          case 'turnos':
            await db.aplicarTurnosRemotos(filas);
          default:
            await db.aplicarInventarioRemoto(filas);
        }
        final ultimo = filas.last['recibido_at'];
        if (ultimo is! String) break;
        cursor = ultimo;
        await db.setAjuste('pull_$tabla', cursor);
        if (filas.length < _lote) break;
      }
    }
    return total;
  }
}
