import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 18, 10);
  final t1 = t0.add(const Duration(minutes: 5));
  final t2 = t0.add(const Duration(minutes: 10));

  ClienteCampos base() => ClienteCampos(
        id: 'c1',
        nombre: 'Ana',
        nombreTs: t0,
        telefono: '573001111111',
        telefonoTs: t0,
        deleted: false,
        deletedTs: t0,
      );

  test('gana el cambio más reciente de CADA campo', () {
    // Celular A cambió el nombre (t1); celular B cambió el teléfono (t2).
    final a = ClienteCampos(
        id: 'c1', nombre: 'Ana María', nombreTs: t1,
        telefono: '573001111111', telefonoTs: t0,
        deleted: false, deletedTs: t0);
    final b = ClienteCampos(
        id: 'c1', nombre: 'Ana', nombreTs: t0,
        telefono: '573002222222', telefonoTs: t2,
        deleted: false, deletedTs: t0);
    for (final unido in [a.merge(b), b.merge(a)]) {
      expect(unido.nombre, 'Ana María');
      expect(unido.telefono, '573002222222');
      expect(unido.updatedAt, t2);
    }
  });

  test('un cambio viejo que llega tarde no pisa uno nuevo', () {
    final nuevo = base().merge(ClienteCampos(
        id: 'c1', nombre: 'Ana Nueva', nombreTs: t2,
        telefono: '573001111111', telefonoTs: t0,
        deleted: false, deletedTs: t0));
    final tarde = ClienteCampos(
        id: 'c1', nombre: 'Ana Vieja', nombreTs: t1,
        telefono: '573001111111', telefonoTs: t0,
        deleted: false, deletedTs: t0);
    expect(nuevo.merge(tarde).nombre, 'Ana Nueva');
  });

  test('el borrado también se resuelve por fecha', () {
    final borrado = ClienteCampos(
        id: 'c1', nombre: 'Ana', nombreTs: t0,
        telefono: '573001111111', telefonoTs: t0,
        deleted: true, deletedTs: t1);
    expect(base().merge(borrado).deleted, isTrue);
    expect(borrado.merge(base()).deleted, isTrue);
  });

  test('ida y vuelta local/remoto conserva los datos', () {
    final c = base();
    final local = ClienteCampos.fromLocal(c.toLocalRow());
    final remoto = ClienteCampos.fromRemote(c.toRemote());
    expect(local.nombre, c.nombre);
    expect(remoto.telefonoTs, c.telefonoTs);
    expect(remoto.deleted, c.deleted);
  });

  test('espera de reintento crece y tiene tope', () {
    expect(esperaReintento(1), const Duration(seconds: 15));
    expect(esperaReintento(2), const Duration(seconds: 30));
    expect(esperaReintento(3), const Duration(seconds: 60));
    expect(esperaReintento(50), const Duration(minutes: 30));
  });
}
