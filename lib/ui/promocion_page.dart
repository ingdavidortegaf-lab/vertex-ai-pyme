import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../data/asistente_service.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/documentos.dart';
import '../domain/formato.dart';
import '../domain/promocion.dart';
import '../domain/resumen.dart';
import 'comun.dart';
import 'ilustraciones.dart';
import 'inventario_page.dart';
import 'tema.dart';

/// Promociones: elige productos y precio de oferta, agrega una foto o un
/// video, deja que la IA redacte el texto y compártelo por WhatsApp, en el
/// estado o en redes. También arma una imagen lista para el estado.
class PromocionPage extends StatefulWidget {
  const PromocionPage({super.key});
  @override
  State<PromocionPage> createState() => _PromocionPageState();
}

class _PromocionPageState extends State<PromocionPage> {
  List<ProductoStock> _productos = const [];
  PerfilNegocio _negocio = const PerfilNegocio();
  final _elegidos = <String>{};
  final _precios = <String, TextEditingController>{};
  final _nota = TextEditingController();
  final _texto = TextEditingController();
  final _cartel = GlobalKey();
  var _estilo = EstiloPromo.alegre;
  var _domicilios = false;
  var _variante = 0;
  var _editado = false;
  var _pensando = false;
  var _hechoPorIA = false;
  XFile? _media;
  Uint8List? _foto;
  var _esVideo = false;

