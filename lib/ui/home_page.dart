import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'escritorio.dart';
import '../data/local_db.dart';
import '../domain/roles.dart';
import '../data/sync_service.dart';
import 'asistente_page.dart';
import 'clientes_page.dart';
import 'equipo_page.dart';
import 'herramientas_page.dart' show HerramientasGrid;
import 'punto_venta_page.dart';
import 'ilustraciones.dart';
import 'inventario_page.dart';
import 'login_page.dart';
import 'negocio_page.dart';
import 'notificaciones.dart';
import 'pago_widget.dart';
import 'privacidad_page.dart';
import 'registro_negocio_page.dart';
import 'tablero_page.dart';
import 'tema.dart';
import 'ventas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SeccionInicio _actual = SeccionInicio.inicio;

  @override
  void initState() {
    super.initState();
    // La app se adapta a las respuestas del registro guiado.
    LocalDb.instance.modo.addListener(_refrescar);
    // Y al rol del equipo: cada quien ve solo sus secciones.
    LocalDb.instance.equipo.addListener(_refrescar);
    LocalDb.instance.perfilActivo.addListener(_refrescar);
    // Avisos en el celular (agotados, cobros vencidos, meta cumplida).
    Avisos.instance.vigilar();
  }

  @override
  void dispose() {
    LocalDb.instance.modo.removeListener(_refrescar);
    LocalDb.instance.equipo.removeListener(_refrescar);
    LocalDb.instance.perfilActivo.removeListener(_refrescar);
    super.dispose();
  }

  void _refrescar() => setState(() {});

  /// Secciones que el rol actual puede ver, en orden. En el computador hay
  /// dos más en el menú lateral: la caja rápida y las herramientas.
  List<SeccionInicio> _secciones(bool escritorio) {
    final db = LocalDb.instance;
    return [
      SeccionInicio.inicio,
      if (escritorio && db.puede(Permiso.venderContado)) SeccionInicio.vender,
      if (db.puede(Permiso.verVentas)) SeccionInicio.caja,
      if (db.puede(Permiso.verProductos)) SeccionInicio.catalogo,
      if (db.puede(Permiso.verClientes)) SeccionInicio.clientes,
      if (escritorio) SeccionInicio.herramientas,
      if (db.puede(Permiso.asistente)) SeccionInicio.asistente,
    ];
  }

  /// Ir a una sección por su nombre (si el rol la tiene).
  void _irA(SeccionInicio s) {
    if (_secciones(esEscritorio(context)).contains(s)) {
      setState(() => _actual = s);
    }
  }

  Widget _page(SeccionInicio s) => switch (s) {
        SeccionInicio.inicio =>
          TableroPage(key: const ValueKey('t'), onIrA: _irA),
        SeccionInicio.vender =>
          const PuntoVentaPage(key: ValueKey('pv'), comoSeccion: true),
        SeccionInicio.caja => const VentasPage(key: ValueKey('v')),
        SeccionInicio.catalogo => const InventarioPage(key: ValueKey('i')),
        SeccionInicio.clientes => const ClientesPage(key: ValueKey('c')),
        SeccionInicio.herramientas =>
          const _HerramientasSeccion(key: ValueKey('h')),
        SeccionInicio.asistente => const AsistentePage(key: ValueKey('a')),
      };

  ({IconData icono, IconData elegido, String nombre}) _datos(SeccionInicio s) {
    final modo = LocalDb.instance.modo.value;
    return switch (s) {
      SeccionInicio.inicio => (
          icono: Icons.space_dashboard_outlined,
          elegido: Icons.space_dashboard,
          nombre: 'Inicio'
        ),
      SeccionInicio.vender => (
          icono: Icons.point_of_sale_outlined,
          elegido: Icons.point_of_sale,
          nombre: 'Caja rápida'
        ),
      SeccionInicio.caja => (
          icono: Icons.receipt_long_outlined,
          elegido: Icons.receipt_long,
          nombre: 'Movimientos'
        ),
      SeccionInicio.catalogo => (
          icono: modo.vendeProductos
              ? Icons.inventory_2_outlined
              : Icons.handyman_outlined,
          elegido: modo.vendeProductos ? Icons.inventory_2 : Icons.handyman,
          nombre: modo.nombreCatalogo
        ),
      SeccionInicio.clientes => (
          icono: Icons.people_outline,
          elegido: Icons.people,
          nombre: 'Clientes'
        ),
      SeccionInicio.herramientas => (
          icono: Icons.apps_outlined,
          elegido: Icons.apps,
          nombre: 'Herramientas'
        ),
      SeccionInicio.asistente => (
          icono: Icons.auto_awesome_outlined,
          elegido: Icons.auto_awesome,
          nombre: 'Asistente'
        ),
    };
  }

  Color _colorSeccion(SeccionInicio s, Paleta p) => switch (s) {
        SeccionInicio.clientes => p.fiado,
        SeccionInicio.asistente => p.asistente,
        _ => p.ventas,
      };

  List<Widget> _acciones(BuildContext context) => [
        const _BotonCuenta(),
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          onSelected: (v) {
            if (v == 'privacidad') {
              Navigator.of(context).push(rutaVertex(const PrivacidadPage()));
            } else if (v == 'negocio') {
              mostrarMiNegocio(context);
            } else if (v == 'pagos') {
              mostrarDatosPago(context);
            } else if (v == 'ajustar') {
              Navigator.of(context)
                  .push(rutaVertex(const RegistroNegocioPage()));
            } else if (v == 'equipo') {
              Navigator.of(context).push(rutaVertex(const EquipoPage()));
            } else if (v == 'persona') {
              LocalDb.instance.salirPerfil();
            } else if (v == 'sync') {
              SyncService.instance.reintentarErrores();
            }
          },
          itemBuilder: (_) => [
            if (LocalDb.instance.perfilActivo.value case final quien?)
              PopupMenuItem(
                value: 'persona',
                child: ListTile(
                    leading: const Icon(Icons.switch_account_outlined),
                    title: const Text('Cambiar de persona'),
                    subtitle: Text(quien.nombre.isEmpty
                        ? 'Entraste con la cuenta'
                        : 'Atiende ${quien.nombre}'),
                    contentPadding: EdgeInsets.zero),
              ),
            const PopupMenuItem(
              value: 'equipo',
              child: ListTile(
                  leading: Icon(Icons.groups_outlined),
                  title: Text('Equipo'),
                  contentPadding: EdgeInsets.zero),
            ),
            // Los datos del negocio y cómo se ajusta la app: dueño y
            // administrador (el servidor tampoco deja cambiarlos a otros).
            if (LocalDb.instance.puede(Permiso.configurarNegocio)) ...const [
              PopupMenuItem(
                value: 'negocio',
                child: ListTile(
                    leading: Icon(Icons.storefront_outlined),
                    title: Text('Mi negocio'),
                    contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'pagos',
                child: ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined),
                    title: Text('Datos para recibir pagos'),
                    contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'ajustar',
                child: ListTile(
                    leading: Icon(Icons.tune),
                    title: Text('Ajustar la app a mi negocio'),
                    contentPadding: EdgeInsets.zero),
              ),
            ],
            const PopupMenuItem(
              value: 'sync',
              child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('Sincronizar ahora'),
                  contentPadding: EdgeInsets.zero),
            ),
            const PopupMenuItem(
              value: 'privacidad',
              child: ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Privacidad y datos'),
                  contentPadding: EdgeInsets.zero),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ];

  Widget _marca(TextTheme t, Paleta p) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        const LogoVertex(tam: 32, animar: true),
        const SizedBox(width: 10),
        Flexible(
            child: Text.rich(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  text: 'VERTEX ',
                  style: t.titleLarge?.copyWith(
                      color: p.tizaBlanca,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4),
                  children: [
                    TextSpan(
                        text: 'AI Pyme',
                        style: TextStyle(
                            color: p.tizaSuave,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0)),
                  ],
                ))),
      ]);

  @override
  Widget build(BuildContext context) {
    final escritorio = esEscritorio(context);
    final secciones = _secciones(escritorio);
    if (!secciones.contains(_actual)) _actual = secciones.first;
    return escritorio
        ? _escritorio(context, secciones)
        : _celular(context, secciones);
  }

  Widget _cuerpo(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: quieto ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _page(_actual),
    );
  }

  Widget _celular(BuildContext context, List<SeccionInicio> secciones) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    // Cada sección tiene su tiza: el indicador de la barra toma ese color.
    final indicador = switch (_actual) {
      SeccionInicio.clientes => p.fiadoFondo,
      SeccionInicio.asistente => p.asistenteFondo,
      _ => p.ventasFondo,
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _marca(t, p),
        actions: _acciones(context),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(alignment: Alignment.centerLeft, child: PildoraSync()),
          ),
        ),
      ),
      body: _cuerpo(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: secciones.indexOf(_actual),
        indicatorColor: indicador,
        onDestinationSelected: (i) => setState(() => _actual = secciones[i]),
        destinations: [
          for (final s in secciones)
            NavigationDestination(
              icon: Icon(_datos(s).icono),
              selectedIcon: Icon(_datos(s).elegido, color: _colorSeccion(s, p)),
              label: s == SeccionInicio.caja ? 'Caja' : _datos(s).nombre,
            ),
        ],
      ),
    );
  }

  /// En el computador: menú lateral de pizarra, barra arriba con el nombre
  /// de la sección y atajos de teclado (F2 abre la caja rápida, Ctrl+1…7
  /// cambia de sección).
  Widget _escritorio(BuildContext context, List<SeccionInicio> secciones) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final extendido = MediaQuery.sizeOf(context).width >= anchoMenuExtendido;
    final atajos = <ShortcutActivator, VoidCallback>{
      if (secciones.contains(SeccionInicio.vender))
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            _irA(SeccionInicio.vender),
      for (final (i, s) in secciones.indexed.take(9))
        SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
            control: true): () => _irA(s),
    };
    final menu = NavigationRail(
      extended: extendido,
      minExtendedWidth: 232,
      backgroundColor: p.pizarra,
      indicatorColor: p.tizaBlanca.withValues(alpha: 0.16),
      selectedIndex: secciones.indexOf(_actual),
      onDestinationSelected: (i) => setState(() => _actual = secciones[i]),
      labelType: extendido
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      selectedLabelTextStyle: t.labelLarge
          ?.copyWith(color: p.tizaBlanca, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: t.labelLarge?.copyWith(color: p.tizaSuave),
      selectedIconTheme: IconThemeData(color: p.ventasTiza),
      unselectedIconTheme: IconThemeData(color: p.tizaSuave),
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
        child:
            extendido ? _marca(t, p) : const LogoVertex(tam: 36, animar: true),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: extendido
                ? const SizedBox(width: 208, child: PildoraSync())
                : const _SyncIcono(),
          ),
        ),
      ),
      destinations: [
        for (final s in secciones)
          NavigationRailDestination(
            icon: Tooltip(
              message: _datos(s).nombre,
              child: Icon(_datos(s).icono, key: ValueKey('menu_${s.name}')),
            ),
            selectedIcon: Icon(_datos(s).elegido),
            label: Text(_datos(s).nombre),
          ),
      ],
    );
    return CallbackShortcuts(
      bindings: atajos,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            menu,
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  titleSpacing: 24,
                  title: Text(_datos(_actual).nombre),
                  actions: _acciones(context),
                ),
                body: _cuerpo(context),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Las herramientas como sección propia del menú lateral.
