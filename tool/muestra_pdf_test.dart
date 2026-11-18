import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/domain/contabilidad.dart';
import 'package:vertex_ai_pyme/pdf/pdf_reportes.dart';
import 'package:vertex_ai_pyme/pdf/reportes_contables.dart';
import '../test/soporte.dart';

/// Genera PDF de muestra para revisar el diseño: SALIDA=carpeta.
void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  test('muestras', () async {
    final out = Platform.environment['SALIDA'] ?? 'build';
    final db = await baseDePrueba();
    await db.setAjuste('negocio_nombre', 'Tienda Doña Marta');
    await db.setAjuste('negocio_nit', '1118000000');
    await db.setAjuste('negocio_direccion', 'Cra 20 # 10-15, Yopal');
    final ana = await db.saveCliente('Ana Pérez', '3001234567');
    await db.saveMovimiento('Arroz y aceite', 30000, credito: true, clienteId: ana);
    await db.saveMovimiento('Purina', 52000, credito: true, clienteId: ana);
    await db.saveMovimiento('Abono', 10000, tipo: 'abono', clienteId: ana);
    await db.saveMovimiento('Venta mostrador', 15000);
    await db.saveMovimiento('Gaseosas', 9000);
    await db.saveMovimiento('Luz', 8000, tipo: 'egreso');
    await db.saveMovimiento('Arriendo', 400000, tipo: 'egreso');
    await db.saveProducto('Sal', precio: 2000, costo: 1500, minimo: 5, stockInicial: 2);
    final d = await cargarInforme(Periodo.mesActual, DateTime.now());
    final n = await db.perfilNegocio();
    await File('$out/informe.pdf').writeAsBytes(await pdfReporte(
        reporteInforme(negocio: n, numero: 'IN-A3F1-000001', fecha: DateTime.now(), d: d)));
    final e = estadoDeCuenta(await db.movimientosDeCredito(ana), DateTime.now());
    await File('$out/cobro.pdf').writeAsBytes(await pdfReporte(reporteCuentaCobro(
        negocio: n, numero: 'CC-A3F1-000001', fecha: DateTime.now(),
        cliente: 'Ana Pérez', telefono: '3001234567', estado: e)));
  });
}
