/// Roles del equipo de un negocio y lo que cada uno puede hacer.
///
/// Esta matriz decide qué muestra la app. La seguridad real la impone el
/// servidor con las mismas reglas (políticas RLS por rol en
/// supabase/migrations/): la app oculta, el servidor impide.
library;

enum Rol { dueno, administrador, contador, despachador, bodeguero }

enum Permiso {
  // Ventas y caja
  venderContado,
  venderFiado,
  registrarAbono,
  registrarGasto,
  anularMovimiento,
  aplicarDescuento,
  verVentas,
  // Información sensible del negocio
  verGastos,
  verCostos,
  verUtilidad,
  verInformes,
  // Inventario
  verProductos,
  editarProductos,
  entradaInventario,
  ajusteInventario,
  // Personas
  verClientes,
  crearClientes,
  editarClientes,
  verProveedores,
  gestionarProveedores,
  // Herramientas
  pagosFijos,
  cotizaciones,
  promociones,
  seguimiento,
  asistente,
  // Administración
  configurarNegocio,
  gestionarEquipo,
}

/// Nombre para mostrar.
String nombreRol(Rol r) => switch (r) {
      Rol.dueno => 'Dueño',
      Rol.administrador => 'Administrador',
      Rol.contador => 'Contador',
      Rol.despachador => 'Despachador',
      Rol.bodeguero => 'Bodeguero',
    };

/// Qué hace cada rol, en una frase (para la pantalla de equipo).
String descripcionRol(Rol r) => switch (r) {
      Rol.dueno => 'Todo, incluido invitar empleados y cambiar sus roles.',
      Rol.administrador => 'Todo el negocio, menos manejar el equipo.',
      Rol.contador => 'Consulta ventas, gastos, costos e informes. No registra nada.',
      Rol.despachador => 'Vende de contado y registra entradas de mercancía. '
          'Fía solo si el dueño lo activa. No ve costos, gastos ni informes.',
      Rol.bodeguero => 'Registra entradas y ajustes de inventario. No ve costos ni ventas.',
    };

/// Texto que se guarda en la base (local y nube).
String rolATexto(Rol r) => r.name;

/// Lee el rol guardado. Acepta los nombres anteriores: «admin» era el dueño y
/// «vendedor» el despachador. Lo desconocido se trata con el mínimo permiso.
Rol rolDesdeTexto(String? s) => switch ((s ?? '').trim().toLowerCase()) {
      'dueno' || 'dueño' || 'admin' || '' => Rol.dueno,
      'administrador' => Rol.administrador,
      'contador' => Rol.contador,
      'despachador' || 'vendedor' => Rol.despachador,
      'bodeguero' => Rol.bodeguero,
      _ => Rol.bodeguero,
    };

/// Roles que se pueden dar con una invitación (el dueño es uno solo).
const rolesInvitables = [Rol.administrador, Rol.contador, Rol.despachador, Rol.bodeguero];

const _contador = {
  Permiso.verVentas,
  Permiso.verGastos,
  Permiso.verCostos,
  Permiso.verUtilidad,
  Permiso.verInformes,
  Permiso.verProductos,
  Permiso.verClientes,
  Permiso.verProveedores,
};

const _despachador = {
  Permiso.venderContado,
  Permiso.verVentas,
  Permiso.verProductos,
  Permiso.entradaInventario,
};

/// Lo que se le suma al despachador cuando el dueño activa «puede fiar».
const _despachadorFiado = {
  Permiso.venderFiado,
  Permiso.registrarAbono,
  Permiso.verClientes,
  Permiso.crearClientes,
};

const _bodeguero = {
  Permiso.verProductos,
  Permiso.entradaInventario,
  Permiso.ajusteInventario,
};

/// ¿Puede [rol] hacer [p]? [despachadorFia]: el dueño activó que el
/// despachador venda fiado (solo afecta al despachador).
bool puede(Rol rol, Permiso p, {bool despachadorFia = false}) => switch (rol) {
      Rol.dueno => true,
      Rol.administrador => p != Permiso.gestionarEquipo,
      Rol.contador => _contador.contains(p),
      Rol.despachador => _despachador.contains(p) || (despachadorFia && _despachadorFiado.contains(p)),
      Rol.bodeguero => _bodeguero.contains(p),
    };

/// Todos los permisos de un rol (para mostrarlos o depurar).
Set<Permiso> permisosDe(Rol rol, {bool despachadorFia = false}) =>
    {for (final p in Permiso.values) if (puede(rol, p, despachadorFia: despachadorFia)) p};
