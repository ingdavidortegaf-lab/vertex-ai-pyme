import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/data/facturacion_service.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';
import 'package:vertex_ai_pyme/domain/facturacion.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'soporte.dart';

/// Proveedor de mentiras, solo para pruebas: la app no trae uno real.
class ProveedorDePrueba implements ProveedorFacturacion {
  bool sinRed = false;
  bool aceptarSinCufe = false;
  EstadoFE alEmitir = EstadoFE.enviado;
  EstadoFE alConsultar = EstadoFE.aceptado;
  final recibidas = <FacturaElectronica>[];

  @override
  String get nombre => 'Prueba';
  @override
  bool get configurado => true;

  @override
  Future<RespuestaFE> emitir(FacturaElectronica f) async {
    if (sinRed) throw const SinRespuestaFE();
    recibidas.add(f);
    return RespuestaFE(estado: alEmitir, idExterno: 'ext-${f.numero}', mensaje: alEmitir == EstadoFE.rechazado ? 'NIT del comprador inválido' : '');
  }

  @override
  Future<RespuestaFE> consultar(String idExterno) async {
    if (sinRed) throw const SinRespuestaFE();
    return alConsultar == EstadoFE.aceptado
        ? RespuestaFE(
            estado: EstadoFE.aceptado,
            idExterno: idExterno,
            cufe: aceptarSinCufe ? null : 'CUFE-DE-PRUEBA-$idExterno',
            qr: aceptarSinCufe ? null : 'https://qr.prueba/$idExterno')
        : RespuestaFE(estado: alConsultar, idExterno: idExterno);
  }
}

