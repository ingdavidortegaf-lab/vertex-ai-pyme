import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/avisos.dart';
import 'package:vertex_ai_pyme/domain/codigos.dart';
import 'package:vertex_ai_pyme/domain/documentos.dart';
import 'package:vertex_ai_pyme/domain/modo_negocio.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'soporte.dart';

void main() {
  final ahora = DateTime(2026, 11, 18, 10);
  const arroz = ProductoStock(id: 'a', nombre: 'Arroz', stock: 0);
  const sal = ProductoStock(id: 's', nombre: 'Sal', stock: 2, minimo: 5);
  const corte = ProductoStock(id: 'c', nombre: 'Corte de cabello', unidad: 'serv', stock: -3);

  test('avisa una sola vez cuando algo se agota o se está acabando', () {
    final r1 = revisarAvisos(
        previa: const MemoriaAvisos(), productos: [arroz, sal, corte], ahora: ahora);
    expect(r1.avisos.map((a) => a.titulo), ['Se agotó Arroz', 'Se está acabando Sal']);
    // Misma situación: no repite.
    final r2 = revisarAvisos(previa: r1.memoria, productos: [arroz, sal, corte], ahora: ahora);
    expect(r2.avisos, isEmpty);
    // Se surte el arroz y se vuelve a agotar: avisa otra vez.
    final r3 = revisarAvisos(
        previa: r2.memoria,
        productos: [const ProductoStock(id: 'a', nombre: 'Arroz', stock: 10), sal],
        ahora: ahora);
    final r4 = revisarAvisos(previa: r3.memoria, productos: [arroz, sal], ahora: ahora);
    expect(r4.avisos.single.titulo, 'Se agotó Arroz');
  });

  test('meta cumplida una vez al mes, cartera una vez al día y errores de envío', () {
    final r = revisarAvisos(
      previa: const MemoriaAvisos(),
      productos: const [],
      ahora: ahora,
      ventasMes: 5000000,
      metaMes: 4000000,
      clientesVencidos: 2,
      saldoVencido: 180000,
      erroresEnvio: 1,
    );
    expect(r.avisos.map((a) => a.canal), ['metas', 'cobros', 'sistema']);
    expect(r.avisos[1].titulo, '2 clientes deben hace más de 30 días');
    final otra = revisarAvisos(
        previa: r.memoria,
        productos: const [],
        ahora: ahora.add(const Duration(hours: 2)),
        ventasMes: 5100000,
        metaMes: 4000000,
        clientesVencidos: 2,
        erroresEnvio: 1);
    expect(otra.avisos, isEmpty);
  });

  test('servicios: no se agotan y el precio se muestra sin «c/u»', () {
    expect(corte.agotado, isFalse);
    expect(corte.bajo, isFalse);
    expect(precioConUnidad(30000, 'serv'), r'$30.000');
    expect(precioConUnidad(2500, 'und'), r'$2.500 c/u');
    expect(const LineaDoc('Corte', 1, 30000, 'serv').precioTexto, r'$30.000');
  });

  test('modo del negocio: se guarda, se lee y cambia la app', () async {
    expect(sugerenciaPorTipo('Peluquería o belleza').oferta, Oferta.servicios);
    expect(const ModoNegocio(oferta: Oferta.servicios).nombreCatalogo, 'Servicios');
    expect(const ModoNegocio(oferta: Oferta.servicios).unidadInicial, 'serv');
    // Celular con versión anterior (sin ajustes): todo sigue como antes.
    final viejo = ModoNegocio.deAjustes(const {});
    expect(viejo.configurado, isFalse);
    expect(viejo.fia && viejo.gramera && viejo.codigos, isTrue);

    final db = await baseDePrueba();
    await db.guardarModo(const ModoNegocio(configurado: true, oferta: Oferta.ambos, fia: false));
    db.modo.value = const ModoNegocio();
    final m = await db.cargarModo();
    expect(m.configurado, isTrue);
    expect(m.oferta, Oferta.ambos);
    expect(m.fia, isFalse);

    // Un servicio se vende sin inventario y no aparece por reponer.
    final id = await db.saveProducto('Domicilio', precio: 3000, unidad: 'serv');
    await db.saveVentaProductos(
        [ItemVenta(productoId: id, nombre: 'Domicilio', cantidad: 2, precio: 3000, unidad: 'serv')]);
    final p = (await db.productos()).single;
    expect(p.esServicio, isTrue);
    expect(p.agotado, isFalse);
  });
}
