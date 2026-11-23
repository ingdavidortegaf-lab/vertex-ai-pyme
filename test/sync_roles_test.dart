import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'soporte.dart';

void main() {
  late LocalDb db;
  late ServidorFalso srv;
  late SyncService sync;

  setUp(() async {
    db = await baseDePrueba();
    srv = ServidorFalso();
    sync = SyncService.instance
      ..db = db
      ..remoto = srv
      ..hayRed = () async => true;
  });

  /// Datos que ya están en la nube, subidos por el dueño desde otro celular.
  void datosDelDueno() {
    final ahora = DateTime.utc(2026, 11, 22).toIso8601String();
    srv.tablas['productos']!['p1'] = {
      'id': 'p1', 'nombre': 'Arroz', 'nombre_ts': ahora, 'precio': 2500, 'precio_ts': ahora,
      'costo': 2000, 'costo_ts': ahora, 'minimo': 0, 'minimo_ts': ahora, 'deleted': false,
      'deleted_ts': ahora, 'codigo': '', 'codigo_ts': ahora, 'unidad': 'und', 'unidad_ts': ahora,
      'updated_at': ahora, 'recibido_at': '2026-11-22T10:00:00.000Z',
    };
    srv.tablas['inventario']!['i1'] = {
      'id': 'i1', 'producto_id': 'p1', 'cantidad': 50, 'motivo': 'entrada', 'costo_unit': 2000,
      'fecha': ahora, 'recibido_at': '2026-11-22T10:00:01.000Z',
    };
    srv.tablas['clientes']!['c1'] = {
      'id': 'c1', 'nombre': 'Ana', 'nombre_ts': ahora, 'telefono': '', 'telefono_ts': ahora,
      'deleted': false, 'deleted_ts': ahora, 'updated_at': ahora, 'recibido_at': '2026-11-22T10:00:02.000Z',
    };
  }

  test('el despachador guarda su rol y baja productos e inventario sin costos, sin clientes', () async {
    datosDelDueno();
    srv.contextoRemoto = {'rol': 'despachador', 'despachador_fia': false, 'empresa_id': 'e1'};
    await sync.sync();

    expect(db.equipo.value.rol, Rol.despachador);
    expect(db.puede(Permiso.verCostos), isFalse);
    expect(srv.descargasDe, containsAll(['productos_operativos', 'inventario_operativo', 'ventas']));
    expect(srv.descargasDe, isNot(contains('productos')));
    expect(srv.descargasDe, isNot(contains('inventario')));
    expect(srv.descargasDe, isNot(contains('clientes')));

    final p = (await db.productos()).single;
    expect(p.precio, 2500);
    expect(p.stock, 50);
    expect(p.costo, 0, reason: 'el costo nunca llega al celular del despachador');
    expect(await db.clientes(), isEmpty);

    // El rol queda guardado: al abrir la app de nuevo se recuerda sin señal.
    db.equipo.value = const ContextoEquipo();
    await db.cargarModo();
    expect(db.equipo.value.rol, Rol.despachador);
  });

  test('si el dueño activa el fiado, el despachador empieza a bajar los clientes', () async {
    datosDelDueno();
    srv.contextoRemoto = {'rol': 'despachador', 'despachador_fia': true, 'empresa_id': 'e1'};
    await sync.sync();
    expect(db.puede(Permiso.venderFiado), isTrue);
    expect(srv.descargasDe, contains('clientes'));
    expect((await db.clientes()).single['nombre'], 'Ana');
  });

  test('el bodeguero baja solo productos e inventario, sin costos', () async {
    datosDelDueno();
    srv.contextoRemoto = {'rol': 'bodeguero', 'despachador_fia': false, 'empresa_id': 'e1'};
    await sync.sync();
    expect(srv.descargasDe.toSet(), {'productos_operativos', 'inventario_operativo'});
    expect((await db.productos()).single.costo, 0);
  });

  test('el dueño baja las tablas completas, con costos', () async {
    datosDelDueno();
    srv.contextoRemoto = {'rol': 'dueno', 'despachador_fia': false, 'empresa_id': 'e1'};
    await sync.sync();
    expect(srv.descargasDe.toSet(), {'clientes', 'ventas', 'productos', 'inventario'});
    expect((await db.productos()).single.costo, 2000);
  });

  test('con un servidor que aún no tiene mi_contexto, se sigue como dueño (como antes)', () async {
    datosDelDueno();
    srv.contextoRemoto = null;
    await sync.sync();
    expect(db.equipo.value.rol, Rol.dueno);
    expect(sync.estado.value, EstadoSync.sincronizado);
    expect((await db.productos()).single.costo, 2000);
  });
}
