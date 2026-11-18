import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../data/local_db.dart';
import '../domain/contabilidad.dart';
import '../domain/formato.dart';
import '../domain/pagos.dart';
import '../pdf/archivo.dart';
import 'comun.dart';
import 'herramientas_page.dart';
import 'pago_widget.dart';
import '../pdf/reportes_contables.dart';
import 'tema.dart';

// "La oficina" del negocio: informes para el contador, cartera con cuentas
// de cobro y el archivo de todos los documentos emitidos.

final _dia = DateFormat('d/MM/y', 'es_CO');
final _diaHora = DateFormat('d/MM/y h:mm a', 'es_CO');

// ------------------------------------------------------- cuenta de cobro
/// Genera, numera y archiva la cuenta de cobro de un cliente; luego deja
/// enviarla por WhatsApp, imprimirla o compartir el PDF.
Future<void> generarCuentaCobro(BuildContext context, String clienteId) async {
  final db = LocalDb.instance;
  final c = await db.cliente(clienteId);
  if (c == null) return;
  final ahora = DateTime.now();
  final estado =
      estadoDeCuenta(await db.movimientosDeCredito(clienteId), ahora);
  final negocio = await db.perfilNegocio();
  final nombre = c['nombre'] as String;
  final tel = (c['telefono'] as String?) ?? '';
  final documento = await db.emitirDocumento('cobro',
      refId: clienteId,
      clienteId: clienteId,
      clienteNombre: nombre,
      total: estado.saldo,
      resumen: estado.debeDesde == null
          ? 'Al día'
          : 'Debe desde ${_dia.format(estado.debeDesde!)} (${estado.diasMora} días)');
  final numero = documento['numero'] as String;
  final formas = (await db.datosPago()).lineas();
  final reporte = reporteCuentaCobro(
      negocio: negocio,
      numero: numero,
      fecha: ahora,
      cliente: nombre,
      telefono: tel,
      estado: estado,
      formasDePago: formas);
  await archivarDocumento(documento, reporte.pdf);
  if (!context.mounted) return;
  await mostrarDocumento(context,
      titulo: 'Cuenta de cobro N.º $numero',
      texto: textoCuentaCobro(
          negocio: negocio,
          cliente: nombre,
          numero: numero,
          estado: estado,
          fecha: ahora,
          formasDePago: formas),
      telefono: tel,
      pdf: reporte.pdf,
      boton: 'Cobrar por WhatsApp');
}

// -------------------------------------------------------------- informes
class InformesPage extends StatefulWidget {
  const InformesPage({super.key});
  @override
  State<InformesPage> createState() => _InformesPageState();
}

class _InformesPageState extends State<InformesPage> {
  Periodo _p = Periodo.semanaActual;
  DatosInforme? _d;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await cargarInforme(_p, DateTime.now());
    if (mounted) setState(() => _d = d);
  }

  Future<void> _generar() async {
    final d = _d;
    if (d == null || _generando) return;
    setState(() => _generando = true);
    try {
      final db = LocalDb.instance;
      final negocio = await db.perfilNegocio();
      final documento = await db.emitirDocumento('informe',
          total: d.actual.ventas,
          resumen: '${nombresPeriodo[d.periodo]}: ${d.textoPeriodo}');
      final numero = documento['numero'] as String;
      final r = reporteInforme(
          negocio: negocio, numero: numero, fecha: DateTime.now(), d: d);
      await archivarDocumento(documento, r.pdf);
      if (!mounted) return;
      await mostrarDocumento(context,
          titulo: 'Informe N.º $numero',
          texto: textoInforme(negocio, numero, d),
          pdf: r.pdf,
          boton: 'Enviar resumen por WhatsApp',
          nota: 'Envíale el PDF a tu contador con el botón «PDF».');
    } catch (_) {
      avisar('No se pudo generar el informe');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final t = Theme.of(context).textTheme;
    final pal = Paleta.of(context);
    Widget cifra(
            String etq, String valor, String nota, Color fondo, Color tinta) =>
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: fondo, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etq, style: t.bodySmall?.copyWith(color: tinta)),
            const SizedBox(height: 2),
            Text(valor, style: cifras(t.titleLarge)),
            if (nota.isNotEmpty) Text(nota, style: t.bodySmall),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Informes')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Elige el periodo', style: t.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in Periodo.values)
            ChoiceChip(
              label: Text(nombresPeriodo[p]!),
              selected: _p == p,
              onSelected: (_) {
                setState(() {
                  _p = p;
                  _d = null;
                });
                _load();
              },
            ),
        ]),
        const SizedBox(height: 16),
        if (d == null)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else ...[
          Text('Del ${d.textoPeriodo}', style: t.bodyMedium),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: [
              cifra(
                  'Ventas',
                  cop(d.actual.ventas),
                  '${variacion(d.actual.ventas, d.anterior.ventas)} vs. anterior',
                  pal.ventasFondo,
                  pal.ventas),
              cifra(
                  'Gastos',
                  cop(d.actual.gastos),
                  '${variacion(d.actual.gastos, d.anterior.gastos)} vs. anterior',
                  pal.gastosFondo,
                  pal.gastos),
              cifra('Utilidad', cop(d.actual.utilidad), 'ventas - gastos',
                  pal.asistenteFondo, pal.asistente),
              cifra('Caja neta', cop(d.cajaNeta), 'contado + abonos - gastos',
                  pal.ventasFondo, pal.ventas),
              cifra(
                  'Por cobrar',
                  cop(d.carteraTotal),
                  d.deudores.length == 1
                      ? '1 cliente'
                      : '${d.deudores.length} clientes',
                  pal.fiadoFondo,
                  pal.fiado),
              cifra('Inventario', cop(d.valorCosto), 'valor al costo',
                  pal.asistenteFondo, pal.asistente),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('El PDF incluye', style: t.titleSmall),
                    const SizedBox(height: 6),
                    for (final x in const [
                      'Estado de resultados frente al periodo anterior',
                      'Flujo de caja (lo que entró y salió en efectivo)',
                      'Ventas por día y productos más vendidos',
                      'Gastos por concepto',
                      'Cartera por antigüedad y lista de quién debe',
                      'Inventario por reponer y su valor',
                      'Libro de movimientos para el contador',
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Icon(Icons.check_circle_outline,
                              size: 18, color: pal.ventas),
                          const SizedBox(width: 8),
                          Expanded(child: Text(x, style: t.bodyMedium)),
                        ]),
                      ),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _generando ? null : _generar,
            icon: _generando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_generando ? 'Generando…' : 'Generar informe en PDF'),
          ),
        ],
      ]),
    );
  }
}

