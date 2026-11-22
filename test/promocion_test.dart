import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/domain/documentos.dart';
import 'package:vertex_ai_pyme/domain/promocion.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  const negocio = PerfilNegocio(nombre: 'Tienda Doña Marta', direccion: 'Calle 10 # 5-20, Bucaramanga');
  final productos = [
    const ProductoPromo('Arroz Diana 500 g', 2000, 2500),
    const ProductoPromo('Aceite 1 L', 9500, 9500),
  ];

  test('ocasión según la fecha: quincena, viernes negro, Navidad y fin de semana', () {
    expect(ocasionDelMomento(DateTime(2026, 11, 15)).nombre, 'Quincena');
    expect(ocasionDelMomento(DateTime(2026, 11, 27)).nombre, 'Viernes negro');
    expect(ocasionDelMomento(DateTime(2026, 12, 16)).nombre, 'Navidad');
    expect(ocasionDelMomento(DateTime(2026, 11, 7)).nombre, 'Fin de semana'); // sábado
    expect(ocasionDelMomento(DateTime(2026, 11, 10)).nombre, 'Hoy'); // martes
  });

  test('el anuncio trae precios, descuento real, llamado a la acción y etiquetas del municipio', () {
    final t = redactarPromocion(
        negocio: negocio, productos: productos, ahora: DateTime(2026, 11, 10), domicilios: true);
    expect(t, contains('2.500'));
    expect(t, contains('-20 %'));
    expect(t, contains('Hasta *20 % de descuento*'));
    expect(t, contains('se lo llevamos'));
    expect(t, contains('#TiendaDoñaMarta'));
    expect(t, contains('#Bucaramanga'));
    expect(t, isNot(contains('#Casa' 'nare')));
    expect(t, isNot(contains('Aceite 1 L: ~')), reason: 'sin rebaja no se tacha el precio');
  });

  test('combo: suma y ahorro; otra versión cambia la redacción', () {
    final a = redactarPromocion(
        negocio: negocio, productos: productos, estilo: EstiloPromo.combo, ahora: DateTime(2026, 11, 10));
    expect(a, contains('Todo por'));
    expect(a, contains('Se ahorra'));
    final b = redactarPromocion(
        negocio: negocio, productos: productos, estilo: EstiloPromo.combo, ahora: DateTime(2026, 11, 10), variante: 1);
    expect(a, isNot(b));
  });

  test('a la IA en la nube solo viajan productos, precios, estilo y ocasión', () {
    final c = cuerpoPromocionIA(productos, EstiloPromo.urgente, DateTime(2026, 11, 27));
    expect(c['modo'], 'promocion');
    expect(c['ocasion'], 'Viernes negro');
    expect(c.toString(), isNot(contains('Doña Marta')));
    expect(c.toString(), isNot(contains('Bucaramanga')));
  });

  test('sin ciudad en la dirección no pone etiqueta de lugar', () {
    const sinCiudad = PerfilNegocio(nombre: 'Tienda Doña Marta', direccion: 'Calle 10 # 5-20');
    final t = redactarPromocion(
        negocio: sinCiudad, productos: productos, ahora: DateTime(2026, 11, 10), domicilios: false);
    expect(t.trim().split('\n').last, '#TiendaDoñaMarta #ComprarEnElBarrio');
  });
}
