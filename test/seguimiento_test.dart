import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/seguimiento.dart';
import 'soporte.dart';

void main() {
  final hoy = DateTime(2026, 11, 19, 10);
  DateTime hace(int d) => hoy.subtract(Duration(days: d));

  test('agrupa: hace rato no vienen, perdidos, nuevos y mejores clientes', () {
    final l = [
      ResumenCliente(id: '1', nombre: 'Ana Pérez', compras: 20, total: 900000, primera: hace(300), ultima: hace(2)),
      ResumenCliente(id: '2', nombre: 'Luis Gómez', compras: 8, total: 300000, primera: hace(200), ultima: hace(35)),
      ResumenCliente(id: '3', nombre: 'Rosa Díaz', compras: 4, total: 80000, primera: hace(250), ultima: hace(120)),
      ResumenCliente(id: '4', nombre: 'Pedro Ruiz', compras: 1, total: 15000, primera: hace(5), ultima: hace(5)),
      const ResumenCliente(id: '5', nombre: 'Sin compras'),
    ];
    final g = agruparClientes(l, hoy);
    expect(g[Grupo.mejores]!.map((c) => c.id), ['1']);
    expect(g[Grupo.extranados]!.map((c) => c.id), ['2']);
    expect(g[Grupo.perdidos]!.map((c) => c.id), ['3']);
    expect(g[Grupo.nuevos]!.map((c) => c.id), ['4']);
  });

  test('mensaje con el primer nombre y el negocio; solo a quien autorizó y sin repetir en 7 días', () {
    final c = ResumenCliente(
        id: '2', nombre: 'Luis Gómez', telefono: '3101234567', compras: 8, total: 300000, ultima: hace(35), autorizo: true);
    final m = mensajeSeguimiento(Grupo.extranados, c, negocio: 'Tienda Doña Marta');
    expect(m, startsWith('Hola Luis'));
    expect(m, contains('*Tienda Doña Marta*'));
    expect(puedeEscribir(c, hoy), isTrue);
    expect(puedeEscribir(ResumenCliente(id: 'x', nombre: 'Sin permiso', telefono: '310', ultima: hace(40)), hoy), isFalse);
    final reciente = ResumenCliente(
        id: '2', nombre: 'Luis', telefono: '310', autorizo: true, contactado: hace(3));
    expect(puedeEscribir(reciente, hoy), isFalse);
  });

  test('resumen desde la base: compras, autorización y último contacto', () async {
    final db = await baseDePrueba();
    final id = await db.saveCliente('Marta Rojas', '3209876543');
    await db.saveMovimiento('Mercado', 50000, clienteId: id);
    await db.saveMovimiento('Pan', 5000, clienteId: id);
    var r = (await db.resumenClientes()).single;
    expect(r.compras, 2);
    expect(r.total, 55000);
    expect(r.autorizo, isFalse);
    await db.registrarAutorizacionCliente(id, 'en la tienda');
    await db.marcarContactado(id);
    r = (await db.resumenClientes()).single;
    expect(r.autorizo, isTrue);
    expect(r.contactado, isNotNull);
  });
}