// --------------------------------------------------------------- cartera
class CarteraPage extends StatefulWidget {
  const CarteraPage({super.key});
  @override
  State<CarteraPage> createState() => _CarteraPageState();
}

class _CarteraPageState extends State<CarteraPage> {
  List<(String id, String nombre, EstadoCuenta e)>? _l;

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
    final ahora = DateTime.now();
    final credito = await db.creditoPorCliente();
    final nombres = {
      for (final c in await db.clientes())
        c['id'] as String: c['nombre'] as String
    };
    final l = [
      for (final e in credito.entries)
        if (nombres.containsKey(e.key))
          (e.key, nombres[e.key]!, estadoDeCuenta(e.value, ahora))
    ]
      ..removeWhere((x) => x.$3.saldo <= 0.5)
      ..sort((a, b) => b.$3.diasMora.compareTo(a.$3.diasMora));
    if (mounted) setState(() => _l = l);
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final t = Theme.of(context).textTheme;
    final pal = Paleta.of(context);
    final edades = carteraPorEdades((l ?? const []).map((x) => x.$3));
    final total = edades.values.fold(0.0, (s, x) => s + x);
    Color color(int dias) => dias > 60
        ? Theme.of(context).colorScheme.error
        : dias > 30
            ? pal.fiado
            : pal.ventas;
    return Scaffold(
      appBar: AppBar(title: const Text('Cartera: quién debe')),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total por cobrar', style: t.bodySmall),
                        Text(cop(total), style: cifras(t.headlineMedium)),
                        const SizedBox(height: 10),
                        Row(children: [
                          for (final (r, etq) in const [
                            ('0-30', '0-30 días'),
                            ('31-60', '31-60'),
                            ('61-90', '61-90'),
                            ('90+', '+90'),
                          ])
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(etq, style: t.bodySmall),
                                    Text(cop(edades[r] ?? 0),
                                        style: cifras(t.titleSmall)),
                                  ]),
                            ),
                        ]),
                      ]),
                ),
              ),
              const SizedBox(height: 8),
              if (l.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nadie te debe. ¡Cuentas al día!',
                        textAlign: TextAlign.center)),
              for (final (id, nombre, e) in l)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color(e.diasMora).withValues(alpha: .15),
                      child: Text('${e.diasMora}',
                          style: TextStyle(
                              color: color(e.diasMora),
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(nombre),
                    subtitle:
                        Text('Debe desde el ${_dia.format(e.debeDesde!)} · '
                            '${e.diasMora} ${e.diasMora == 1 ? 'día' : 'días'}'),
                    trailing: Text(cop(e.saldo), style: cifras(t.titleMedium)),
                    onTap: () => generarCuentaCobro(context, id),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                  'Toca un cliente para generar su cuenta de cobro en PDF con el detalle '
                  'de cada fiado, los abonos y desde cuándo debe.',
                  style: t.bodySmall),
            ]),
    );
  }
}

