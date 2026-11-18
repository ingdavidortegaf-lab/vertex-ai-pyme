import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/domain/contabilidad.dart';
import 'package:vertex_ai_pyme/domain/documentos.dart';
import 'package:vertex_ai_pyme/ui/pdf_reportes.dart';
import 'package:vertex_ai_pyme/ui/reportes_contables.dart';
import 'soporte.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  test('gastos por concepto y variación', () {
    final g = gastosPorConcepto([
      {'tipo': 'egreso', 'concepto': 'Luz', 'monto': 50000},
      {'tipo': 'egreso', 'concepto': 'luz ', 'monto': 10000},
      {'tipo': 'egreso', 'concepto': 'Arriendo', 'monto': 400000},
      {'tipo': 'ingreso', 'concepto': 'Venta', 'monto': 999},
    ]);
    expect(g.first, ('Arriendo', 400000.0));
    expect(g[1].$2, 60000);
    expect(variacion(120, 100), '+20 %');
    expect(variacion(80, 100), '-20 %');
    expect(variacion(50, 0), 'nuevo');
  });

  test('informe del mes y cuenta de cobro salen en PDF con datos reales', () async {
    final db = await baseDePrueba();
    final ana = await db.saveCliente('Ana Pérez', '3001234567');
    await db.saveMovimiento('Arroz y aceite', 30000, credito: true, clienteId: ana);
    await db.saveMovimiento('Abono', 10000, tipo: 'abono', clienteId: ana);
    await db.saveMovimiento('Venta mostrador', 15000);
    await db.saveMovimiento('Luz', 8000, tipo: 'egreso');
    await db.saveProducto('Sal', precio: 2000, costo: 1500, minimo: 5, stockInicial: 2);
    await db.saveProducto('Purina 40 kg', precio: 90000, costo: 80000, stockInicial: 3);

    final d = await cargarInforme(Periodo.mesActual, DateTime.now());
    expect(d.actual.ventas, 45000);
    expect(d.actual.gastos, 8000);
    expect(d.cajaNeta, 15000 + 10000 - 8000);
    expect(d.carteraTotal, 20000);
    expect(d.deudores.single.$1, 'Ana Pérez');
    expect(d.porReponer.map((p) => p.nombre), ['Sal']);
    expect(d.valorCosto, 2 * 1500 + 3 * 80000);
    expect(d.gastos.single, ('Luz', 8000.0));

    final negocio = await db.perfilNegocio();
    final doc = await db.emitirDocumento('informe', total: d.actual.ventas);
    final r = reporteInforme(
        negocio: negocio, numero: doc['numero'] as String, fecha: DateTime.now(), d: d);
    final pdf = await pdfReporte(r);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(textoInforme(negocio, doc['numero'] as String, d), contains('Caja neta'));

    final estado = estadoDeCuenta(await db.movimientosDeCredito(ana), DateTime.now());
    expect(estado.saldo, 20000);
    final cobro = reporteCuentaCobro(
        negocio: const PerfilNegocio(nombre: 'Tienda Doña Marta'),
        numero: 'CC-TEST-000001',
        fecha: DateTime.now(),
        cliente: 'Ana Pérez',
        telefono: '3001234567',
        estado: estado);
    final pdfCobro = await pdfReporte(cobro);
    expect(String.fromCharCodes(pdfCobro.take(5)), '%PDF-');
    expect(cobro.pdf.nombre, 'CC-TEST-000001.pdf');
    final texto = textoCuentaCobro(
        negocio: const PerfilNegocio(nombre: 'Tienda Doña Marta'),
        cliente: 'Ana Pérez',
        numero: 'CC-TEST-000001',
        estado: estado,
        fecha: DateTime.now());
    expect(texto, contains('Saldo pendiente: '));
    expect(texto, contains('Hola, Ana'));
  });
}
