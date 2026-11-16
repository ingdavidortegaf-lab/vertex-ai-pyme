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

  bool _syncing = false;
  bool _otraVez = false;
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
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
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
  Future<void> sync() async {
    if (_syncing) {
      _otraVez = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _otraVez = false;
        await _ciclo();
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
        } on RechazoServidor catch (e) {
          await db.marcarFallo(n, tabla, id, item['intentos'] as int, e.codigo);
        }
        await _contar();
      }
      await _descargar(api);
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

  Future<void> _descargar(RemoteApi api) async {
    for (final tabla in const ['clientes', 'ventas']) {
      var cursor = await db.ajuste('pull_$tabla');
      while (true) {
        final filas = await api.descargar(tabla, cursor, _lote);
        if (filas.isEmpty) break;
        if (tabla == 'clientes') {
          await db.aplicarClientesRemotos(filas);
        } else {
          await db.aplicarVentasRemotas(filas);
        }
        final ultimo = filas.last['recibido_at'];
        if (ultimo is! String) break;
        cursor = ultimo;
        await db.setAjuste('pull_$tabla', cursor);
        if (filas.length < _lote) break;
      }
    }
  }
}