void main() {
  late LocalDb db;
  // Datos inventados para la prueba (el dueño escribe los reales).
  final emisor = DatosEmisor(
    razonSocial: 'Tienda de Prueba S.A.S.',
    nit: '900123456',
    dv: '1',
    direccion: 'Calle 1 # 2-3',
    municipio: 'Ciudad de prueba',
    correo: 'tienda@prueba.local',
    resolucion: '000000',
    prefijo: 'PRU',
    desde: 1,
    hasta: 3,
    vigenteHasta: DateTime(2099, 12, 31),
  );

  setUp(() async => db = await baseDePrueba());

  Future<String> clienteConDocumento() =>
      db.saveCliente('Ana Pérez', '3001234567', tipoDoc: 'CC', documento: '1020304050', correo: 'ana@prueba.local');

  group('cálculos (dominio)', () {
    test('el precio cobrado trae el IVA: se separa en base e impuesto', () {
      const l = LineaFE(descripcion: 'X', cantidad: 2, unidad: 'und', precioConIva: 5500, ivaPct: 10);
      expect(l.total, 11000);
      expect(l.base, 10000);
      expect(l.iva, 1000);
      const exento = LineaFE(descripcion: 'Y', cantidad: 1, unidad: 'und', precioConIva: 3000, ivaPct: 0);
      expect(exento.iva, 0);
    });

    test('numeración: empieza en «desde», no pasa de «hasta» ni de la vigencia', () {
      final hoy = DateTime(2026, 11, 24);
      expect(siguienteNumero(emisor, null, hoy).numero, 1);
      expect(siguienteNumero(emisor, 2, hoy).numero, 3);
      expect(siguienteNumero(emisor, 3, hoy).error, contains('acabó'));
      final vencida = DatosEmisor.desdeAjustes({...emisor.aAjustes(), 'fe_vigente_hasta': '2026-11-23'});
      expect(siguienteNumero(vencida, null, hoy).error, contains('vencida'));
      expect(const DatosEmisor().faltantes(), contains('NIT'));
      expect(emisor.faltantes(), isEmpty);
    });

    test('la factura guardada en la cola se vuelve a armar igual', () {
      final f = FacturaElectronica(
        id: 'f1',
        ventaId: 'v1',
        numero: 'PRU1',
        fecha: DateTime.utc(2026, 11, 24, 15),
        emisor: emisor,
        comprador: const CompradorFE(nombre: 'Ana', tipoDoc: 'CC', documento: '1020304050'),
        lineas: const [LineaFE(descripcion: 'X', cantidad: 1, unidad: 'und', precioConIva: 1100, ivaPct: 10)],
      );
      final g = facturaDesdeMapa(f.aMapa());
      expect(g.numero, 'PRU1');
      expect(g.total, 1100);
      expect(g.iva, 100);
      expect(g.emisor.nit, '900123456');
      expect(g.ivaPorTarifa[10.0]!.base, 1000);
    });
  });

  group('armar la factura de una venta', () {
    test('sin los datos del negocio o sin documento del cliente, explica qué falta', () async {
      final v = await db.saveMovimiento('Venta', 5000);
      await expectLater(db.encolarFactura(v, ivaSinProductos: 0),
          throwsA(isA<ErrorFactura>().having((e) => e.mensaje, 'm', contains('Faltan datos del negocio'))));
      await db.guardarEmisor(emisor);
      await expectLater(db.encolarFactura(v, ivaSinProductos: 0),
          throwsA(isA<ErrorFactura>().having((e) => e.mensaje, 'm', contains('documento'))));
    });

    test('con productos: usa el IVA de cada producto; si falta alguno, lo dice', () async {
      await db.guardarEmisor(emisor);
      final ana = await clienteConDocumento();
      final arroz = await db.saveProducto('Arroz', precio: 2500, costo: 2000, stockInicial: 10, iva: 0);
      final gaseosa = await db.saveProducto('Gaseosa', precio: 3300, costo: 2000, stockInicial: 10);
      final v = await db.saveVentaProductos([
        ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 2, precio: 2500, costo: 2000, unidad: 'und'),
        ItemVenta(productoId: gaseosa, nombre: 'Gaseosa', cantidad: 1, precio: 3300, costo: 2000, unidad: 'und'),
      ], clienteId: ana, fiado: true);
      await expectLater(db.encolarFactura(v),
          throwsA(isA<ErrorFactura>().having((e) => e.mensaje, 'm', contains('Gaseosa'))));
      await db.saveProducto('Gaseosa', precio: 3300, costo: 2000, iva: 10, id: gaseosa);
      final f = await db.encolarFactura(v);
      expect(f.numero, 'PRU1');
      expect(f.estado, EstadoFE.pendiente);
      expect(f.total, 8300);
      await expectLater(db.encolarFactura(v), throwsA(isA<ErrorFactura>()), reason: 'una sola por venta');
    });

    test('con descuento la factura suma lo que se cobró', () async {
      await db.guardarEmisor(emisor);
      final ana = await clienteConDocumento();
      final p = await db.saveProducto('Aceite', precio: 10000, costo: 7000, stockInicial: 5, iva: 10);
      final v = await db.saveVentaProductos(
          [ItemVenta(productoId: p, nombre: 'Aceite', cantidad: 2, precio: 10000, costo: 7000, unidad: 'und')],
          clienteId: ana, fiado: true, descuento: 2000);
      expect((await db.encolarFactura(v)).total, 18000);
    });

    test('sin productos pide el IVA; la numeración avanza y se acaba', () async {
      await db.guardarEmisor(emisor);
      final ana = await clienteConDocumento();
      final ids = [for (var i = 0; i < 4; i++) await db.saveMovimiento('Servicio $i', 1000, credito: true, clienteId: ana)];
      await expectLater(db.encolarFactura(ids[0]), throwsA(isA<ErrorFactura>()));
      expect((await db.encolarFactura(ids[0], ivaSinProductos: 0)).numero, 'PRU1');
      expect((await db.encolarFactura(ids[1], ivaSinProductos: 0)).numero, 'PRU2');
      expect((await db.encolarFactura(ids[2], ivaSinProductos: 0)).numero, 'PRU3');
      await expectLater(db.encolarFactura(ids[3], ivaSinProductos: 0),
          throwsA(isA<ErrorFactura>().having((e) => e.mensaje, 'm', contains('acabó'))));
    });

    test('una venta facturada no se anula con anulación simple; una anulada no se factura', () async {
      await db.guardarEmisor(emisor);
      final ana = await clienteConDocumento();
      final v = await db.saveMovimiento('Venta', 5000, credito: true, clienteId: ana);
      await db.encolarFactura(v, ivaSinProductos: 0);
      await expectLater(db.anular(v), throwsA(isA<StateError>().having((e) => e.message, 'm', 'facturada')));
      final w = await db.saveMovimiento('Otra', 2000, credito: true, clienteId: ana);
      await db.anular(w);
      await expectLater(db.encolarFactura(w, ivaSinProductos: 0), throwsA(isA<ErrorFactura>()));
    });

    test('el despachador no emite facturas electrónicas', () async {
      await db.guardarEmisor(emisor);
      final v = await db.saveMovimiento('Venta', 5000);
      db.equipo.value = const ContextoEquipo(rol: Rol.despachador);
      await expectLater(db.encolarFactura(v, ivaSinProductos: 0), throwsA(isA<ErrorFactura>()));
    });

    test('solo se quita de la cola la última pendiente (sin huecos en la numeración)', () async {
      await db.guardarEmisor(emisor);
      final ana = await clienteConDocumento();
      final a = await db.encolarFactura(await db.saveMovimiento('A', 1000, credito: true, clienteId: ana), ivaSinProductos: 0);
      final b = await db.encolarFactura(await db.saveMovimiento('B', 1000, credito: true, clienteId: ana), ivaSinProductos: 0);
      expect(await db.quitarFacturaPendiente(a.id), isFalse);
      expect(await db.quitarFacturaPendiente(b.id), isTrue);
      expect((await db.facturas()).single.numero, 'PRU1');
    });
  });

  group('cola de emisión', () {
    late ProveedorDePrueba prov;
    late String fid;

    setUp(() async {
      prov = ProveedorDePrueba();
      await db.guardarEmisor(emisor);
      final ana = await clienteConDocumento();
      final v = await db.saveMovimiento('Venta', 11000, credito: true, clienteId: ana);
      fid = (await db.encolarFactura(v, ivaSinProductos: 10)).id;
    });

    Future<FacturaEmitida> estado() async => (await db.facturas()).single;

    test('sin proveedor la factura espera en la cola y lo dice', () async {
      await FacturacionService.procesarCola(db, const SinProveedor());
      expect((await estado()).estado, EstadoFE.pendiente);
      expect((await estado()).mensaje, FacturacionService.sinProveedor);
    });

    test('sin internet sigue pendiente; con internet se envía y luego llega el CUFE', () async {
      prov.sinRed = true;
      await FacturacionService.procesarCola(db, prov);
      expect((await estado()).estado, EstadoFE.pendiente);
      prov.sinRed = false;
      await FacturacionService.procesarCola(db, prov);
      expect((await estado()).estado, EstadoFE.enviado);
      expect(prov.recibidas.single.iva, 1000);
      await FacturacionService.procesarCola(db, prov);
      final f = await estado();
      expect(f.estado, EstadoFE.aceptado);
      expect(f.aceptada, isTrue);
      expect(f.cufe, startsWith('CUFE-DE-PRUEBA'));
      expect(f.qr, isNotEmpty);
      await FacturacionService.procesarCola(db, prov);
      expect(prov.recibidas, hasLength(1), reason: 'una aceptada no se vuelve a enviar');
    });

    test('«aceptada» sin CUFE no cuenta: se sigue consultando', () async {
      prov.aceptarSinCufe = true;
      await FacturacionService.procesarCola(db, prov);
      await FacturacionService.procesarCola(db, prov);
      expect((await estado()).estado, EstadoFE.enviado);
    });

    test('rechazada: queda el motivo y se puede reintentar con el mismo número', () async {
      prov.alEmitir = EstadoFE.rechazado;
      await FacturacionService.procesarCola(db, prov);
      var f = await estado();
      expect(f.estado, EstadoFE.rechazado);
      expect(f.mensaje, contains('NIT'));
      await db.reintentarFactura(f.id);
      f = await estado();
      expect(f.estado, EstadoFE.pendiente);
      expect(f.id, fid);
      expect(f.numero, 'PRU1');
    });

    test('la sincronización procesa la cola con el proveedor configurado', () async {
      final sync = SyncService.instance
        ..db = db
        ..remoto = ServidorFalso()
        ..hayRed = (() async => true)
        ..facturador = prov;
      await sync.sync();
      expect((await estado()).estado, EstadoFE.enviado);
      sync.facturador = const SinProveedor();
    });
  });

  group('IVA por producto', () {
    test('editar sin decir el IVA lo conserva; se une por campo con la nube', () async {
      final p = await db.saveProducto('Leche', precio: 4000, iva: 5);
      await db.saveProducto('Leche', precio: 4200, id: p);
      expect((await db.productos()).single.iva, 5);
      expect(() => db.saveProducto('Mal', precio: 1, iva: 150), throwsArgumentError);
      final nuevo = (await db.productos()).single;
      expect(nuevo.precio, 4200);

      final local = ProductoCampos.fromRemote({
        'id': 'x', 'nombre': 'A', 'nombre_ts': '2026-11-01T00:00:00Z', 'precio': 1, 'precio_ts': '2026-11-01T00:00:00Z',
        'iva': 0, 'iva_ts': '2026-11-02T00:00:00Z',
      });
      final remoto = ProductoCampos.fromRemote({
        'id': 'x', 'nombre': 'A', 'nombre_ts': '2026-11-01T00:00:00Z', 'precio': 1, 'precio_ts': '2026-11-01T00:00:00Z',
        'iva': 10, 'iva_ts': '2026-11-03T00:00:00Z',
      });
      expect(local.merge(remoto).iva, 10);
      expect(remoto.merge(local).iva, 10);
      expect(ProductoCampos.fromRemote({'id': 'y', 'nombre': 'B', 'precio': 1}).iva, -1, reason: 'sin dato: sin definir');
    });

    test('una base v10 sube a v11 con el IVA sin definir', () async {
      sqfliteFfiInit();
      final v10 = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false));
      await v10.execute('CREATE TABLE productos(id TEXT PRIMARY KEY, nombre TEXT NOT NULL)');
      await v10.insert('productos', {'id': 'p1', 'nombre': 'Arroz'});
      await LocalDb.migrar(v10, 10, 11);
      expect((await v10.query('productos')).single['iva'], -1);
      expect(await v10.query('facturas_e'), isEmpty);
      await v10.close();
    });
  });
}
