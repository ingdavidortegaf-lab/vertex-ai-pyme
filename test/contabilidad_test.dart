import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/contabilidad.dart';
import 'soporte.dart';

Map<String, Object?> mov(String tipo, double monto, DateTime f,
        {bool credito = false, String concepto = 'x'}) =>
    {
      'tipo': tipo,
      'monto': monto,
      'credito': credito ? 1 : 0,
      'fecha': f.toUtc().toIso8601String(),
      'concepto': concepto,
    };

void main() {
  final hoy = DateTime(2026, 11, 18, 10);

  test('cuenta de cobro: abonos pagan lo más antiguo y queda la antigüedad', () {
    final e = estadoDeCuenta([
      mov('abono', 30000, DateTime(2026, 10, 20)),
      mov('ingreso', 50000, DateTime(2026, 8, 1), credito: true, concepto: 'Purina'),
      mov('ingreso', 40000, DateTime(2026, 10, 5), credito: true, concepto: 'Sal'),
      mov('ingreso', 20000, DateTime(2026, 11, 10), credito: true, concepto: 'Arroz'),
      mov('ingreso', 9999, DateTime(2026, 11, 11)), // contado: no entra
    ], hoy);
    expect(e.totalFiado, 110000);
    expect(e.totalAbonado, 30000);
    expect(e.saldo, 80000);
    // Orden por fecha: fiado ago (50k), fiado oct 5 (90k), abono oct 20 (60k), fiado nov (80k).
    expect(e.lineas.map((l) => l.saldo).toList(), [50000, 90000, 60000, 80000]);
    // El abono de 30.000 paga parte del fiado de agosto (quedan 20.000).
    expect(e.abiertas.first.concepto, 'Purina');
    expect(e.abiertas.first.pendiente, 20000);
    expect(e.diasMora, 109);
    expect(e.debeDesde, DateTime(2026, 8, 1));
    expect(e.edades['90+'], 20000);
    expect(e.edades['31-60'], 40000);
    expect(e.edades['0-30'], 20000);
  });

  test('cliente al día', () {
    final e = estadoDeCuenta([
      mov('ingreso', 10000, DateTime(2026, 11, 1), credito: true),
      mov('abono', 10000, DateTime(2026, 11, 2)),
    ], hoy);
    expect(e.saldo, 0);
    expect(e.abiertas, isEmpty);
    expect(e.diasMora, 0);
  });

  test('periodos: semana, quincena y mes con su anterior', () {
    final s = rangoPeriodo(Periodo.semanaActual, hoy); // miércoles 18
    expect(s.desde, DateTime(2026, 11, 16));
    expect(s.hasta, DateTime(2026, 11, 23));
    expect(s.antDesde, DateTime(2026, 11, 9));
    final q = rangoPeriodo(Periodo.quincenaActual, hoy);
    expect(q.desde, DateTime(2026, 11, 16));
    expect(q.hasta, DateTime(2026, 12, 1));
    expect(q.antDesde, DateTime(2026, 11, 1));
    expect(q.antHasta, DateTime(2026, 11, 16));
    final qa = rangoPeriodo(Periodo.quincenaAnterior, hoy);
    expect(qa.desde, DateTime(2026, 11, 1));
    expect(qa.antDesde, DateTime(2026, 10, 16));
    final m = rangoPeriodo(Periodo.mesAnterior, DateTime(2026, 1, 5));
    expect(m.desde, DateTime(2025, 12, 1));
    expect(m.hasta, DateTime(2026, 1, 1));
  });

  test('documentos: número único con prefijo, dispositivo y consecutivo; reimpresión', () async {
    final db = await baseDePrueba();
    final a = await db.emitirDocumento('venta', refId: 'v1', total: 1000);
    final b = await db.emitirDocumento('venta', refId: 'v2', total: 2000);
    final a2 = await db.emitirDocumento('venta', refId: 'v1', reutilizar: true);
    final c = await db.emitirDocumento('cobro', clienteNombre: 'Ana', total: 5000);
    final disp = await db.codigoDispositivo();
    expect(a['numero'], 'CV-$disp-000001');
    expect(b['numero'], 'CV-$disp-000002');
    expect(a2['numero'], a['numero']);
    expect(c['numero'], 'CC-$disp-000001');
    await db.archivarPdf(c['id'] as String, 'C:/x/CC.pdf');
    final l = await db.documentos(tipo: 'cobro');
    expect(l.single['archivo'], 'C:/x/CC.pdf');
    expect((await db.documentos()).length, 3);
  });
}
