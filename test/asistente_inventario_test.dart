import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/asistente_local.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';

void main() {
  test('detecta preguntas de inventario, más vendido y meta', () {
    expect(detectarIntencion('¿Qué se me está agotando?'), Intencion.inventario);
    expect(detectarIntencion('¿Qué tengo que surtir?'), Intencion.inventario);
    expect(detectarIntencion('¿Cuál es mi producto más vendido?'), Intencion.masVendido);
    expect(detectarIntencion('¿Qué es lo que más se vende?'), Intencion.masVendido);
    expect(detectarIntencion('¿Cómo voy con la meta?'), Intencion.meta);
    // Las de antes siguen igual.
    expect(detectarIntencion('¿Cuánto vendí hoy?'), Intencion.ventasHoy);
    expect(detectarIntencion('¿Quién me debe?'), Intencion.quienDebe);
  });

  test('responde por reponer con agotados primero', () {
    const d = DatosAsistente(productos: [
      ProductoStock(id: 'a', nombre: 'Arroz', costo: 1800, minimo: 5, stock: 3),
      ProductoStock(id: 'b', nombre: 'Aceite', costo: 7000, minimo: 2, stock: 0),
      ProductoStock(id: 'c', nombre: 'Sal', costo: 800, minimo: 2, stock: 10),
    ]);
    final r = responderLocal('¿qué se me está agotando?', d).texto;
    expect(r, contains('3 productos'));
    expect(r, contains(cop(3 * 1800 + 10 * 800)));
    expect(r.indexOf('Aceite: agotado'), lessThan(r.indexOf('Arroz: quedan 3')));
    expect(r, isNot(contains('Sal')));
  });

  test('meta del mes: cuánto falta', () {
    const d = DatosAsistente(
        mes: Resumen(ingresos: 600000, nIngresos: 10), metaMensual: 1000000);
    final r = responderLocal('¿cómo voy con la meta?', d).texto;
    expect(r, contains('60 %'));
    expect(r, contains(cop(400000)));
  });

  test('más vendido sin ventas con productos explica qué hacer', () {
    final r = responderLocal('producto más vendido', const DatosAsistente()).texto;
    expect(r, contains('agrega los productos'));
  });
}
