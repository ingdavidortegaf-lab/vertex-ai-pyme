import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import '../domain/modo_negocio.dart';
import 'campo_telefono.dart';
import 'comun.dart';
import 'ilustraciones.dart';
import 'negocio_page.dart';
import 'notificaciones.dart';
import 'tema.dart';

/// Muestra el registro guiado la primera vez; después, la app.
class RegistroGate extends StatefulWidget {
  final Widget child;
  const RegistroGate({super.key, required this.child});
  @override
  State<RegistroGate> createState() => _RegistroGateState();
}

class _RegistroGateState extends State<RegistroGate> {
  bool? _listo;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.cargarModo().then((m) {
      if (mounted) setState(() => _listo = m.configurado);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_listo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_listo!) return widget.child;
    return RegistroNegocioPage(onListo: () => setState(() => _listo = true));
  }
}

/// Registro guiado del negocio: la app pregunta y se adapta.
/// 1) Nombre y tipo · 2) ¿Qué vendes? · 3) ¿Cómo trabajas?
/// 4) Datos para los documentos · 5) Así quedó tu app.
class RegistroNegocioPage extends StatefulWidget {
  /// Se llama al terminar. Si es null (abierto desde el menú), se cierra.
  final VoidCallback? onListo;
  const RegistroNegocioPage({super.key, this.onListo});
  @override
  State<RegistroNegocioPage> createState() => _RegistroNegocioPageState();
}

class _RegistroNegocioPageState extends State<RegistroNegocioPage> {
  final _pag = PageController();
  int _paso = 0;
  static const _pasos = 5;

