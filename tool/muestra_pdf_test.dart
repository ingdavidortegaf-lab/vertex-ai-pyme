import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/domain/contabilidad.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'package:vertex_ai_pyme/pdf/pdf_reportes.dart';
import 'package:vertex_ai_pyme/pdf/reportes_contables.dart';
import '../test/soporte.dart';

/// Genera PDF de muestra (informe del mes y cuenta de cobro) con una historia
/// realista de una tienda, para revisar el diseño o mostrarlos en el pitch.
/// Uso: SALIDA=carpeta flutter test tool/muestra_pdf_test.dart
void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  test('muestras', () async {
    final out = Platform.environment['SALIDA'] ?? 'build';
    final hoy = DateTime.now();
    DateTime hace(int dias, [int hora = 10]) =>
        DateTime(hoy.year, hoy.month, hoy.day - dias, hora);
    final db = await baseDePrueba();
    await db.setAjuste('negocio_nombre', 'Tienda Doña Marta');
    await db.setAjuste('negocio_nit', '1118000000');
    await db.setAjuste('negocio_direccion', 'Cra 20 # 10-15, Trinidad, Casanare');
    await db.setAjuste('negocio_telefono', '3101234567');

    Future<void> en(DateTime f, Future<void> Function() hacer) async {
      db.reloj = () => f;
      await hacer();
    }

    final pedro = await db.saveCliente('Pedro Rincón', '3001234567');
    final ana = await db.saveCliente('Ana Pérez', '3157654321');
    // Pedro, productor de la vereda: fía y paga cuando vende el ganado.
    await en(hace(95), () => db.saveMovimiento('Purina 40 kg x2', 236000, credito: true, clienteId: pedro));
    await en(hace(70), () => db.saveMovimiento('Sal mineralizada 25 kg', 48000, credito: true, clienteId: pedro));
    await en(hace(50), () => db.saveMovimiento('Abono', 150000, tipo: 'abono', clienteId: pedro));
    await en(hace(38), () => db.saveMovimiento('Alambre de púas y grapas', 92000, credito: true, clienteId: pedro));
    await en(hace(12), () => db.saveMovimiento('Acetaminofén y suero oral', 18500, credito: true, clienteId: pedro));
    await en(hace(20), () => db.saveMovimiento('Mercado de la semana', 64000, credito: true, clienteId: ana));

    final arroz = await db.saveProducto('Arroz 500 g', precio: 2500, costo: 1800, minimo: 10, stockInicial: 300);
    final sal = await db.saveProducto('Sal mineralizada 25 kg', precio: 48000, costo: 36000, minimo: 4, stockInicial: 12);
    final aceta = await db.saveProducto('Acetaminofén x10', precio: 3000, costo: 1900, minimo: 5, stockInicial: 120);
    for (var d = 0; d < hoy.day + 30; d++) {
      final f = hace(d, 9);
      await en(f, () => db.saveMovimiento('Venta mostrador', 180000 + (d % 5) * 35000.0));
      if (d % 3 == 0) {
        await en(f, () async {
          await db.saveVentaProductos([
            ItemVenta(productoId: arroz, nombre: 'Arroz 500 g', cantidad: 6, precio: 2500, costo: 1800),
            ItemVenta(productoId: aceta, nombre: 'Acetaminofén x10', cantidad: 2, precio: 3000, costo: 1900),
          ]);
        });
      }
      if (d % 7 == 2) {
        await en(f, () => db.saveVentaProductos([
              ItemVenta(productoId: sal, nombre: 'Sal mineralizada 25 kg', cantidad: 1, precio: 48000, costo: 36000)
            ]));
      }
      if (d % 10 == 4) await en(f, () => db.saveMovimiento('Pago al preventista', 420000, tipo: 'egreso'));
    }
    await en(hace(1), () => db.saveMovimiento('Servicio de luz', 86000, tipo: 'egreso'));
    db.reloj = DateTime.now;

    final n = await db.perfilNegocio();
    final d = await cargarInforme(Periodo.mesActual, hoy);
    await File('$out/informe.pdf').writeAsBytes(await pdfReporte(
        reporteInforme(negocio: n, numero: 'IN-A3F1-000004', fecha: hoy, d: d)));
    final e = estadoDeCuenta(await db.movimientosDeCredito(pedro), hoy);
    await File('$out/cobro.pdf').writeAsBytes(await pdfReporte(reporteCuentaCobro(
        negocio: n, numero: 'CC-A3F1-000017', fecha: hoy,
        cliente: 'Pedro Rincón', telefono: '3001234567', estado: e)));
  });
}
