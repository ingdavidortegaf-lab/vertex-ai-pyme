import 'package:flutter/material.dart';
import '../data/sync_service.dart';
import 'asistente_page.dart';
import 'clientes_page.dart';
import 'login_page.dart';
import 'privacidad_page.dart';
import 'tablero_page.dart';
import 'ventas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _i = 0;

  Widget _page() => switch (_i) {
        0 => const ClientesPage(key: ValueKey('c')),
        1 => const VentasPage(key: ValueKey('v')),
        2 => const TableroPage(key: ValueKey('t')),
        _ => const AsistentePage(key: ValueKey('a')),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VERTEX AI Pyme'),
        actions: [
          IconButton(
              tooltip: 'Cuenta',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => mostrarLogin(context)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'privacidad') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PrivacidadPage()));
              } else if (v == 'sync') {
                SyncService.instance.reintentarErrores();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sync', child: Text('Sincronizar ahora')),
              PopupMenuItem(
                  value: 'privacidad', child: Text('Privacidad y datos')),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: BarraSync(),
        ),
      ),
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Movimientos'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Tablero'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'Asistente'),
        ],
      ),
    );
  }
}

/// Barra que dice siempre si los datos están en la nube o solo en el celular.
class BarraSync extends StatelessWidget {
  const BarraSync({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SyncService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([s.estado, s.pendientes, s.errores]),
      builder: (context, _) {
        final e = s.estado.value;
        final (Color fondo, IconData icono) = switch (e) {
          EstadoSync.sincronizado => (Colors.green.shade100, Icons.cloud_done),
          EstadoSync.sincronizando => (Colors.blue.shade100, Icons.sync),
          EstadoSync.conErrores => (Colors.red.shade100, Icons.error_outline),
          EstadoSync.soloLocal => (Colors.grey.shade200, Icons.phone_android),
          _ => (Colors.amber.shade100, Icons.cloud_off),
        };
        return Material(
          color: fondo,
          child: InkWell(
            onTap: () => e == EstadoSync.conErrores
                ? s.reintentarErrores()
                : s.sync(),
            child: SizedBox(
              height: 30,
              width: double.infinity,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icono, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    textoEstado(e, s.pendientes.value, s.errores.value),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