class _HerramientasSeccion extends StatelessWidget {
  const _HerramientasSeccion({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: const [
          AnchoContenido(maxAncho: 1200, child: HerramientasGrid())
        ],
      );
}

/// Estado de sincronización en el menú lateral angosto: solo el icono.
class _SyncIcono extends StatelessWidget {
  const _SyncIcono();

  @override
  Widget build(BuildContext context) {
    final s = SyncService.instance;
    final p = Paleta.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([s.estado, s.pendientes, s.errores]),
      builder: (context, _) {
        final e = s.estado.value;
        final icono = switch (e) {
          EstadoSync.sincronizado => Icons.cloud_done_outlined,
          EstadoSync.sincronizando => Icons.sync,
          EstadoSync.conErrores => Icons.error_outline,
          EstadoSync.soloLocal => Icons.computer,
          _ => Icons.cloud_off_outlined,
        };
        return IconButton(
          tooltip: textoEstado(e, s.pendientes.value, s.errores.value),
          onPressed: () =>
              e == EstadoSync.conErrores ? s.reintentarErrores() : s.sync(),
          icon: Icon(icono, color: p.tizaSuave),
        );
      },
    );
  }
}

/// Avatar de la cuenta: iniciales si hay sesión, icono si no.
class _BotonCuenta extends StatelessWidget {
  const _BotonCuenta();
  @override
  Widget build(BuildContext context) {
    final s = SyncService.instance;
    return AnimatedBuilder(
      animation: s.estado,
      builder: (context, _) {
        final correo = correoSesion();
        return IconButton(
          tooltip: correo == null ? 'Entrar o crear cuenta' : 'Tu cuenta',
          onPressed: () => mostrarLogin(context),
          icon: correo == null
              ? const Icon(Icons.account_circle_outlined, size: 28)
              : AvatarCliente(nombre: correo, clave: correo, tam: 30),
        );
      },
    );
  }
}