  final _nombre = TextEditingController();
  final _nit = TextEditingController();
  final _dir = TextEditingController();
  var _tel = TelefonoCtrl();
  final _meta = TextEditingController();
  String _tipo = '';
  String _logo = '';
  ModoNegocio _modo = const ModoNegocio();
  bool _sugerido = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = LocalDb.instance;
    final n = await db.perfilNegocio();
    final m = await db.cargarModo();
    if (!mounted) return;
    setState(() {
      _nombre.text = n.nombre;
      _nit.text = n.nit;
      _dir.text = n.direccion;
      _tel.dispose();
      _tel = TelefonoCtrl(n.telefono);
      _meta.text = n.meta > 0 ? cop(n.meta).substring(1) : '';
      _tipo = n.tipo;
      _logo = n.logo;
      _modo = m;
      _sugerido = m.configurado;
    });
  }

  @override
  void dispose() {
    _tel.dispose();
    for (final c in [_nombre, _nit, _dir, _meta]) {
      c.dispose();
    }
    _pag.dispose();
    super.dispose();
  }

  void _ir(int paso) {
    FocusScope.of(context).unfocus();
    setState(() => _paso = paso);
    _pag.animateToPage(paso,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic);
  }

  void _siguiente() {
    if (_paso == 0) {
      if (_nombre.text.trim().length < 2) {
        avisar('Escribe el nombre de tu negocio');
        return;
      }
      // La primera vez se proponen respuestas según el tipo de negocio.
      if (!_sugerido && _tipo.isNotEmpty) {
        _modo = sugerenciaPorTipo(_tipo);
        _sugerido = true;
      }
    }
    if (_paso == 3) {
      if (_tel.valor == null) {
        avisar(_tel.pais.codigo == '57'
            ? 'WhatsApp: celular colombiano de 10 dígitos que empiece por 3'
            : 'WhatsApp: revisa el número; en ${_tel.pais.nombre} se escribe como ${_tel.pais.ejemplo}');
        return;
      }
      if (_meta.text.trim().isNotEmpty && parseMonto(_meta.text) == null) {
        avisar('La meta debe ser un valor en pesos');
        return;
      }
    }
    if (_paso < _pasos - 1) {
      _ir(_paso + 1);
    } else {
      _terminar();
    }
  }

  Future<void> _terminar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    final db = LocalDb.instance;
    try {
      await db.setAjuste('negocio_nombre',
          _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '));
      await db.setAjuste('negocio_tipo', _tipo);
      await db.setAjuste('negocio_nit', _nit.text.trim());
      await db.setAjuste('negocio_direccion', _dir.text.trim());
      await db.setAjuste(
          'negocio_telefono', _tel.valor ?? '');
      await db.setAjuste(
          'negocio_meta', (parseMonto(_meta.text) ?? 0).toStringAsFixed(0));
      await db.setAjuste('negocio_logo', _logo);
      var modo = _modo.copia(configurado: true);
      if (!modo.vendeProductos) {
        modo = modo.copia(gramera: false, codigos: false, pedidos: false);
      }
      await db.guardarModo(modo);
      if (modo.avisos) await Avisos.instance.pedirPermiso();
      if (!mounted) return;
      if (widget.onListo != null) {
        widget.onListo!();
      } else {
        Navigator.of(context).pop();
        avisar('Listo: la app quedó ajustada a tu negocio');
      }
    } catch (_) {
      avisar('No se pudo guardar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.onListo == null
          ? AppBar(title: const Text('Ajustar la app'))
          : null,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              if (_paso > 0)
                IconButton(
                    tooltip: 'Atrás',
                    onPressed: () => _ir(_paso - 1),
                    icon: const Icon(Icons.arrow_back))
              else
                const SizedBox(width: 48, child: LogoVertex(tam: 28)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: (_paso + 1) / _pasos,
                      minHeight: 8,
                      color: p.ventas),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_paso + 1} de $_pasos', style: t.bodySmall),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _pag,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _pasoNombre(),
                _pasoOferta(),
                _pasoTrabajo(),
                _pasoDatos(),
                _pasoResumen()
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando ? null : _siguiente,
                child: Text(_paso == _pasos - 1
                    ? (_guardando ? 'Guardando…' : 'Empezar a usar la app')
                    : 'Siguiente'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _marco(
      {required String titulo,
      String? texto,
      Widget? dibujo,
      required List<Widget> hijos}) {
    final t = Theme.of(context).textTheme;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        children: [
          if (dibujo != null)
            Center(child: SizedBox(width: 200, height: 110, child: dibujo)),
          Text(titulo, style: t.headlineSmall),
          if (texto != null) ...[
            const SizedBox(height: 6),
            Text(texto,
                style: t.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          ...hijos,
        ]);
  }

  Widget _pasoNombre() => _marco(
        titulo: 'Cuéntanos de tu negocio',
        texto: 'Con tus respuestas la app se arma a la medida de tu negocio. '
            'Todo se guarda en tu celular y lo puedes cambiar después.',
        dibujo: const IlustracionPizarra(),
        hijos: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            decoration: const InputDecoration(
                labelText: '¿Cómo se llama tu negocio?',
                hintText: 'Ej.: Tienda Doña Marta',
                counterText: ''),
          ),
          const SizedBox(height: 16),
          Text('¿Qué tipo de negocio es?',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final x in tiposNegocio)
              ChoiceChip(
                label: Text(conEmoji(x)),
                selected: _tipo == x,
                onSelected: (_) => setState(() {
                  _tipo = x;
                  if (!_modo.configurado) _sugerido = false;
                }),
              ),
          ]),
        ],
      );

  Widget _opcion(Oferta o, IconData icono, String titulo, String sub) {
    final sel = _modo.oferta == o;
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: sel ? esquema.primary : esquema.outlineVariant,
              width: sel ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _modo = _modo.copia(oferta: o)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icono,
                  size: 32,
                  color: sel ? esquema.primary : esquema.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(sub, style: Theme.of(context).textTheme.bodySmall),
                    ]),
              ),
              Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: sel ? esquema.primary : esquema.outline),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pasoOferta() => _marco(
        titulo: '¿Qué vendes?',
        texto: 'Así sabemos si llevar inventario, servicios o las dos cosas.',
        hijos: [
          _opcion(Oferta.productos, Icons.inventory_2_outlined, 'Productos',
              'Mercancía con inventario: arroz, droguería, insumos…'),
          _opcion(Oferta.servicios, Icons.handyman_outlined, 'Servicios',
              'Cortes, reparaciones, domicilios, asesorías… sin inventario'),
          _opcion(
              Oferta.ambos,
              Icons.storefront_outlined,
              'Productos y servicios',
              'Por ejemplo, vendes repuestos y también los instalas'),
        ],
      );

  Widget _interruptor(String titulo, String sub, bool valor,
          ValueChanged<bool> cambio, IconData icono) =>
      Card(
        child: SwitchListTile(
          secondary: Icon(icono),
          title: Text(titulo),
          subtitle: Text(sub),
          value: valor,
          onChanged: (v) => setState(() => cambio(v)),
        ),
      );

  Widget _pasoTrabajo() => _marco(
        titulo: '¿Cómo trabajas?',
        texto: 'Activa solo lo que usas; lo demás no aparece para no estorbar.',
        hijos: [
          _interruptor(
              '¿Le fías a tus clientes?',
              'Cuaderno de fiados, cartera y cuentas de cobro',
              _modo.fia,
              (v) => _modo = _modo.copia(fia: v),
              Icons.menu_book_outlined),
          if (_modo.vendeProductos) ...[
            _interruptor(
                '¿Vendes por peso con gramera?',
                'Kilos y libras, etiquetas de báscula',
                _modo.gramera,
                (v) => _modo = _modo.copia(gramera: v),
                Icons.scale_outlined),
            _interruptor(
                '¿Usas códigos de barras?',
                'Con la cámara o un lector USB',
                _modo.codigos,
                (v) => _modo = _modo.copia(codigos: v),
                Icons.qr_code_scanner),
            _interruptor(
                '¿Le haces pedidos a proveedores?',
                'Pedido sugerido y PDF para el proveedor',
                _modo.pedidos,
                (v) => _modo = _modo.copia(pedidos: v),
                Icons.local_shipping_outlined),
          ],
          // En la versión web (Safari) no hay avisos del sistema.
          if (!kIsWeb)
          _interruptor(
              'Avisos en el celular',
              'Se agotó un producto, cobros vencidos, meta cumplida',
              _modo.avisos,
              (v) => _modo = _modo.copia(avisos: v),
              Icons.notifications_active_outlined),
        ],
      );

  Widget _pasoDatos() => _marco(
        titulo: 'Datos para tus documentos',
        texto:
            'Salen en comprobantes, cotizaciones, cuentas de cobro e informes. '
            'Todo es opcional.',
        hijos: [
          TextField(
              controller: _nit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NIT o cédula')),
          const SizedBox(height: 12),
          TextField(
              controller: _dir,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Ej.: Cra 20 # 10-15, Bucaramanga')),
          const SizedBox(height: 12),
          CampoTelefono(ctrl: _tel, etiqueta: 'WhatsApp del negocio'),
          const SizedBox(height: 12),
          TextField(
              controller: _meta,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Meta de ventas del mes (opcional)',
                  prefixText: r'$ ')),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: VistaLogo(logo: _logo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final r = await elegirLogoNegocio();
                  if (r != null && mounted) setState(() => _logo = r);
                },
                icon: const Icon(Icons.upload_outlined),
                label:
                    Text(_logo.isEmpty ? 'Subir el logo' : 'Cambiar el logo'),
              ),
            ),
          ]),
        ],
      );

  Widget _pasoResumen() {
    final m = _modo;
    final pal = Paleta.of(context);
    final items = [
      (
        Icons.store_outlined,
        _nombre.text.trim().isEmpty ? 'Tu negocio' : _nombre.text.trim()
      ),
      (
        Icons.inventory_2_outlined,
        'La pestaña del catálogo se llamará «${m.nombreCatalogo}»'
      ),
      if (m.vendeServicios)
        (Icons.handyman_outlined, 'Puedes crear servicios sin inventario'),
      if (m.fia)
        (
          Icons.menu_book_outlined,
          'Fiados con cartera por edades y cuentas de cobro en PDF'
        )
      else
        (Icons.payments_outlined, 'Ventas de contado (sin fiados)'),
      if (m.vendeProductos && m.gramera)
        (Icons.scale_outlined, 'Ventas por peso con gramera'),
      if (m.vendeProductos && m.codigos)
        (Icons.qr_code_scanner, 'Lector de códigos de barras'),
      if (m.vendeProductos && m.pedidos)
        (Icons.local_shipping_outlined, 'Pedidos al proveedor en PDF'),
      if (m.avisos && !kIsWeb)
        (Icons.notifications_active_outlined, 'Avisos en el celular'),
      (
        Icons.insert_chart_outlined,
        'Informes semanal, quincenal y mensual para tu contador'
      ),
    ];
    return _marco(
      titulo: 'Así quedó tu app',
      texto:
          'Puedes cambiarlo cuando quieras en el menú ⋮ → «Ajustar la app a mi negocio».',
      hijos: [
        for (final (i, x) in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(i, color: pal.ventas),
            title: Text(x),
          ),
      ],
    );
  }
}
