import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/documentos.dart';
import 'package:vertex_ai_pyme/domain/formato.dart';
import 'package:vertex_ai_pyme/domain/privacidad.dart';

void main() {
  test('cop formatea miles con punto', () {
    expect(cop(0), '\$0');
    expect(cop(950), '\$950');
    expect(cop(1234567), '\$1.234.567');
    expect(cop(-25000), '-\$25.000');
  });

  group('parseMonto', () {
    test('acepta formato colombiano', () {
      expect(parseMonto('25.000'), 25000);
      expect(parseMonto('\$ 25.000'), 25000);
      expect(parseMonto('25000'), 25000);
      expect(parseMonto('1.234,5'), 1234.5);
    });
    test('rechaza vacío, cero, negativo y texto', () {
      expect(parseMonto(''), isNull);
      expect(parseMonto('0'), isNull);
      expect(parseMonto('abc'), isNull);
      expect(parseMonto('-'), isNull);
      expect(parseMonto('9999999999999'), isNull);
    });
  });

  group('normalizarTelefono', () {
    test('celulares válidos quedan en formato wa.me', () {
      expect(normalizarTelefono('300 123 4567'), '573001234567');
      expect(normalizarTelefono('+57 300-123-4567'), '573001234567');
      expect(normalizarTelefono('573001234567'), '573001234567');
    });
    test('vacío es válido (opcional) e inválidos dan null', () {
      expect(normalizarTelefono(''), '');
      expect(normalizarTelefono('6087654321'), isNull); // fijo
      expect(normalizarTelefono('30012345'), isNull);
    });
    test('mostrarTelefono', () {
      expect(mostrarTelefono('573001234567'), '300 123 4567');
    });
    test('celulares de otros países con su indicativo', () {
      expect(normalizarTelefono('305 123 4567', pais: '1'), '13051234567'); // EE. UU.
      expect(normalizarTelefono('1 305 123 4567', pais: '1'), '13051234567');
      expect(normalizarTelefono('412 123 4567', pais: '58'), '584121234567'); // Venezuela
      expect(normalizarTelefono('612 345 678', pais: '34'), '34612345678'); // España
      expect(normalizarTelefono('99 123 4567', pais: '593'), '593991234567'); // Ecuador
      expect(normalizarTelefono('+1 (305) 123-4567'), '13051234567'); // con +, sin elegir país
      expect(normalizarTelefono('0034 612 345 678'), '34612345678');
      expect(normalizarTelefono('+61 412 345 678'), '61412345678'); // país que no está en la lista
      expect(normalizarTelefono('123', pais: '1'), isNull);
      expect(normalizarTelefono('+57 608 765 4321'), isNull); // fijo colombiano
    });
    test('mostrar y separar números de otros países', () {
      expect(mostrarTelefono('13051234567'), '+1 305 123 4567');
      expect(mostrarTelefono('584121234567'), '+58 412 123 4567');
      expect(separarTelefono('13051234567'), ('1', '3051234567'));
      expect(separarTelefono('573001234567'), ('57', '3001234567'));
      expect(separarTelefono('34612345678'), ('34', '612345678'));
    });
  });

  test('normalizarTexto quita tildes y signos', () {
    expect(normalizarTexto('¿Cuánto VENDÍ hoy?'), 'cuanto vendi hoy');
  });

  group('anonimizarPregunta (minimización Ley 1581)', () {
    test('quita nombres de clientes, teléfonos y correos', () {
      final t = anonimizarPregunta(
          '¿Le fío a Ana María al 300 123 4567 o a pedro@correo.com?',
          ['Ana María Pérez', 'Pedro Gómez']);
      expect(t, isNot(contains('Ana')));
      expect(t, isNot(contains('300 123 4567')));
      expect(t, isNot(contains('pedro@correo.com')));
      expect(t, contains('un cliente'));
    });
    test('no toca palabras que solo contienen el nombre', () {
      final t = anonimizarPregunta('¿Cómo vendo más bananas?', ['Ana']);
      expect(t, contains('bananas'));
    });
  });

  test('el logo se guarda dentro de la base y se recupera igual (sirve en la web)', () {
    final bytes = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3, 250]);
    final t = logoComoTexto(bytes);
    expect(t, startsWith('b64:'));
    expect(bytesDeLogo(t), bytes);
    expect(bytesDeLogo('C:/viejo/logo.img'), isNull); // logo viejo: ruta de archivo
    expect(bytesDeLogo(''), isNull);
  });
}