  bool get _hayCamara =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    () async {
      final db = LocalDb.instance;
      final ps = (await db.productos()).where((x) => x.stock > 0 || x.esServicio).toList();
      final n = await db.perfilNegocio();
      if (mounted) {
        setState(() {
          _productos = ps;
          _negocio = n;
          if (ocasionDelMomento(DateTime.now()).nombre != 'Hoy') _estilo = EstiloPromo.temporada;
        });
      }
    }();
  }

  @override
  void dispose() {
    for (final c in _precios.values) {
      c.dispose();
    }
    _nota.dispose();
    _texto.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(ProductoStock p) =>
      _precios.putIfAbsent(p.id, () => TextEditingController(text: p.precio.toStringAsFixed(0)));

  List<ProductoPromo> get _lista => [
        for (final p in _productos)
          if (_elegidos.contains(p.id)) ProductoPromo(p.nombre, parseMonto(_ctrl(p).text) ?? p.precio, p.precio)
      ];

  /// Vuelve a redactar con el redactor del celular (si la persona no ha
  /// cambiado el texto a mano).
  void _redactar({bool forzar = false}) {
    if (_editado && !forzar) return;
    final l = _lista;
    _texto.text = l.isEmpty
        ? ''
        : redactarPromocion(
            negocio: _negocio,
            productos: l,
            estilo: _estilo,
            ahora: DateTime.now(),
            nota: _nota.text,
            domicilios: _domicilios,
            variante: _variante);
    _editado = false;
    _hechoPorIA = false;
  }

  Future<void> _conIA() async {
    final l = _lista;
    if (l.isEmpty) {
      avisar('Primero elige al menos un producto');
      return;
    }
    setState(() => _pensando = true);
    final s = SyncService.instance;
    final r = await AsistenteService.promocionIA(cuerpoPromocionIA(l, _estilo, DateTime.now()),
        api: s.remoto, hayRed: s.hayRed);
    if (!mounted) return;
    setState(() {
      _pensando = false;
      if (r != null) {
        final dir = _negocio.direccion.trim();
        _texto.text = '$r\n\n📲 Pedidos por este WhatsApp${dir.isEmpty ? '' : ' · $dir'}';
        _editado = false;
        _hechoPorIA = true;
      } else {
        _variante++;
        _redactar(forzar: true);
      }
    });
    if (r == null) avisar('Sin señal o sin IA en la nube: te dejamos otra versión hecha en el celular');
  }

  Future<void> _elegirMedia(ImageSource origen, {bool video = false}) async {
    final picker = ImagePicker();
    try {
      final f = video
          ? await picker.pickVideo(source: origen, maxDuration: const Duration(seconds: 60))
          : await picker.pickImage(source: origen, maxWidth: 1600, imageQuality: 85);
      if (f == null) return;
      final bytes = video ? null : await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _media = f;
        _esVideo = video;
        _foto = bytes;
      });
    } catch (_) {
      avisar('No se pudo abrir la cámara o la galería');
    }
  }

  Future<Uint8List?> _capturarCartel() async {
    try {
      final b = _cartel.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (b == null) return null;
      final img = await b.toImage(pixelRatio: 1080 / b.size.width);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _compartir({required bool cartel}) async {
    final texto = _texto.text.trim();
    if (_lista.isEmpty || texto.isEmpty) {
      avisar('Elige al menos un producto');
      return;
    }
    // El texto queda copiado: si la app elegida no lo pega solo, se pega.
    await Clipboard.setData(ClipboardData(text: texto));
    final archivos = <XFile>[];
    if (cartel) {
      final png = await _capturarCartel();
      if (png == null) {
        avisar('No se pudo crear la imagen');
        return;
      }
      archivos.add(XFile.fromData(png, mimeType: 'image/png', name: 'promocion.png'));
    } else if (_media != null) {
      archivos.add(_media!);
    }
    if (archivos.isEmpty) {
      await enviarWhatsApp(texto);
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(text: texto, files: archivos, subject: 'Promoción'));
      avisar('Texto copiado: si no aparece junto a la imagen, mantén presionado y pega');
    } catch (_) {
      avisar('Este equipo no permite compartir archivos. El texto quedó copiado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final oc = ocasionDelMomento(DateTime.now());
    final lista = _lista;
    return Scaffold(
      appBar: AppBar(title: const Text('Promociones')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Paleta.of(context).asistenteFondo, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Text(oc.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  oc.nombre == 'Hoy'
                      ? 'Elige productos, ponles precio de oferta, agrega una foto y la IA te escribe el anuncio.'
                      : 'Temporada de ${oc.nombre}: buen momento para una promoción. La IA ya lo tiene en cuenta.',
                  style: t.bodyMedium),
            ),
          ]),
        ),
        const TituloSeccion('1. Productos en oferta'),
        if (_productos.isEmpty)
          Text('No hay productos con existencias. Agrégalos en Inventario.', style: t.bodyMedium)
        else
          Card(
            child: Column(children: [
              for (final (i, p) in _productos.indexed) ...[
                if (i > 0) const Divider(indent: 16, height: 1),
                CheckboxListTile(
                  value: _elegidos.contains(p.id),
                  onChanged: (v) => setState(() {
                    v == true ? _elegidos.add(p.id) : _elegidos.remove(p.id);
                    _redactar();
                  }),
                  title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: _elegidos.contains(p.id)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextField(
                            controller: _ctrl(p),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(_redactar),
                            decoration: InputDecoration(
                                isDense: true,
                                labelText: 'Precio de oferta (normal ${cop(p.precio)})',
                                prefixText: r'$ '),
                          ),
                        )
                      : Text(p.esServicio
                          ? '${cop(p.precio)} · servicio'
                          : '${cop(p.precio)} · hay ${cantidadTexto(p.stock)}'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ]),
          ),
        const TituloSeccion('2. Foto o video'),
        _media == null
            ? Wrap(spacing: 8, runSpacing: 8, children: [
                if (_hayCamara)
                  OutlinedButton.icon(
                      onPressed: () => _elegirMedia(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Tomar foto')),
                OutlinedButton.icon(
                    onPressed: () => _elegirMedia(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Foto de la galería')),
                if (_hayCamara)
                  OutlinedButton.icon(
                      onPressed: () => _elegirMedia(ImageSource.camera, video: true),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Grabar video')),
                OutlinedButton.icon(
                    onPressed: () => _elegirMedia(ImageSource.gallery, video: true),
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Video de la galería')),
              ])
            : Card(
                clipBehavior: Clip.antiAlias,
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: _foto != null
                        ? Image.memory(_foto!, fit: BoxFit.cover)
                        : Container(
                            color: esquema.surfaceContainerHighest,
                            child: const Icon(Icons.play_circle_fill, size: 44)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_esVideo ? 'Video listo (hasta 60 s)' : 'Foto lista: va en la imagen y al compartir',
                        style: t.bodyMedium),
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    onPressed: () => setState(() {
                      _media = null;
                      _foto = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ]),
              ),
        const TituloSeccion('3. El anuncio'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in EstiloPromo.values)
            ChoiceChip(
              label: Text(e == EstiloPromo.temporada ? '${oc.emoji} ${oc.nombre}' : nombresEstilo[e]!),
              selected: _estilo == e,
              onSelected: (_) => setState(() {
                _estilo = e;
                _redactar(forzar: true);
              }),
            ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _nota,
          onChanged: (_) => setState(_redactar),
          decoration: const InputDecoration(labelText: 'Detalle (opcional)', hintText: 'Ej.: solo hasta el sábado'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hago domicilios'),
          value: _domicilios,
          onChanged: (v) => setState(() {
            _domicilios = v;
            _redactar();
          }),
        ),
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _pensando ? null : _conIA,
              icon: _pensando
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_pensando ? 'Redactando…' : 'Redactar con IA'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: lista.isEmpty
                ? null
                : () => setState(() {
                      _variante++;
                      _redactar(forzar: true);
                    }),
            icon: const Icon(Icons.refresh),
            label: const Text('Otra versión'),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _texto,
          minLines: 6,
          maxLines: 14,
          onChanged: (_) => _editado = true,
          decoration: InputDecoration(
            labelText: _hechoPorIA ? 'Texto redactado por la IA (puedes cambiarlo)' : 'Texto del anuncio (puedes cambiarlo)',
            alignLabelWithHint: true,
            hintText: 'Elige productos y aquí aparece el anuncio',
          ),
        ),
        if (lista.isNotEmpty) ...[
          const TituloSeccion('4. Imagen para el estado'),
          RepaintBoundary(
            key: _cartel,
            child: CartelPromo(negocio: _negocio, productos: lista, estilo: _estilo, foto: _foto),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1C7A43), foregroundColor: Colors.white),
          onPressed: lista.isEmpty ? null : () => _compartir(cartel: true),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Compartir imagen + texto'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: lista.isEmpty ? null : () => _compartir(cartel: false),
          icon: Icon(_media == null ? Icons.chat_outlined : (_esVideo ? Icons.videocam_outlined : Icons.photo_outlined)),
          label: Text(_media == null
              ? 'Enviar solo el texto por WhatsApp'
              : (_esVideo ? 'Compartir el video + texto' : 'Compartir la foto + texto')),
        ),
        const SizedBox(height: 8),
        Text('Consejo: publícala en tu estado de WhatsApp y en una lista de difusión. '
            'Los estados se ven más entre 6 y 8 de la noche.',
            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
      ]),
    );
  }
}

/// Imagen cuadrada de la promoción (1080 × 1080 al compartir), con los
/// colores de la marca, la foto si la hay y los precios bien grandes.
class CartelPromo extends StatelessWidget {
  final PerfilNegocio negocio;
  final List<ProductoPromo> productos;
  final EstiloPromo estilo;
  final Uint8List? foto;
  const CartelPromo({super.key, required this.negocio, required this.productos, required this.estilo, this.foto});

  static const _fondo = Color(0xFF17362C);
  static const _menta = Color(0xFF8FE0AE);
  static const _amarillo = Color(0xFFF4C55A);

  @override
  Widget build(BuildContext context) {
    final oc = ocasionDelMomento(DateTime.now());
    final titulo = switch (estilo) {
      EstiloPromo.urgente => '¡ÚLTIMAS UNIDADES!',
      EstiloPromo.combo => '¡COMBO ESPECIAL!',
      EstiloPromo.cercano => 'PARA EL BARRIO',
      EstiloPromo.temporada => oc.nombre.toUpperCase(),
      EstiloPromo.alegre => '¡OFERTAS!',
    };
    final mejor = productos.fold<int>(0, (m, p) => p.descuento > m ? p.descuento : m);
    final visibles = productos.take(foto == null ? 6 : 4).toList();
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final u = box.maxWidth / 100; // 1 unidad = 1 % del ancho
        return ClipRRect(
          borderRadius: BorderRadius.circular(u * 3),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F4A3C), _fondo, Color(0xFF0E231C)]),
            ),
            child: Stack(children: [
              if (foto != null)
                Positioned(
                  right: 0,
                  top: 0,
                  width: u * 48,
                  height: u * 100,
                  child: ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                            colors: [Colors.transparent, Colors.black], stops: [0, .35])
                        .createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: Image.memory(foto!, fit: BoxFit.cover),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(u * 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    LogoVertex(tam: u * 7),
                    SizedBox(width: u * 2),
                    Flexible(
                      child: Text(negocio.nombreVisible.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _menta, fontSize: u * 3.6, fontWeight: FontWeight.w800, letterSpacing: u * .3)),
                    ),
                  ]),
                  SizedBox(height: u * 4),
                  SizedBox(
                    width: foto == null ? null : u * 52,
                    child: Text(titulo,
                        style: TextStyle(
                            color: Colors.white, fontSize: u * 9, fontWeight: FontWeight.w900, height: 1)),
                  ),
                  if (mejor >= 5)
                    Container(
                      margin: EdgeInsets.only(top: u * 2),
                      padding: EdgeInsets.symmetric(horizontal: u * 2.4, vertical: u * .8),
                      decoration:
                          BoxDecoration(color: _amarillo, borderRadius: BorderRadius.circular(u * 5)),
                      child: Text('HASTA -$mejor %',
                          style: TextStyle(color: _fondo, fontSize: u * 3.6, fontWeight: FontWeight.w900)),
                    ),
                  const Spacer(),
                  for (final p in visibles)
                    Padding(
                      padding: EdgeInsets.only(bottom: u * 1.6),
                      child: SizedBox(
                        width: foto == null ? null : u * 56,
                        child: Row(children: [
                          Expanded(
                            child: Text(p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontSize: u * 4.2, fontWeight: FontWeight.w600)),
                          ),
                          if (p.descuento > 0) ...[
                            Text(cop(p.precioAntes),
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: u * 3,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.white54)),
                            SizedBox(width: u * 1.5),
                          ],
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: u * 2, vertical: u * .6),
                            decoration:
                                BoxDecoration(color: _amarillo, borderRadius: BorderRadius.circular(u * 2)),
                            child: Text(cop(p.precio),
                                style: TextStyle(color: _fondo, fontSize: u * 4.4, fontWeight: FontWeight.w900)),
                          ),
                        ]),
                      ),
                    ),
                  if (productos.length > visibles.length)
                    Text('y ${productos.length - visibles.length} ofertas más',
                        style: TextStyle(color: _menta, fontSize: u * 3.2)),
                  SizedBox(height: u * 2),
                  Text(
                      negocio.telefono.trim().isEmpty
                          ? 'Pida por WhatsApp'
                          : 'Pida por WhatsApp · ${mostrarTelefono(negocio.telefono)}',
                      style: TextStyle(color: _menta, fontSize: u * 3.4, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