// ---------------------------------------------------- documentos emitidos
const nombresTipoDoc = {
  'venta': 'Comprobantes',
  'cotizacion': 'Cotizaciones',
  'cobro': 'Cuentas de cobro',
  'pedido': 'Pedidos',
  'informe': 'Informes',
};

const _iconosTipoDoc = {
  'venta': Icons.receipt_outlined,
  'cotizacion': Icons.request_quote_outlined,
  'cobro': Icons.account_balance_wallet_outlined,
  'pedido': Icons.local_shipping_outlined,
  'informe': Icons.insert_chart_outlined,
};

class DocumentosPage extends StatefulWidget {
  const DocumentosPage({super.key});
  @override
  State<DocumentosPage> createState() => _DocumentosPageState();
}

class _DocumentosPageState extends State<DocumentosPage> {
  String? _tipo;
  String _buscar = '';
  List<Map<String, Object?>>? _l;

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
    final l = await LocalDb.instance.documentos(tipo: _tipo, limite: 1000);
    if (mounted) setState(() => _l = l);
  }

  Future<void> _abrir(Map<String, Object?> d) async {
    final bytes = await leerArchivado(d['archivo'] as String?);
    if (!mounted) return;
    if (bytes == null) {
      avisar(
          'El PDF no está en este equipo. Vuelve a generarlo desde donde se creó.');
      return;
    }
    final nombre = nombreArchivo(d['numero'] as String);
    await showModalBottomSheet<void>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text('N.º ${d['numero']}',
                style: Theme.of(s).textTheme.titleLarge),
            subtitle: Text([
              nombresTipoDoc[d['tipo']] ?? '',
              if ((d['cliente_nombre'] as String?)?.isNotEmpty ?? false)
                d['cliente_nombre'],
              _diaHora.format(DateTime.parse(d['fecha'] as String).toLocal()),
            ].join(' · ')),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Compartir PDF (WhatsApp, correo…)'),
            onTap: () {
              Navigator.pop(s);
              Printing.sharePdf(bytes: bytes, filename: nombre);
            },
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Imprimir'),
            onTap: () {
              Navigator.pop(s);
              Printing.layoutPdf(name: nombre, onLayout: (_) async => bytes);
            },
          ),
          if (Platform.isWindows)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Abrir la carpeta de documentos'),
              onTap: () async {
                Navigator.pop(s);
                final dir = await carpetaDocumentos();
                await Process.run('explorer', [dir.path]);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = normalizarTexto(_buscar.trim());
    final l = [
      for (final d in _l ?? const <Map<String, Object?>>[])
        if (q.isEmpty ||
            normalizarTexto(
                    '${d['numero']} ${d['cliente_nombre'] ?? ''} ${d['resumen'] ?? ''}')
                .contains(q))
          d
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos emitidos')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por número o cliente'),
            onChanged: (v) => setState(() => _buscar = v),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _tipo == null,
                    onSelected: (_) {
                      _tipo = null;
                      _load();
                    }),
              ),
              for (final e in nombresTipoDoc.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text(e.value),
                      selected: _tipo == e.key,
                      onSelected: (_) {
                        _tipo = e.key;
                        _load();
                      }),
                ),
            ],
          ),
        ),
        Expanded(
          child: _l == null
              ? const Center(child: CircularProgressIndicator())
              : l.isEmpty
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'Aquí quedan todos los comprobantes, cotizaciones, cuentas de '
                          'cobro, pedidos e informes que generes, cada uno con su número.',
                          textAlign: TextAlign.center),
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: l.length,
                      itemBuilder: (_, i) {
                        final d = l[i];
                        final cliente = (d['cliente_nombre'] as String?) ?? '';
                        return Card(
                          child: ListTile(
                            leading: Icon(_iconosTipoDoc[d['tipo']] ??
                                Icons.description_outlined),
                            title: Text('${d['numero']}',
                                style: cifras(t.titleSmall)),
                            subtitle: Text([
                              if (cliente.isNotEmpty) cliente,
                              _diaHora.format(
                                  DateTime.parse(d['fecha'] as String)
                                      .toLocal()),
                            ].join(' · ')),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(cop((d['total'] as num).toDouble()),
                                    style: cifras(t.bodyMedium)),
                                Icon(
                                    d['archivo'] == null
                                        ? Icons.cloud_off_outlined
                                        : Icons.picture_as_pdf_outlined,
                                    size: 16),
                              ],
                            ),
                            onTap: () => _abrir(d),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------- cierre de caja
/// Cierre de caja del día: cuánto entró por cada medio de pago, cuánto
/// efectivo debería haber y la diferencia con lo que se cuenta.
class CierreCajaPage extends StatefulWidget {
  const CierreCajaPage({super.key});
  @override
  State<CierreCajaPage> createState() => _CierreCajaPageState();
}

class _CierreCajaPageState extends State<CierreCajaPage> {
  PorMedio? _m;
  int _nMovs = 0;
  final _base = TextEditingController();
  final _contado = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _base.dispose();
    _contado.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final db = LocalDb.instance;
    final hoy = DateTime.now();
    final desde = DateTime(hoy.year, hoy.month, hoy.day);
    final movs = await db.movimientosEntre(desde, desde.add(const Duration(days: 1)));
    final base = double.tryParse(await db.ajuste('caja_base') ?? '') ?? 0;
    if (!mounted) return;
    setState(() {
      _m = porMedio(movs);
      _nMovs = movs.length;
      if (_base.text.isEmpty && base > 0) _base.text = cop(base).substring(1);
    });
  }

  double get _baseV => parseMonto(_base.text) ?? 0;

  String _texto(PorMedio m) {
    final esperado = m.efectivoEsperado(_baseV);
    final contado = parseMonto(_contado.text);
    final b = StringBuffer()
      ..writeln('*Cierre de caja ${_dia.format(DateTime.now())}*')
      ..writeln();
    for (final x in m.medios) {
      b.writeln('${nombresMedio[x]}: entró ${cop(m.entrada(x))}'
          '${m.salida(x) > 0 ? ', salió ${cop(m.salida(x))}' : ''}');
    }
    b
      ..writeln()
      ..writeln('Base: ${cop(_baseV)}')
      ..writeln('Efectivo esperado: ${cop(esperado)}');
    if (contado != null) {
      final dif = contado - esperado;
      b.writeln('Efectivo contado: ${cop(contado)} '
          '(${dif.abs() < 1 ? 'cuadra' : dif > 0 ? 'sobran ${cop(dif)}' : 'faltan ${cop(-dif)}'})');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final t = Theme.of(context).textTheme;
    final pal = Paleta.of(context);
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cierre de caja de hoy'), actions: [
        IconButton(
          tooltip: 'Datos para recibir pagos',
          icon: const Icon(Icons.account_balance_wallet_outlined),
          onPressed: () => mostrarDatosPago(context),
        ),
      ]),
      body: m == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('$_nMovs movimientos hoy', style: t.bodyMedium),
              const SizedBox(height: 10),
              Card(
                child: Column(children: [
                  if (m.medios.isEmpty)
                    const Padding(padding: EdgeInsets.all(20), child: Text('Todavía no hay pagos hoy.')),
                  for (final x in m.medios)
                    ListTile(
                      leading: Icon(iconosMedio[x]),
                      title: Text(nombresMedio[x]!),
                      subtitle: m.salida(x) > 0 ? Text('Pagos y gastos: ${cop(m.salida(x))}') : null,
                      trailing: Text(cop(m.entrada(x)), style: cifras(t.titleMedium?.copyWith(color: pal.ventas))),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Cuadre del efectivo', style: t.titleMedium),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _base,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Base inicial', prefixText: r'$ '),
                    onChanged: (v) {
                      setState(() {});
                      LocalDb.instance.setAjuste('caja_base', (parseMonto(v) ?? 0).toStringAsFixed(0));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _contado,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Efectivo contado', prefixText: r'$ '),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final esperado = m.efectivoEsperado(_baseV);
                final contado = parseMonto(_contado.text);
                final dif = contado == null ? null : contado - esperado;
                final color = dif == null || dif.abs() < 1 ? pal.ventas : esquema.error;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: pal.ventasFondo, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Efectivo que debería haber', style: t.bodySmall),
                    Text(cop(esperado), style: cifras(t.headlineMedium)),
                    Text('Base + efectivo recibido − gastos pagados en efectivo', style: t.bodySmall),
                    if (dif != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          dif.abs() < 1
                              ? 'La caja cuadra'
                              : dif > 0
                                  ? 'Sobran ${cop(dif)}'
                                  : 'Faltan ${cop(-dif)}',
                          style: t.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                );
              }),
              const SizedBox(height: 12),
              Text('Lo recibido por Nequi, Daviplata, bancos y tarjetas (${cop(m.totalDigital)}) '
                  'se revisa en la app de cada banco.', style: t.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => enviarWhatsApp(_texto(m)),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Enviar el cierre por WhatsApp'),
              ),
            ]),
    );
  }
}
