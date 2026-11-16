import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/asistente_local.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';

void main() {
  const ana = ClienteSaldo(
      id: 'a', nombre: 'Ana María Pérez', telefono: '573001234567', saldo: 20000);
  const luis = ClienteSaldo(id: 'l', nombre: 'Luis Torres', saldo: 0);
  const datos = DatosAsistente(
    mes: Resumen(
        ingresos: 67000,
        egresos: 5000,
        nIngresos: 4,
        nEgresos: 1,
        porCobrar: 20000,
        nDeudores: 1,
        nClientes: 2),
    ventasHoy: 50000,
    nVentasHoy: 2,
    ventasSemana: 60000,
    nVentasSemana: 3,
    clientes: [ana, luis],
    topClientes: [TopCliente('Ana María Pérez', 30000)],
  );

  test('Resumen calcula utilidad, margen y ticket', () {
    const r = Resumen(ingresos: 1000, egresos: 400, nIngresos: 4, nEgresos: 2);
    expect(r.utilidad, 600);
    expect(r.margen, closeTo(0.6, 1e-9));
    expect(r.ticketPromedio, 250);
    expect(r.movimientos, 6);
  });

  test('Resumen sin ingresos no divide por cero', () {
    const r = Resumen(egresos: 50, nEgresos: 1);
    expect(r.margen, 0);
    expect(r.ticketPromedio, 0);
  });

  group('detectarIntencion', () {
    final casos = {
      '¿Cuánto vendí hoy?': Intencion.ventasHoy,
      '¿cuanto vendi esta semana?': Intencion.ventasSemana,
      'ventas del mes': Intencion.ventasMes,
      '¿Quién me debe?': Intencion.quienDebe,
      'cobros pendientes': Intencion.quienDebe,
      '¿Quiénes son mis mejores clientes?': Intencion.mejoresClientes,
      '¿Cuánto gasté este mes?': Intencion.gastosMes,
      'mensaje para cobrarle a Ana': Intencion.mensajeCliente,
      '¿Cómo voy este mes?': Intencion.resumen,
      '¿Qué debo mejorar?': Intencion.general,
      '¿Cómo atraigo más gente al local?': Intencion.general,
    };
    casos.forEach((pregunta, esperado) {
      test(pregunta, () => expect(detectarIntencion(pregunta), esperado));
    });
  });

  group('responderLocal (sin señal)', () {
    test('ventas de hoy y de la semana', () {
      expect(responderLocal('¿Cuánto vendí hoy?', datos).texto,
          contains('\$50.000 en 2 ventas'));
      expect(responderLocal('¿Cuánto vendí esta semana?', datos).texto,
          contains('\$60.000 en 3 ventas'));
    });

    test('quién me debe lista a los deudores', () {
      final t = responderLocal('¿Quién me debe?', datos).texto;
      expect(t, contains('Ana María Pérez: \$20.000'));
      expect(t, isNot(contains('Luis')));
    });

    test('nadie debe', () {
      const d = DatosAsistente(clientes: [luis]);
      expect(responderLocal('¿quién me debe?', d).texto, contains('Nadie te debe'));
    });

    test('mejores clientes y gastos', () {
      expect(responderLocal('mejores clientes', datos).texto,
          contains('1. Ana María Pérez: \$30.000'));
      expect(responderLocal('¿cuánto gasté?', datos).texto, contains('\$5.000'));
    });

    test('mensaje de cobro listo para WhatsApp', () {
      final r = responderLocal('mensaje para cobrarle a Ana', datos);
      expect(r.telefono, '573001234567');
      expect(r.mensajeWhatsApp, contains('Hola Ana'));
      expect(r.mensajeWhatsApp, contains('\$20.000'));
    });

    test('mensaje sin cliente reconocido pide el nombre', () {
      final r = responderLocal('escribele un mensaje', datos);
      expect(r.telefono, isNull);
      expect(r.texto, contains('¿Para cuál cliente?'));
    });

    test('cliente sin celular no ofrece WhatsApp', () {
      final r = responderLocal('mensaje para Luis', datos);
      expect(r.telefono, isNull);
      expect(r.texto, contains('no tiene celular'));
    });

    test('pregunta general da el resumen con lo por cobrar', () {
      final t = responderLocal('¿Cómo voy?', datos).texto;
      expect(t, contains('Tu utilidad es \$62.000'));
      expect(t, contains('\$20.000 por cobrar'));
    });
  });

  group('resumenLocal', () {
    test('sin movimientos invita a registrar', () {
      expect(resumenLocal(const Resumen()), contains('Aún no hay movimientos'));
    });
    test('avisa cuando hay pérdidas', () {
      final t = resumenLocal(const Resumen(
          ingresos: 100000, egresos: 150000, nIngresos: 1, nEgresos: 2));
      expect(t, contains('superan'));
      expect(t, contains('-\$50.000'));
    });
    test('margen bajo y margen sano', () {
      expect(
          resumenLocal(const Resumen(
              ingresos: 100000, egresos: 90000, nIngresos: 2, nEgresos: 1)),
          contains('margen es bajo'));
      expect(
          resumenLocal(const Resumen(
              ingresos: 100000, egresos: 30000, nIngresos: 2, nEgresos: 1)),
          contains('Buen margen'));
    });
  });

  test('enlace de WhatsApp codifica el mensaje', () {
    final u = enlaceWhatsApp('573001234567', 'Hola Ana, ¿cómo está?');
    expect(u.host, 'wa.me');
    expect(u.path, '/573001234567');
    expect(u.queryParameters['text'], 'Hola Ana, ¿cómo está?');
  });
}
