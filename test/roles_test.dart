import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';

void main() {
  test('el dueño puede todo y el administrador todo menos manejar el equipo', () {
    for (final p in Permiso.values) {
      expect(puede(Rol.dueno, p), isTrue, reason: '$p');
      expect(puede(Rol.administrador, p), p != Permiso.gestionarEquipo, reason: '$p');
    }
  });

  test('el despachador solo vende de contado y registra entradas; no ve costos, utilidad, gastos ni informes', () {
    expect(permisosDe(Rol.despachador),
        {Permiso.venderContado, Permiso.verVentas, Permiso.verProductos, Permiso.entradaInventario});
    for (final p in [Permiso.verCostos, Permiso.verUtilidad, Permiso.verGastos, Permiso.verInformes,
        Permiso.registrarGasto, Permiso.venderFiado, Permiso.anularMovimiento, Permiso.editarProductos]) {
      expect(puede(Rol.despachador, p), isFalse, reason: '$p');
    }
  });

  test('el despachador fía solo si el dueño lo activa, y aun así no ve costos ni gastos', () {
    expect(puede(Rol.despachador, Permiso.venderFiado), isFalse);
    expect(puede(Rol.despachador, Permiso.venderFiado, despachadorFia: true), isTrue);
    expect(puede(Rol.despachador, Permiso.registrarAbono, despachadorFia: true), isTrue);
    expect(puede(Rol.despachador, Permiso.crearClientes, despachadorFia: true), isTrue);
    expect(puede(Rol.despachador, Permiso.verCostos, despachadorFia: true), isFalse);
    expect(puede(Rol.despachador, Permiso.verGastos, despachadorFia: true), isFalse);
    // La opción de fiado no le da nada a los demás roles.
    expect(puede(Rol.bodeguero, Permiso.venderFiado, despachadorFia: true), isFalse);
  });

  test('el contador solo consulta: no registra ventas, gastos ni inventario', () {
    for (final p in [Permiso.venderContado, Permiso.venderFiado, Permiso.registrarGasto,
        Permiso.entradaInventario, Permiso.editarProductos, Permiso.crearClientes, Permiso.gestionarEquipo]) {
      expect(puede(Rol.contador, p), isFalse, reason: '$p');
    }
    for (final p in [Permiso.verGastos, Permiso.verCostos, Permiso.verUtilidad, Permiso.verInformes]) {
      expect(puede(Rol.contador, p), isTrue, reason: '$p');
    }
  });

  test('el bodeguero maneja el inventario sin ver costos ni ventas', () {
    expect(permisosDe(Rol.bodeguero),
        {Permiso.verProductos, Permiso.entradaInventario, Permiso.ajusteInventario});
  });

  test('roles guardados: nombres nuevos y los anteriores (admin, vendedor)', () {
    for (final r in Rol.values) {
      expect(rolDesdeTexto(rolATexto(r)), r);
    }
    expect(rolDesdeTexto('admin'), Rol.dueno);
    expect(rolDesdeTexto('vendedor'), Rol.despachador);
    expect(rolDesdeTexto('Dueño'), Rol.dueno);
    expect(rolDesdeTexto('algo raro'), Rol.bodeguero, reason: 'lo desconocido, con el mínimo permiso');
  });

  test('una invitación nunca da el rol de dueño', () {
    expect(rolesInvitables, isNot(contains(Rol.dueno)));
    expect(rolesInvitables.toSet(), Rol.values.toSet()..remove(Rol.dueno));
  });

  test('qué descarga cada rol: despachador y bodeguero sin costos y sin lo que no pueden ver', () {
    List<(String, String)> f(Rol r, {bool fia = false}) =>
        fuentesDescarga(ContextoEquipo(rol: r, despachadorFia: fia));
    const completo = [('clientes', 'clientes'), ('ventas', 'ventas'), ('productos', 'productos'), ('inventario', 'inventario')];
    expect(f(Rol.dueno), completo);
    expect(f(Rol.administrador), completo);
    expect(f(Rol.contador), completo);
    expect(f(Rol.despachador),
        [('ventas', 'ventas'), ('productos', 'productos_operativos'), ('inventario', 'inventario_operativo')]);
    expect(f(Rol.despachador, fia: true).first, ('clientes', 'clientes'));
    expect(f(Rol.bodeguero), [('productos', 'productos_operativos'), ('inventario', 'inventario_operativo')]);
  });

  test('el contexto del servidor se lee bien y sin datos es el dueño', () {
    final c = ContextoEquipo.desdeServidor({'rol': 'despachador', 'despachador_fia': true, 'empresa_id': 'e1'});
    expect(c.rol, Rol.despachador);
    expect(c.puede(Permiso.venderFiado), isTrue);
    expect(c.empresaId, 'e1');
    expect(const ContextoEquipo().rol, Rol.dueno);
  });
}
