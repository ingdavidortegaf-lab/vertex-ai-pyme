import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/local_db.dart';
import '../domain/avisos.dart';
import '../domain/contabilidad.dart';

/// Avisos en el celular (notificaciones locales: no usan internet ni
/// servidores). Cada vez que cambia algo en la base (una venta, un ajuste
/// de inventario o lo que llega de otro celular) se revisa la situación y,
/// si hay algo nuevo, se avisa: producto agotado o por acabarse, clientes
/// que deben hace más de 30 días, meta cumplida o datos sin subir.
class Avisos {
  Avisos._();
  static final instance = Avisos._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _iniciado = false;
  bool _revisando = false;
  Timer? _espera;

  static const _canales = {
    'inventario': ('Inventario', 'Productos agotados o por acabarse'),
    'cobros': ('Cobros', 'Clientes con fiados vencidos'),
    'metas': ('Metas', 'Meta de ventas cumplida'),
    'sistema': ('Sincronización', 'Datos que no se pudieron subir'),
  };

  bool get _soportado =>
      !kIsWeb; // en la versión web no hay avisos del sistema

  Future<void> iniciar() async {
    if (_iniciado || !_soportado) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false),
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Abrir'),
          windows: WindowsInitializationSettings(
              appName: 'VERTEX AI Pyme',
              appUserModelId: 'VertexTech.VertexAIPyme',
              guid: '6b1f3c2e-8d4a-4f7b-9a51-2c7e0d9b4a13'),
        ),
      );
      _iniciado = true;
    } catch (_) {
      // Sin avisos en este equipo; la app sigue igual.
    }
  }

  /// Pide permiso (Android 13 o más pide confirmación al usuario).
  Future<void> pedirPermiso() async {
    await iniciar();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// Empieza a vigilar los cambios de la base.
  Future<void> vigilar() async {
    await iniciar();
    LocalDb.instance.cambios.addListener(_programar);
    _programar();
  }

  // Espera 2 s para agrupar varios cambios seguidos en una sola revisión.
  void _programar() {
    _espera?.cancel();
    _espera = Timer(const Duration(seconds: 2), revisar);
  }

  Future<void> revisar() async {
    if (_revisando) return;
    _revisando = true;
    try {
      final db = LocalDb.instance;
      final modo = db.modo.value;
      if (!modo.avisos) return;
      final ahora = DateTime.now();
      final previa = _leer(await db.ajuste('avisos_memoria'));
      final negocio = await db.perfilNegocio();
      final mes = await db.resumenPeriodo(DateTime(ahora.year, ahora.month),
          DateTime(ahora.year, ahora.month + 1));
      var vencidos = 0;
      var saldoVencido = 0.0;
      if (modo.fia) {
        for (final movs in (await db.creditoPorCliente()).values) {
          final e = estadoDeCuenta(movs, ahora);
          if (e.diasMora > 30) {
            vencidos++;
            saldoVencido += e.saldo - (e.edades['0-30'] ?? 0);
          }
        }
      }
      var porVencer = 0;
      var saldoPorVencer = 0.0;
      final limite = ahora.add(const Duration(days: 3));
      for (final c in await db.cuentasPorPagar()) {
        if (DateTime.parse(c['vence'] as String).isBefore(limite)) {
          porVencer++;
          saldoPorVencer += (c['saldo'] as num).toDouble();
        }
      }
      final r = revisarAvisos(
        previa: previa,
        productos: await db.productos(),
        ahora: ahora,
        ventasMes: mes.ventas,
        metaMes: negocio.meta,
        clientesVencidos: vencidos,
        saldoVencido: saldoVencido,
        erroresEnvio: await db.conError(),
        avisarCartera: modo.fia,
        pagosPorVencer: porVencer,
        saldoPorVencer: saldoPorVencer,
      );
      await db.setAjuste('avisos_memoria', _escribir(r.memoria));
      for (final a in r.avisos) {
        await _mostrar(a);
      }
    } catch (_) {
      // Un aviso nunca debe tumbar la app.
    } finally {
      _revisando = false;
    }
  }

  Future<void> _mostrar(Aviso a) async {
    if (!_iniciado) return;
    final (nombre, descripcion) = _canales[a.canal] ?? ('Avisos', '');
    try {
      await _plugin.show(
        id: a.id,
        title: a.titulo,
        body: a.cuerpo,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails('vertex_${a.canal}', nombre,
              channelDescription: descripcion,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(a.cuerpo)),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  static MemoriaAvisos _leer(String? s) {
    if (s == null || s.isEmpty) return const MemoriaAvisos();
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return MemoriaAvisos(
        agotados: {...(m['agotados'] as List? ?? const []).cast<String>()},
        bajos: {...(m['bajos'] as List? ?? const []).cast<String>()},
        metaMes: m['metaMes'] as String? ?? '',
        carteraDia: m['carteraDia'] as String? ?? '',
        errores: m['errores'] as int? ?? 0,
        proveedoresDia: m['proveedoresDia'] as String? ?? '',
      );
    } catch (_) {
      return const MemoriaAvisos();
    }
  }

  static String _escribir(MemoriaAvisos m) => jsonEncode({
        'agotados': m.agotados.toList(),
        'bajos': m.bajos.toList(),
        'metaMes': m.metaMes,
        'carteraDia': m.carteraDia,
        'errores': m.errores,
        'proveedoresDia': m.proveedoresDia,
      });
}
