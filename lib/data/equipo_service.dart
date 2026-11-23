import '../domain/invitaciones.dart';
import '../domain/roles.dart';
import 'local_db.dart';
import 'remote_api.dart';

/// Algo del equipo no se pudo hacer. [mensaje] se muestra tal cual.
class ErrorEquipo implements Exception {
  final String mensaje;
  const ErrorEquipo(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Manejar el equipo: invitar, unirse con un código, cambiar roles y quitar.
/// Esto sí necesita internet (lo decide el servidor); vender, registrar y
/// todo lo del despachador sigue funcionando sin conexión.
///
/// La app oculta lo que el rol no permite, pero quien impide es el servidor:
/// estas funciones solo piden, y si el servidor dice que no, se explica.
class EquipoService {
  EquipoService(this.db, this.api);
  final LocalDb db;
  final RemoteApi api;

  static const sinConexion =
      'No hay conexión. Para manejar el equipo se necesita internet; '
      'vender y registrar sí funcionan sin ella.';
  static const sinSesion = 'Inicia sesión con tu correo para manejar el equipo.';

  Future<T> _pedir<T>(Future<T> Function() f) async {
    if (!api.haySesion) throw const ErrorEquipo(sinSesion);
    try {
      return await f();
    } on RechazoServidor catch (e) {
      throw ErrorEquipo(_explicar(e));
    } on SesionVencida {
      throw const ErrorEquipo('La sesión venció. Vuelve a iniciar sesión.');
    } on ErrorEquipo {
      rethrow;
    } catch (_) {
      throw const ErrorEquipo(sinConexion);
    }
  }

  /// El servidor explica en español; si no hay explicación (o es técnica),
  /// se dice algo útil según el código.
  static String _explicar(RechazoServidor e) {
    final m = e.mensaje.trim();
    final tecnico = m.isEmpty || m.contains('function') || m.contains('schema') || m.contains('relation');
    if (!tecnico) return m;
    return switch (e.codigo) {
      '42501' => 'Tu rol no permite hacer esto.',
      'PGRST202' || '42883' =>
        'El servidor todavía no tiene esta función. Pide a soporte que lo actualice.',
      _ => 'El servidor no lo aceptó (${e.codigo}).',
    };
  }

  /// Código de invitación para [rol]. Solo el dueño (lo verifica el servidor).
  Future<String> invitar(Rol rol, {int dias = diasInvitacion}) {
    if (!rolesInvitables.contains(rol)) throw ArgumentError('rol');
    return _pedir(() => api.crearInvitacion(rol, dias: dias));
  }

  /// Une esta cuenta al negocio del código. No se permite si en este celular
  /// hay datos de un negocio propio: se mezclarían con los del otro.
  /// Devuelve el rol con el que quedó.
  Future<Rol> unirse(String codigo) async {
    if (!codigoValido(codigo)) {
      throw const ErrorEquipo('El código tiene 8 letras y números, por ejemplo ABCD-EFGH.');
    }
    if (await db.tieneDatosDelNegocio()) {
      throw const ErrorEquipo('Este celular ya tiene ventas, clientes o productos de tu propio negocio. '
          'Para unirte a otro negocio usa una cuenta y un celular sin datos, '
          'o borra los datos de este celular desde Privacidad.');
    }
    final r = await _pedir(() => api.unirseConCodigo(normalizarCodigo(codigo)));
    final nuevo = ContextoEquipo(
      rol: rolDesdeTexto(r['rol'] as String?),
      empresaId: (r['empresa_id'] as String?) ?? '',
    );
    // Lo del negocio propio (vacío) se descarta y se baja lo del nuevo en la
    // próxima sincronización.
    await db.cambiarDeNegocio(nuevo);
    return nuevo.rol;
  }

  Future<List<MiembroEquipo>> miembros() => _pedir(api.equipo);

  Future<void> cambiarRol(MiembroEquipo m, Rol rol) {
    if (!rolesInvitables.contains(rol)) throw ArgumentError('rol');
    return _pedir(() => api.cambiarRol(m.userId, rol));
  }

  Future<void> quitar(MiembroEquipo m) => _pedir(() => api.quitarMiembro(m.userId));

  /// ¿El despachador puede fiar y recibir abonos?
  Future<void> definirDespachadorFia(bool valor) async {
    await _pedir(() => api.definirDespachadorFia(valor));
    final c = db.equipo.value;
    await db.guardarContexto(c.copiar(despachadorFia: valor));
  }

  /// Tope de descuento para todos menos el dueño (0 = sin descuentos).
  Future<void> definirDescuentoMaximo(double pct) async {
    if (!pct.isFinite || pct < 0 || pct > 100) throw ArgumentError('pct');
    await _pedir(() => api.definirDescuentoMaximo(pct));
    await db.guardarContexto(db.equipo.value.copiar(descuentoMaxPct: pct));
  }
}
