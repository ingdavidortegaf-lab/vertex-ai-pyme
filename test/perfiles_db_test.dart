import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/domain/perfiles.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'soporte.dart';

void main() {
  late LocalDb db;
  // Pocas iteraciones en las pruebas para que corran rápido; el algoritmo es el mismo.
  const it = 50;

  setUp(() async => db = await baseDePrueba());

  test('crear perfiles: el PIN no queda en claro y el rol no supera al de la cuenta', () async {
    final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
    final fila = (await db.db.query('perfiles', where: 'id = ?', whereArgs: [luis])).single;
    expect(fila['pin_hash'], isNot(contains('2580')));
    expect((await db.perfiles()).single.nombre, 'Luis');

    expect(() => db.crearPerfil('Ana', Rol.contador, '1234', iteraciones: it), throwsArgumentError,
        reason: 'PIN de números seguidos');
    expect(() => db.crearPerfil('luis', Rol.despachador, '2580', iteraciones: it), throwsStateError,
        reason: 'nombre repetido');

    db.equipo.value = const ContextoEquipo(rol: Rol.despachador);
    expect(() => db.crearPerfil('Marta', Rol.administrador, '9051', iteraciones: it), throwsArgumentError,
        reason: 'una cuenta de despachador no crea un administrador');
  });

  test('entrar con PIN, permiso efectivo y salir', () async {
    final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
    expect(db.puede(Permiso.verCostos), isTrue, reason: 'la dueña, sin perfil activo');
    expect(await db.entrarComo(luis, '0000'), isFalse);
    expect(db.perfilActivo.value, isNull);
    expect(await db.entrarComo(luis, '2580'), isTrue);
    expect(db.perfilActivo.value!.nombre, 'Luis');
    expect(db.puede(Permiso.verCostos), isFalse, reason: 'atiende Luis, despachador');
    expect(db.puede(Permiso.venderContado), isTrue);
    db.salirPerfil();
    expect(db.puede(Permiso.verCostos), isTrue);
  });

  test('tras 5 PIN equivocados hay que esperar, aunque el sexto sea el correcto', () async {
    var ahora = DateTime(2026, 11, 22, 10);
    db.reloj = () => ahora;
    final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
    for (var i = 0; i < intentosAntesDeEsperar; i++) {
      expect(await db.entrarComo(luis, '1111'), isFalse);
    }
    expect(await db.esperaPin(), greaterThan(0));
    expect(await db.entrarComo(luis, '2580'), isFalse, reason: 'bloqueado');
    ahora = ahora.add(esperaTrasFallos + const Duration(seconds: 1));
    expect(await db.esperaPin(), 0);
    expect(await db.entrarComo(luis, '2580'), isTrue);
    db.reloj = DateTime.now;
  });

  test('cada venta guarda quién la hizo; sin perfil, la nube recibe lo mismo que antes', () async {
    await db.saveMovimiento('Venta sin perfil', 1000);
    var cola = await db.colaLista();
    expect(jsonDecode(cola.last['payload'] as String), isNot(contains('perfil')));

    final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
    await db.entrarComo(luis, '2580');
    final arroz = await db.saveProducto('Arroz', precio: 2500, costo: 2000, stockInicial: 10);
    await db.saveVentaProductos([
      ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 2, precio: 2500, costo: 2000, unidad: 'und')
    ]);
    await db.saveMovimiento('Venta rápida', 3000);

    final movs = await db.movimientos();
    expect(movs.where((m) => m['perfil'] == 'Luis').length, 2);
    expect(movs.singleWhere((m) => m['concepto'] == 'Venta sin perfil')['perfil'], '');
    cola = await db.colaLista();
    final ventas = cola.where((c) => c['tabla'] == 'ventas').map((c) => jsonDecode(c['payload'] as String)).toList();
    expect(ventas.where((v) => v['perfil'] == 'Luis').length, 2);
  });

  test('quitar un perfil: si estaba atendiendo, se sale; sus ventas conservan el nombre', () async {
    final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
    await db.entrarComo(luis, '2580');
    await db.saveMovimiento('Venta', 1000);
    await db.quitarPerfil(luis);
    expect(db.perfilActivo.value, isNull);
    expect(await db.perfiles(), isEmpty);
    expect((await db.movimientos()).single['perfil'], 'Luis');
  });

  test('una base v8 sube a v9 sin perder ventas', () async {
    sqfliteFfiInit();
    final v8 = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await v8.execute('''CREATE TABLE ventas(id TEXT PRIMARY KEY, cliente_id TEXT, concepto TEXT NOT NULL,
      monto REAL NOT NULL, tipo TEXT NOT NULL, credito INTEGER NOT NULL DEFAULT 0, fecha TEXT NOT NULL,
      sync TEXT NOT NULL DEFAULT 'pendiente', pagos TEXT, tercero_id TEXT)''');
    await v8.insert('ventas', {'id': 'v1', 'concepto': 'Venta vieja', 'monto': 500, 'tipo': 'ingreso', 'fecha': 't'});
    await LocalDb.migrar(v8, 8, 9);
    expect((await v8.query('ventas')).single['perfil'], '');
    expect(await v8.query('perfiles'), isEmpty);
    await v8.close();
  });
}
