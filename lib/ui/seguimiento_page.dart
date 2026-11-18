import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import '../domain/seguimiento.dart';
import 'cliente_detalle_page.dart';
import 'comun.dart';
import 'legal_page.dart';
import 'tema.dart';

/// Seguimiento de clientes por WhatsApp: a quién escribirle hoy y qué
/// decirle, con un toque. Solo a quien autorizó la comunicación comercial.
class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({super.key});
  @override
  State<SeguimientoPage> createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage> {
  Map<Grupo, List<ResumenCliente>>? _g;
  var _grupo = Grupo.extranados;
  var _negocio = 'Mi negocio';
  var _variante = 0;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.cambios.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocalDb.instance.cambios.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final db = LocalDb.instance;
    final l = await db.resumenClientes();
    final n = (await db.perfilNegocio()).nombreVisible;
    if (!mounted) return;
    setState(() {
      _negocio = n;
      _g = agruparClientes(l, DateTime.now());
      if (_g![_grupo]!.isEmpty) {
        _grupo = Grupo.values.firstWhere((g) => _g![g]!.isNotEmpty, orElse: () => _grupo);
      }
    });
  }

  Future<void> _escribir(ResumenCliente c) async {
    final ctrl = TextEditingController(text: mensajeSeguimiento(_grupo, c, negocio: _negocio, variante: _variante));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('Mensaje para ${primerNombre(c.nombre)}'),
          content: TextField(controller: ctrl, maxLines: 7, decoration: const InputDecoration(alignLabelWithHint: true)),
          actions: [
            TextButton(
              onPressed: () => set(() {
                _variante++;
                ctrl.text = mensajeSeguimiento(_grupo, c, negocio: _negocio, variante: _variante);
              }),
              child: const Text('Otro mensaje'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(d, true),
              icon: const Icon(Icons.send),
              label: const Text('Abrir WhatsApp'),
            ),
          ],
        ),
      ),
    );
    final texto = ctrl.text;
    ctrl.dispose();
    if (ok != true) return;
    await enviarWhatsApp(texto, telefono: c.telefono);
    await LocalDb.instance.marcarContactado(c.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final t = Theme.of(context).textTheme;
    final pal = Paleta.of(context);
    final esquema = Theme.of(context).colorScheme;
    final ahora = DateTime.now();
    final lista = g?[_grupo] ?? const <ResumenCliente>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento de clientes')),
      body: g == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final x in Grupo.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${nombresGrupo[x]} (${g[x]!.length})'),
                        selected: _grupo == x,
                        onSelected: (_) => setState(() => _grupo = x),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(ayudaGrupo[_grupo]!,
                    key: ValueKey(_grupo), style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
              ),
              const SizedBox(height: 10),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      'Nadie en este grupo por ahora. Registre las ventas con el nombre del cliente '
                      'y aquí irán apareciendo.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium),
                ),
              for (final c in lista)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: pal.ventasFondo,
                          child: Text(c.nombre.isEmpty ? '?' : c.nombre[0].toUpperCase(),
                              style: TextStyle(color: pal.ventas, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.nombre, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                                '${c.compras} ${c.compras == 1 ? 'compra' : 'compras'} · ${cop(c.total)} · '
                                'última hace ${c.diasSinComprar(ahora)} días',
                                style: t.bodySmall),
                          ]),
                        ),
                      ]),
                      if (c.saldo > 0.5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Debe ${cop(c.saldo)} (el cobro va por «Cartera»)',
                              style: t.bodySmall?.copyWith(color: pal.fiado)),
                        ),
                      if (c.contactado != null)
                        Text('Le escribió hace ${ahora.difference(c.contactado!).inDays} días',
                            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ClienteDetallePage(clienteId: c.id))),
                          child: const Text('Ver'),
                        ),
                        if (!c.autorizo)
                          TextButton.icon(
                            onPressed: () => generarAutorizacionCliente(context, c.id),
                            icon: const Icon(Icons.verified_user_outlined),
                            label: const Text('Pedir autorización'),
                          )
                        else if (c.telefono.trim().isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Sin celular'),
                          )
                        else
                          FilledButton.tonalIcon(
                            onPressed: () => _escribir(c),
                            icon: const Icon(Icons.chat_outlined),
                            label: Text(puedeEscribir(c, ahora) ? 'Escribirle' : 'Escribir otra vez'),
                          ),
                      ]),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                  'Por la Ley 1581 solo se sugiere escribir a quien autorizó la comunicación comercial. '
                  'Para no cansar a nadie, espere al menos una semana entre mensajes.',
                  style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
            ]),
    );
  }
}
