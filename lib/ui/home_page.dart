import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import 'asistente_page.dart';
import 'clientes_page.dart';
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
  int _i = 0;

  @override
  void initState() {
    super.initState();
    // La app se adapta a las respuestas del registro guiado.
    LocalDb.instance.modo.addListener(_refrescar);
    // Avisos en el celular (agotados, cobros vencidos, meta cumplida).
    Avisos.instance.vigilar();
  }

  @override
  void dispose() {
    LocalDb.instance.modo.removeListener(_refrescar);
    super.dispose();
  }

  void _refrescar() => setState(() {});

  void _ir(int i) => setState(() => _i = i);

  Widget _page() => switch (_i) {
        0 => TableroPage(key: const ValueKey('t'), onIr: _ir),
        1 => const VentasPage(key: ValueKey('v')),
        2 => const InventarioPage(key: ValueKey('i')),
        3 => const ClientesPage(key: ValueKey('c')),
        _ => const AsistentePage(key: ValueKey('a')),
      };

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    // Cada sección tiene su tiza: el indicador de la barra toma ese color.
    final indicador = [
      p.ventasFondo,
      p.ventasFondo,
      p.ventasFondo,
      p.fiadoFondo,
      p.asistenteFondo
    ][_i];
    final quieto = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const LogoVertex(tam: 32, animar: true),
          const SizedBox(width: 10),
          Text.rich(TextSpan(
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
          )),
        ]),
        actions: [
          const _BotonCuenta(),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (v) {
              if (v == 'privacidad') {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacidadPage()));
              } else if (v == 'negocio') {
                mostrarMiNegocio(context);
              } else if (v == 'pagos') {
                mostrarDatosPago(context);
              } else if (v == 'ajustar') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RegistroNegocioPage()));
              } else if (v == 'sync') {
                SyncService.instance.reintentarErrores();
              }
            },
            itemBuilder: (_) => const [
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
              PopupMenuItem(
                value: 'sync',
                child: ListTile(
                    leading: Icon(Icons.sync),
                    title: Text('Sincronizar ahora'),
                    contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'privacidad',
                child: ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Privacidad y datos'),
                    contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(alignment: Alignment.centerLeft, child: PildoraSync()),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: quieto ? Duration.zero : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _page(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        indicatorColor: indicador,
        onDestinationSelected: _ir,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard, color: p.ventas),
              label: 'Inicio'),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: p.ventas),
              label: 'Caja'),
          NavigationDestination(
              icon: Icon(LocalDb.instance.modo.value.vendeProductos
                  ? Icons.inventory_2_outlined
                  : Icons.handyman_outlined),
              selectedIcon: Icon(
                  LocalDb.instance.modo.value.vendeProductos
                      ? Icons.inventory_2
                      : Icons.handyman,
                  color: p.ventas),
              label: LocalDb.instance.modo.value.nombreCatalogo),
          NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people, color: p.fiado),
              label: 'Clientes'),
          NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome, color: p.asistente),
              label: 'Asistente'),
        ],
      ),
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
