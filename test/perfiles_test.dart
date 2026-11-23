import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/perfiles.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';

void main() {
  test('PBKDF2-HMAC-SHA256 da el vector de prueba del RFC 7914 (1 iteración)', () {
    // RFC 7914, sección 11: P="passwd", S="salt", c=1, dkLen=64; los
    // primeros 32 bytes son el primer bloque, que es lo que calcula hashPin.
    const esperado = '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc';
    final h = base64Decode(hashPin('passwd', base64Encode(utf8.encode('salt')), iteraciones: 1));
    expect(h.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), esperado);
  });

  test('mismo PIN con distinta sal da hashes distintos; el PIN correcto se reconoce', () {
    final azar = Random(7);
    final s1 = nuevaSal(azar), s2 = nuevaSal(azar);
    expect(s1, isNot(s2));
    final h1 = hashPin('2580', s1, iteraciones: 100), h2 = hashPin('2580', s2, iteraciones: 100);
    expect(h1, isNot(h2));
    final p = Perfil(id: 'x', nombre: 'Luis', rol: Rol.despachador, pinHash: h1, sal: s1);
    expect(pinCorrecto('2580', p, iteraciones: 100), isTrue);
    expect(pinCorrecto('2581', p, iteraciones: 100), isFalse);
    expect(h1, isNot(contains('2580')), reason: 'el PIN no queda en claro');
    expect(base64Decode(h1).length, sha256.convert([]).bytes.length);
  });

  test('PIN: de 4 a 6 números, sin repetidos ni seguidos', () {
    expect(problemaPin('2580'), isNull);
    expect(problemaPin('905317'), isNull);
    expect(problemaPin('123'), isNotNull);
    expect(problemaPin('1234567'), isNotNull);
    expect(problemaPin('12a4'), isNotNull);
    expect(problemaPin('0000'), contains('repetido'));
    expect(problemaPin('1234'), contains('seguidos'));
    expect(problemaPin('6543'), contains('seguidos'));
  });

  test('en el celular compartido, el perfil nunca puede más que la cuenta', () {
    const duena = ContextoEquipo(rol: Rol.dueno);
    const despachador = ContextoEquipo(rol: Rol.despachador);
    // La dueña abre la app y atiende Luis (despachador): no ve costos.
    expect(puedeEfectivo(duena, Rol.despachador, Permiso.verCostos), isFalse);
    expect(puedeEfectivo(duena, Rol.despachador, Permiso.venderContado), isTrue);
    // Sin perfil activo, manda la cuenta.
    expect(puedeEfectivo(duena, null, Permiso.verCostos), isTrue);
    // Una cuenta de despachador con un perfil «administrador» sigue sin ver costos.
    expect(puedeEfectivo(despachador, Rol.administrador, Permiso.verCostos), isFalse);
  });

  test('roles que se pueden dar a un perfil según la cuenta', () {
    expect(rolesParaPerfil(const ContextoEquipo(rol: Rol.dueno)), Rol.values);
    expect(rolesParaPerfil(const ContextoEquipo(rol: Rol.administrador)),
        isNot(contains(Rol.dueno)));
    expect(rolesParaPerfil(const ContextoEquipo(rol: Rol.despachador)), [Rol.despachador]);
  });
}
