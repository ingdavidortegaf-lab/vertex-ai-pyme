import 'roles.dart';

/// Letras y números del código de invitación: sin I, L, O, 0 ni 1, que se
/// confunden al dictarlos. Es el mismo alfabeto que usa el servidor.
const alfabetoCodigo = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const largoCodigo = 8;

/// Días que dura una invitación si no se dice otra cosa (el servidor acepta
/// de 1 a 30).
const diasInvitacion = 7;

/// Deja el código como lo guarda el servidor: mayúsculas, sin espacios ni
/// guiones.
String normalizarCodigo(String s) => s.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

/// ¿Tiene la forma de un código? (que exista y no esté vencido lo dice el
/// servidor).
bool codigoValido(String s) {
  final c = normalizarCodigo(s);
  return c.length == largoCodigo && c.split('').every(alfabetoCodigo.contains);
}

/// «ABCD-EFGH», más fácil de leer y dictar.
String formatearCodigo(String s) {
  final c = normalizarCodigo(s);
  return c.length == largoCodigo ? '${c.substring(0, 4)}-${c.substring(4)}' : c;
}

/// Mensaje para enviar por WhatsApp. No lleva datos de clientes ni del
/// negocio fuera de su nombre.
String mensajeInvitacion({required String negocio, required Rol rol, required String codigo, int dias = diasInvitacion}) {
  final n = negocio.trim().isEmpty ? 'el negocio' : negocio.trim();
  return 'Te invito a trabajar con $n en VERTEX AI Pyme como ${nombreRol(rol).toLowerCase()}.\n'
      '1. Instala la app y crea tu cuenta con tu correo.\n'
      '2. Entra a Más > Equipo > «Tengo un código».\n'
      '3. Escribe este código: ${formatearCodigo(codigo)}\n'
      'Sirve una sola vez y vence en $dias ${dias == 1 ? 'día' : 'días'}.';
}

/// Una persona del equipo, como la devuelve el servidor.
class MiembroEquipo {
  final String userId;
  final String correo;
  final Rol rol;
  const MiembroEquipo({required this.userId, required this.correo, required this.rol});

  factory MiembroEquipo.desdeServidor(Map<String, dynamic> m) => MiembroEquipo(
        userId: m['user_id'] as String,
        correo: (m['correo'] as String?) ?? '',
        rol: rolDesdeTexto(m['rol'] as String?),
      );
}
