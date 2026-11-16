import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/data/local_db.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'soporte.dart';

void main() {
  late LocalDb db;
  late ServidorFalso srv;
  late SyncService sync;
  var red = true;

  setUp(() async {
    db = await baseDePrueba();
    srv = ServidorFalso();
    red = true;
    sync = SyncService.instance
      ..db = db
      ..remoto = srv
      ..hayRed = () async => red;
  });

  Future<void> datosDeDemo() async {
    final ana = await db.saveCliente('Ana', '573001234567');
    await db.saveCliente('Luis', '');
    await db.saveMovimiento('Venta', 20000, clienteId: ana);
    await db.saveMovimiento('Fiado', 30000, credito: true, clienteId: ana);
    await db.saveMovimiento('Arriendo', 5000, tipo: 'egreso');
  }

  test('modo avión: todo queda en cola y nada se pierde', () async {
    red = false;
    await datosDeDemo();
    await sync.sync();
    expect(sync.estado.value, EstadoSync.sinConexion);
    expect(sync.pendientes.value, 5);
    expect(textoEstado(sync.estado.value, 5, 0), 'Sin conexión · 5 pendientes');
    expect(srv.envios, 0);
  });

  test('al volver la señal se envía todo una sola vez', () async {
    red = false;
    await datosDeDemo();
    await sync.sync();
    red = true;
    await sync.sync();
    expect(sync.estado.value, EstadoSync.sincronizado);
    expect(textoEstado(sync.estado.value, 0, 0), 'Sincronizado');
    expect(sync.pendientes.value, 0);
    expect(srv.tablas['clientes'], hasLength(2));
    expect(srv.tablas['ventas'], hasLength(3));
    final estados = await db.db.rawQuery(
        'SELECT sync FROM clientes UNION ALL SELECT sync FROM ventas');
    expect(estados.every((e) => e['sync'] == 'enviado'), isTrue);

    // Sincronizar otra vez no duplica nada.
    await sync.sync();
    expect(srv.tablas['ventas'], hasLength(3));
  });

  test('se cae la red a mitad del envío: se reanuda sin duplicar', () async {
    await datosDeDemo();
    srv.fallarRedEnEnvio = 3;
    await sync.sync();
    expect(sync.estado.value, EstadoSync.servidorNoResponde);
    expect(srv.tablas['clientes']!.length + srv.tablas['ventas']!.length, 2);
    expect(await db.pendientes(), 3);

    srv.fallarRedEnEnvio = null;
    await sync.sync();
    expect(srv.tablas['clientes'], hasLength(2));
    expect(srv.tablas['ventas'], hasLength(3));
    expect(await db.pendientes(), 0);
  });

  test('la app se cierra tras guardar en el servidor: reenviar no duplica',
      () async {
    await datosDeDemo();
    // Simula que el servidor ya recibió todo pero la cola no se borró.
    for (final item in await db.colaLista()) {
      await srv.enviar(item['tabla'] as String,
          Map<String, dynamic>.from(_decode(item['payload'] as String)));
    }
    await sync.sync();
    expect(srv.tablas['ventas'], hasLength(3));
    expect(srv.tablas['clientes'], hasLength(2));
    expect(await db.pendientes(), 0);
  });

  test('un registro rechazado espera y no bloquea a los demás', () async {
    await datosDeDemo();
    final rechazado = (await db.colaLista())[2]['registro_id'] as String;
    srv.rechazar.add(rechazado);
    await sync.sync();
    expect(srv.tablas['ventas'], hasLength(2)); // los otros sí pasaron
    expect(await db.pendientes(), 1);
    expect(await db.colaLista(), isEmpty); // espera su turno (15 s)
    expect(sync.estado.value, EstadoSync.reintentando);

    // Pasan los reintentos con espera creciente hasta apartarlo.
    var ahora = DateTime.now();
    for (var i = 0; i < LocalDb.maxIntentos; i++) {
      ahora = ahora.add(const Duration(hours: 1));
      final t = ahora;
      db.reloj = () => t;
      await sync.sync();
    }
    expect(await db.conError(), 1);
    expect(sync.estado.value, EstadoSync.conErrores);
    final fila = (await db.db.query('ventas',
            where: 'id = ?', whereArgs: [rechazado]))
        .single;
    expect(fila['sync'], 'error'); // apartado, NO borrado

    // Si el servidor ya lo acepta, "reintentar" lo envía.
    srv.rechazar.clear();
    await sync.reintentarErrores();
    expect(srv.tablas['ventas'], hasLength(3));
    expect(await db.conError(), 0);
  });

  test('sesión vencida: la cola queda intacta', () async {
    await datosDeDemo();
    srv.sesionVencida = true;
    await sync.sync();
    expect(sync.estado.value, EstadoSync.sesionVencida);
    expect(await db.pendientes(), 5);
  });

  test('sin sesión: pide iniciar sesión y no envía', () async {
    await datosDeDemo();
    srv.sesion = false;
    await sync.sync();
    expect(sync.estado.value, EstadoSync.sinSesion);
    expect(srv.envios, 0);
  });

  test('descarga cambios de otro celular y une clientes por campo', () async {
    final id = await db.saveCliente('Ana', '573001111111');
    await sync.sync();

    // Otro celular cambia el teléfono (más reciente) en el servidor.
    final remoto = Map<String, dynamic>.from(srv.tablas['clientes']![id]!);
    remoto['telefono'] = '573002222222';
    remoto['telefono_ts'] =
        DateTime.now().toUtc().add(const Duration(minutes: 1)).toIso8601String();
    await srv.enviar('clientes', remoto);
    // Y registra una venta.
    await srv.enviar('ventas', {
      'id': '00000000-0000-4000-8000-000000000001',
      'cliente_id': id,
      'concepto': 'Venta en otro celular',
      'monto': 15000,
      'tipo': 'ingreso',
      'credito': false,
      'fecha': DateTime.now().toUtc().toIso8601String(),
    });

    await sync.sync();
    final c = (await db.db.query('clientes')).single;
    expect(c['nombre'], 'Ana');
    expect(c['telefono'], '573002222222');
    expect(await db.movimientos(), hasLength(1));
    expect(sync.estado.value, EstadoSync.sincronizado);
  });

  test('preguntas para la IA en cola se responden al volver la señal', () async {
    await db.guardarPreguntaIA('¿Cómo vendo más?');
    srv.respuestaIA = 'Ofrece combos a tus clientes frecuentes.';
    await sync.sync();
    final p = (await db.preguntasIA()).single;
    expect(p['estado'], 'respondida');
    expect(p['respuesta'], contains('combos'));
  });

  test('modo local (sin nube configurada)', () async {
    sync.remoto = null;
    await datosDeDemo();
    await sync.sync();
    expect(sync.estado.value, EstadoSync.soloLocal);
  });
}

Map<String, Object?> _decode(String s) =>
    Map<String, Object?>.from(jsonDecode(s) as Map);