/// Píldora que dice siempre si los datos están en la nube o solo en el
/// celular. Lo recién subido queda a la vista hasta que el usuario la toca.
class PildoraSync extends StatelessWidget {
  const PildoraSync({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SyncService.instance;
    final p = Paleta.of(context);
    return AnimatedBuilder(
      animation:
          Listenable.merge([s.estado, s.pendientes, s.errores, s.subidos]),
      builder: (context, _) {
        final e = s.estado.value;
        final subidos = s.subidos.value;
        final (Color tiza, IconData icono) = switch (e) {
          EstadoSync.sincronizado => (p.ventasTiza, Icons.cloud_done_outlined),
          EstadoSync.sincronizando => (p.asistenteTiza, Icons.sync),
          EstadoSync.conErrores => (p.gastosTiza, Icons.error_outline),
          EstadoSync.soloLocal => (p.tizaSuave, Icons.smartphone),
          _ => (p.fiadoTiza, Icons.cloud_off_outlined),
        };
        var texto = textoEstado(e, s.pendientes.value, s.errores.value);
        final resaltar = e == EstadoSync.sincronizado && subidos > 0;
        if (resaltar) {
          texto =
              'Sincronizado · ${subidos == 1 ? '1 registro subido' : '$subidos registros subidos'}';
        }
        return Semantics(
          button: true,
          label: texto,
          child: Material(
            color: resaltar
                ? tiza.withValues(alpha: 0.22)
                : p.tizaBlanca.withValues(alpha: 0.08),
            shape: StadiumBorder(
                side: BorderSide(
                    color: tiza.withValues(alpha: resaltar ? 0.9 : 0.35))),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                s.verSubidos();
                e == EstadoSync.conErrores ? s.reintentarErrores() : s.sync();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (e == EstadoSync.sincronizando)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: tiza),
                      )
                    else
                      Icon(icono, size: 16, color: tiza),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        texto,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: p.tizaBlanca),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Secciones de la barra de abajo.
enum SeccionInicio {
  inicio,
  vender,
  caja,
  catalogo,
  clientes,
  herramientas,
  asistente
}
