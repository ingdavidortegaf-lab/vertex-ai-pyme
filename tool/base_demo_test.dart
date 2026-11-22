import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/data/local_db.dart';
import 'package:vertex_ai_pyme/domain/pagos.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';

/// Crea `docs/base_de_datos/vertex_demo.db`: una base SQLite con el MISMO
/// esquema de la app (versión actual) y datos de ejemplo de una tienda, para
/// mostrar la base de datos y practicar consultas en DBeaver o DB Browser.
/// Uso: flutter test tool/base_demo_test.dart
void main() {
  test('base de demostración', () async {
    sqfliteFfiInit();
    final ruta = '${Directory.current.path}/docs/base_de_datos/vertex_demo.db';
    await Directory('${Directory.current.path}/docs/base_de_datos').create(recursive: true);
    if (await File(ruta).exists()) await File(ruta).delete();
    final d = await databaseFactoryFfi.openDatabase(ruta,
        options: OpenDatabaseOptions(
            version: LocalDb.versionEsquema, onCreate: (d, _) => LocalDb.crearEsquema(d)));
    final db = LocalDb.instance..usarBase(d);
    final hoy = DateTime.now();
    var ajuste = 0;
    DateTime hace(int dias, [int hora = 10, int min = 0]) {
      final f = DateTime(hoy.year, hoy.month, hoy.day - dias, hora, min);
      // Nada en el futuro: lo de hoy que aún no ha pasado se corre a la mañana.
      return f.isAfter(hoy)
          ? DateTime(hoy.year, hoy.month, hoy.day, 7, 0).add(Duration(minutes: 7 * ++ajuste))
          : f;
    }
    Future<T> en<T>(DateTime f, Future<T> Function() hacer) {
      db.reloj = () => f;
      return hacer();
    }

    await db.setAjuste('negocio_nombre', 'Tienda Doña Marta');
    await db.setAjuste('negocio_nit', '1118000000');
    await db.setAjuste('negocio_direccion', 'Cra 20 # 10-15, Trinidad, Casanare');
    await db.guardarDatosPago(const DatosPago(nequi: '3101234567', bancolombia: 'Ahorros 123-456789-01'));

    final pedro = await en(hace(100), () => db.saveCliente('Pedro Rincón', '3001234567'));
    final ana = await en(hace(60), () => db.saveCliente('Ana Pérez', '3157654321'));
    final luz = await en(hace(30), () => db.saveCliente('Luz Martínez', '3204567890'));

    final arroz = await en(hace(90), () => db.saveProducto('Arroz 500 g',
        precio: 2500, costo: 1800, minimo: 10, stockInicial: 120, codigo: '7702001000012'));
    final aceta = await en(hace(90), () => db.saveProducto('Acetaminofén x10',
        precio: 3000, costo: 1900, minimo: 5, stockInicial: 40));
    final sal = await en(hace(90), () => db.saveProducto('Sal mineralizada 25 kg',
        precio: 48000, costo: 36000, minimo: 4, stockInicial: 6));
    final queso = await en(hace(90), () => db.saveProducto('Queso campesino',
        precio: 24000, costo: 18000, minimo: 2, stockInicial: 8, unidad: 'kg'));
    await en(hace(90), () => db.saveProducto('Domicilio', precio: 3000, unidad: 'serv'));

    // Fiados y abonos (historia de cartera).
    await en(hace(95), () => db.saveMovimiento('Purina 40 kg x2', 236000, credito: true, clienteId: pedro));
    await en(hace(50), () => db.saveMovimiento('Abono', 150000, tipo: 'abono', clienteId: pedro,
        pagos: const [Pago('nequi', 150000)]));
    await en(hace(38), () => db.saveMovimiento('Alambre de púas', 92000, credito: true, clienteId: pedro));
    await en(hace(20), () => db.saveMovimiento('Mercado de la semana', 64000, credito: true, clienteId: ana));
    await en(hace(3), () => db.saveMovimiento('Abono', 20000, tipo: 'abono', clienteId: ana,
        pagos: const [Pago('efectivo', 20000)]));

    // Ventas de los últimos 14 días con distintos medios de pago.
    const medios = ['efectivo', 'nequi', 'efectivo', 'bancolombia', 'efectivo', 'tarjeta_debito', 'daviplata'];
    for (var d = 13; d >= 0; d--) {
      for (var k = 0; k < 4; k++) {
        final m = medios[(d + k) % medios.length];
        final valor = 8000.0 + ((d * 7 + k * 3) % 9) * 3500;
        await en(hace(d, 8 + k * 3, 15), () => db.saveMovimiento('Venta mostrador', valor,
            pagos: [Pago(m, valor)]));
      }
      await en(hace(d, 11), () => db.saveVentaProductos([
            ItemVenta(productoId: arroz, nombre: 'Arroz 500 g', cantidad: 4, precio: 2500, costo: 1800),
            ItemVenta(productoId: aceta, nombre: 'Acetaminofén x10', cantidad: 1, precio: 3000, costo: 1900),
          ], pagos: d % 2 == 0
              ? const [Pago('nequi', 8000), Pago('efectivo', 5000)]
              : const [Pago('efectivo', 13000)]));
      if (d % 4 == 1) {
        await en(hace(d, 16), () => db.saveVentaProductos([
              ItemVenta(productoId: queso, nombre: 'Queso campesino', cantidad: 0.75, precio: 24000, costo: 18000, unidad: 'kg'),
            ], fiado: true, clienteId: luz));
      }
      if (d % 6 == 0) {
        await en(hace(d, 17), () => db.saveVentaProductos([
              ItemVenta(productoId: sal, nombre: 'Sal mineralizada 25 kg', cantidad: 1, precio: 48000, costo: 36000),
            ], pagos: const [Pago('bancolombia', 48000)]));
      }
      if (d % 5 == 0) {
        await en(hace(d, 18), () => db.saveMovimiento('Pago al preventista', 180000, tipo: 'egreso',
            pagos: const [Pago('efectivo', 180000)]));
      }
    }
    await en(hace(1, 19), () => db.saveMovimiento('Servicio de luz', 86000, tipo: 'egreso',
        pagos: const [Pago('nequi', 86000)]));
    // Proveedores: pedido pagado a la mitad y el resto fiado, con un abono.
    final llano = await en(hace(12), () => db.saveProveedor('Distribuidora El Llano', '3109876543'));
    await en(hace(12, 9), () => db.recibirPedido([(arroz, 50, 1800)],
        conceptoGasto: 'Compra a Distribuidora El Llano',
        pagosGasto: const [Pago('efectivo', 45000)],
        pagadoAhora: 45000,
        proveedorId: llano,
        proveedorNombre: 'Distribuidora El Llano',
        venceSaldo: hoy.add(const Duration(days: 3))));
    final cuenta = (await db.cuentasPorPagar()).single['id'] as String;
    await en(hace(5, 15), () => db.pagarProveedor(cuenta, 20000, const [Pago('nequi', 20000)]));
    final lacteos = await en(hace(6), () => db.saveProveedor('Lácteos La Sabana', '3112223344'));
    await en(hace(6, 8), () => db.recibirPedido([(queso, 6, 18000)],
        conceptoGasto: 'Compra a Lácteos La Sabana',
        pagadoAhora: 0,
        proveedorId: lacteos,
        proveedorNombre: 'Lácteos La Sabana',
        venceSaldo: hoy.add(const Duration(days: 10))));

    // Autorizaciones de datos y último contacto de seguimiento.
    await en(hace(60), () => db.registrarAutorizacionCliente(ana, 'firmó el formato en la tienda'));
    await en(hace(29), () => db.registrarAutorizacionCliente(luz, 'respondió AUTORIZO por WhatsApp'));
    await en(hace(4), () => db.marcarContactado(ana));

    await en(hace(0, 9), () => db.emitirDocumento('cobro', clienteId: pedro, clienteNombre: 'Pedro Rincón', total: 178000));
    await en(hace(0, 9, 5), () => db.emitirDocumento('informe', total: 0, resumen: 'Informe semanal'));

    // Simula que todo ya se subió a la nube menos lo de hoy.
    await d.rawUpdate("UPDATE cola_sync SET estado = 'enviado' WHERE creado < ?",
        [DateTime(hoy.year, hoy.month, hoy.day).toUtc().toIso8601String()]);
    await d.rawUpdate("DELETE FROM cola_sync WHERE estado = 'enviado'");
    await d.rawUpdate("UPDATE ventas SET sync = 'enviado' WHERE fecha < ?",
        [DateTime(hoy.year, hoy.month, hoy.day).toUtc().toIso8601String()]);
    db.reloj = DateTime.now;
    await d.close();
    expect(await File(ruta).exists(), isTrue);
  });
}
