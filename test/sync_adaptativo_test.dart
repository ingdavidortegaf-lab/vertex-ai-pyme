import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'soporte.dart';

/// Con muchas tiendas, consultar la nube cada 30 s aunque no haya cambios
/// la satura. Esta prueba comprueba la descarga adaptativa.
void main() {
  test('sin cambios consulta cada vez menos; con cambios vuelve a 30 s; lo guardado sube ya',
      () async {
    final db = await baseDePrueba();
    final srv = ServidorFalso();
    var ahora = DateTime(2030, 1, 1, 8);
    final sync = SyncService.instance
      ..db = db
      ..remoto = srv
      ..hayRed = (() async => true)
      ..reloj = (() => ahora)
      ..pullCada = SyncService.pullMin;

    await sync.sync(porTiempo: true); // primera vez: descarga las 4 tablas
    expect(srv.consultas, 4);
    expect(sync.pullCada, const Duration(seconds: 60));

    ahora = ahora.add(const Duration(seconds: 30));
    await sync.sync(porTiempo: true); // todavía no toca
    expect(srv.consultas, 4);

    ahora = ahora.add(const Duration(seconds: 31));
    await sync.sync(porTiempo: true); // ya toca; la próxima en 2 min
    expect(srv.consultas, 8);
    expect(sync.pullCada, const Duration(minutes: 2));

    for (var i = 0; i < 6; i++) {
      ahora = ahora.add(sync.pullCada);
      await sync.sync(porTiempo: true);
    }
    expect(sync.pullCada, SyncService.pullMax); // tope: 5 min

    // Otro celular registró algo: vuelve a consultar cada 30 s.
    srv.tablas['ventas']!['22222222-2222-4222-8222-222222222222'] = {
      'id': '22222222-2222-4222-8222-222222222222',
      'concepto': 'Venta del otro celular',
      'monto': 5000,
      'tipo': 'ingreso',
      'credito': false,
      'fecha': ahora.toUtc().toIso8601String(),
      'recibido_at': '2099-01-01T00:00:00Z',
    };
    ahora = ahora.add(SyncService.pullMax);
    await sync.sync(porTiempo: true);
    expect(sync.pullCada, SyncService.pullMin);

    // Lo que el tendero guarda se sube enseguida, aunque no toque descargar.
    final antes = srv.envios;
    final consultasAntes = srv.consultas;
    await db.saveMovimiento('Venta', 1000);
    await sync.sync();
    expect(srv.envios, antes + 1);
    expect(srv.consultas, greaterThan(consultasAntes)); // y al guardar también trae lo nuevo
    sync.reloj = DateTime.now;
  });
}
