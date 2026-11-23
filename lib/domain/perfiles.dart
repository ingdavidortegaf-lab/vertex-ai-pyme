/// Perfiles locales con PIN para el celular compartido: varias personas
/// atienden con la misma cuenta y cada venta queda a nombre de quien la hizo.
///
/// Límite honesto: la base del celular tiene los datos del negocio, así que
/// el PIN solo decide qué muestra la app. La protección real de los datos es
/// la cuenta de cada quien en el servidor (RLS por rol). Por eso un perfil
/// nunca puede hacer más que la cuenta con la que se abrió la app.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'roles.dart';

/// Iteraciones de PBKDF2. Un PIN de 4 a 6 dígitos tiene pocas combinaciones:
/// el hash con sal evita que se lea a simple vista, y el bloqueo por intentos
/// fallidos frena a quien lo pruebe a mano.
const iteracionesPin = 20000;

/// Intentos fallidos antes de esperar.
const intentosAntesDeEsperar = 5;

/// Espera tras demasiados intentos fallidos.
const esperaTrasFallos = Duration(seconds: 30);

class Perfil {
  final String id;
  final String nombre;
  final Rol rol;
  final String pinHash;
  final String sal;

  /// Iteraciones con que se calculó el hash: se guardan con él para poder
  /// subirlas en el futuro sin que los PIN viejos dejen de servir.
  final int iteraciones;
  const Perfil(
      {required this.id,
      required this.nombre,
      required this.rol,
      required this.pinHash,
      required this.sal,
      this.iteraciones = iteracionesPin});

  factory Perfil.desdeFila(Map<String, Object?> f) => Perfil(
        id: f['id'] as String,
        nombre: f['nombre'] as String,
        rol: rolDesdeTexto(f['rol'] as String?),
        pinHash: f['pin_hash'] as String,
        sal: f['sal'] as String,
        iteraciones: (f['iteraciones'] as int?) ?? iteracionesPin,
      );
}

/// Sal aleatoria de 16 bytes (en base64).
String nuevaSal([Random? azar]) {
  final r = azar ?? Random.secure();
  return base64Encode(Uint8List.fromList(List.generate(16, (_) => r.nextInt(256))));
}

/// PBKDF2-HMAC-SHA256 del PIN con la sal (32 bytes, en base64).
String hashPin(String pin, String sal, {int iteraciones = iteracionesPin}) {
  final hmac = Hmac(sha256, utf8.encode(pin));
  final s = base64Decode(sal);
  // Un solo bloque (32 bytes = tamaño de SHA-256): U1 = HMAC(sal || 00000001).
  var u = hmac.convert([...s, 0, 0, 0, 1]).bytes;
  final t = List<int>.of(u);
  for (var i = 1; i < iteraciones; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return base64Encode(t);
}

/// Compara en tiempo constante.
bool pinCorrecto(String pin, Perfil p) {
  final a = base64Decode(hashPin(pin, p.sal, iteraciones: p.iteraciones));
  final b = base64Decode(p.pinHash);
  if (a.length != b.length) return false;
  var dif = 0;
  for (var i = 0; i < a.length; i++) {
    dif |= a[i] ^ b[i];
  }
  return dif == 0;
}

/// Revisa el PIN nuevo. Null si sirve; si no, el motivo en palabras simples.
String? problemaPin(String pin) {
  if (!RegExp(r'^[0-9]{4,6}$').hasMatch(pin)) return 'El PIN tiene de 4 a 6 números';
  if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return 'No uses el mismo número repetido';
  const sube = '0123456789', baja = '9876543210';
  if (sube.contains(pin) || baja.contains(pin)) return 'No uses números seguidos (1234, 4321)';
  return null;
}

/// Permiso efectivo en el celular compartido: el de la cuenta Y el del perfil
/// activo. Sin perfil activo, el de la cuenta.
bool puedeEfectivo(ContextoEquipo cuenta, Rol? perfil, Permiso p) =>
    cuenta.puede(p) && (perfil == null || puede(perfil, p, despachadorFia: cuenta.despachadorFia));

/// Roles que se le pueden dar a un perfil del celular: solo los que la cuenta
/// cubre (nadie crea un perfil con más permisos que la cuenta).
List<Rol> rolesParaPerfil(ContextoEquipo cuenta) => [
      for (final r in Rol.values)
        if (Permiso.values.every((p) => !puede(r, p, despachadorFia: cuenta.despachadorFia) || cuenta.puede(p))) r
    ];
