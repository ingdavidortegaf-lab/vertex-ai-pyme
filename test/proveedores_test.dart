import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/avisos.dart';
import 'package:vertex_ai_pyme/domain/pagos.dart';
import 'soporte.dart';

void main() {
  test('pedido pagado a medias: entra todo al inventario, gasto solo por lo pagado y el resto queda por pagar', () async {
    final db = await baseDePrueba();
    final arroz = await db.saveProducto('Arroz', precio: 2500, costo: 2000, stockInicial: 0);
    final pid = await db.saveProveedor('Distribuidora El Llano', '3101234567');
    await db.recibirPedido([(arroz, 50, 2000)],
        conceptoGasto: 'Compra a Distribuidora El Llano',
        pagosGasto: [const Pago('nequi', 50000)],
        pagadoAhora: 50000,
        proveedorId: pid,
        proveedorNombre: 'Distribuidora El Llano',
        venceSaldo: DateTime.now().add(const Duration(days: 15)));
    expect((await db.productos()).single.stock, 50);
    final gastos = (await db.movimientos()).where((m) => m['tipo'] == 'egreso').toList();
    expect(gastos.single['monto'], 50000);
    expect(gastos.single['concepto'], contains('pago parcial'));

    final deudas = await db.cuentasPorPagar();
    expect(deudas.single['saldo'], 50000);
    expect(deudas.single['proveedor_telefono'], '3101234567');
    expect(await db.totalPorPagar(), 50000);

    // Abono de 20.000 en efectivo y luego el resto por Nequi.
    final id = deudas.single['id'] as String;
    await db.pagarProveedor(id, 20000, [const Pago('efectivo', 20000)]);
    expect(await db.totalPorPagar(), 30000);
    expect(() => db.pagarProveedor(id, 40000, [const Pago('efectivo', 40000)]), throwsArgumentError);
    await db.pagarProveedor(id, 30000, [const Pago('nequi', 30000)]);
    expect(await db.cuentasPorPagar(), isEmpty);
    expect((await db.cuentasPorPagar(soloPendientes: false)).single['abonado'], 50000);
    final egresos = (await db.movimientos()).where((m) => m['tipo'] == 'egreso');
    expect(egresos.fold<double>(0, (s, m) => s + (m['monto'] as num).toDouble()), 100000);
  });

  test('pedido todo fiado: no hay gasto todavía, solo la cuenta por pagar', () async {
    final db = await baseDePrueba();
    final sal = await db.saveProducto('Sal', precio: 1500, costo: 1000, stockInicial: 0);
    await db.recibirPedido([(sal, 10, 1000)], conceptoGasto: 'Compra', pagadoAhora: 0);
    expect((await db.movimientos()).where((m) => m['tipo'] == 'egreso'), isEmpty);
    expect(await db.totalPorPagar(), 10000);
    expect((await db.cuentasPorPagar()).single['proveedor_nombre'], 'Proveedor');
  });

  test('aviso de pagos a proveedores por vencer, una vez al día', () {
    final ahora = DateTime(2026, 11, 19, 9);
    final r = revisarAvisos(
        previa: const MemoriaAvisos(), productos: const [], ahora: ahora, pagosPorVencer: 2, saldoPorVencer: 80000);
    expect(r.avisos.single.titulo, 'Tienes 2 pagos a proveedores por vencer');
    final otra = revisarAvisos(
        previa: r.memoria, productos: const [], ahora: ahora, pagosPorVencer: 2, saldoPorVencer: 80000);
    expect(otra.avisos, isEmpty);
  });
}
