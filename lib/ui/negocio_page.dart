import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/local_db.dart';
import '../domain/modo_negocio.dart';
import '../domain/documentos.dart';
import '../domain/formato.dart';
import 'campo_telefono.dart';
import 'comun.dart';
import 'tema.dart';

/// Tipos de negocio (con su emoji) para que la app sirva a cualquiera:
/// la tienda de barrio primero, y luego comercio, comidas y servicios.
const tiposNegocio = [
  'Tienda de todo un poco',
  'Tienda o minimercado',
  'Panadería o cafetería',
  'Frutas y verduras',
  'Carnicería o pollo',
  'Droguería',
  'Ferretería',
  'Agro y veterinaria',
  'Licorera',
  'Restaurante o comidas',
  'Comidas rápidas y domicilios',
  'Ropa y calzado',
  'Papelería y variedades',
  'Celulares y tecnología',
  'Artesanías y emprendimiento',
  'Peluquería o belleza',
  'Taller o reparaciones',
  'Lavadero de carros y motos',
  'Transporte o mensajería',
  'Hospedaje',
  'Servicios profesionales',
  'Otro',
];

/// Preguntas al dueño sobre su negocio: nombre, tipo, meta del mes y los
/// datos que salen en comprobantes y cotizaciones (NIT, dirección, WhatsApp).
/// Se guardan solo en el celular.
Future<void> mostrarMiNegocio(BuildContext context) async {
  final db = LocalDb.instance;
  final actual = await db.perfilNegocio();
  if (!context.mounted) return;
  final r = await showModalBottomSheet<PerfilNegocio>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormNegocio(actual: actual),
  );
  if (r == null) return;
  await db.setAjuste('negocio_nombre', r.nombre);
  await db.setAjuste('negocio_tipo', r.tipo);
  await db.setAjuste('negocio_meta', r.meta.toStringAsFixed(0));
  await db.setAjuste('negocio_nit', r.nit);
  await db.setAjuste('negocio_direccion', r.direccion);
  await db.setAjuste('negocio_telefono', r.telefono);
  await db.setAjuste('negocio_logo', r.logo);
  db.cambios.value++;
  avisar('Datos del negocio guardados');
}

/// Muestra el logo del negocio, guardado en la base o (logos viejos) como
/// archivo en el celular o el PC.
class VistaLogo extends StatelessWidget {
  final String logo;
  final BoxFit ajuste;
  const VistaLogo({super.key, required this.logo, this.ajuste = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    final vacio = Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant);
    if (logo.isEmpty) return vacio;
    final b = bytesDeLogo(logo);
    if (b != null) {
      return Image.memory(b, fit: ajuste, errorBuilder: (c, e, s) => const Icon(Icons.broken_image_outlined));
    }
    if (kIsWeb || !File(logo).existsSync()) return vacio;
    return Image.file(File(logo), fit: ajuste, errorBuilder: (c, e, s) => const Icon(Icons.broken_image_outlined));
  }
}

/// Elige una imagen de la galería y la copia a la carpeta privada de la
/// app; devuelve la ruta (o null si se cancela o falla).
Future<String?> elegirLogoNegocio() async {
  try {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 85);
    if (img == null) return null;
    final bytes = await img.readAsBytes();
    if (bytes.length > 1024 * 1024) {
      avisar('La imagen pesa más de 1 MB; elige una más liviana');
      return null;
    }
    return logoComoTexto(bytes);
  } catch (_) {
    avisar('No se pudo cargar la imagen');
    return null;
  }
}

class _FormNegocio extends StatefulWidget {
  final PerfilNegocio actual;
  const _FormNegocio({required this.actual});
  @override
  State<_FormNegocio> createState() => _FormNegocioState();
}

class _FormNegocioState extends State<_FormNegocio> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.actual.nombre);
  late String _tipo = widget.actual.tipo;
  late final _meta = TextEditingController(
      text: widget.actual.meta > 0 ? cop(widget.actual.meta).substring(1) : '');
  late final _nit = TextEditingController(text: widget.actual.nit);
  late final _dir = TextEditingController(text: widget.actual.direccion);
  late final _tel = TelefonoCtrl(widget.actual.telefono);
  late String _logo = widget.actual.logo;

  Future<void> _elegirLogo() async {
    final r = await elegirLogoNegocio();
    if (r != null && mounted) setState(() => _logo = r);
  }

  @override
  void dispose() {
    for (final c in [_nombre, _meta, _nit, _dir]) {
      c.dispose();
    }
    _tel.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
        context,
        PerfilNegocio(
          nombre: _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          tipo: _tipo,
          meta: _meta.text.trim().isEmpty ? 0 : (parseMonto(_meta.text) ?? 0),
          nit: _nit.text.trim(),
          direccion: _dir.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          telefono: _tel.valor ?? '',
          logo: _logo,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    Widget pregunta(String s) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(s, style: t.titleSmall));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: p.ventasFondo, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.storefront_outlined, color: p.ventas),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('Cuéntanos de tu negocio', style: t.headlineSmall)),
            ]),
            const SizedBox(height: 6),
            Text('Con esto el tablero, el asistente y tus comprobantes se ajustan '
                'a ti. Se guarda solo en este celular.',
                style: t.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            pregunta('¿Cómo se llama tu negocio?'),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: const InputDecoration(
                  hintText: 'Ej.: Tienda Doña Marta', counterText: ''),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Escribe el nombre del negocio' : null,
            ),
            pregunta('¿Qué tipo de negocio es?'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in tiposNegocio)
                ChoiceChip(
                  label: Text(conEmoji(x)),
                  selected: _tipo == x,
                  onSelected: (_) => setState(() => _tipo = x),
                ),
            ]),
            pregunta('¿Cuánto quieres vender este mes?'),
            TextFormField(
              controller: _meta,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  hintText: 'Ej.: 5.000.000',
                  prefixText: r'$ ',
                  helperText: 'Tu meta. Te mostramos cuánto llevas y cuánto falta.'),
              validator: (v) => (v ?? '').trim().isNotEmpty && parseMonto(v!) == null
                  ? 'Escribe un monto válido'
                  : null,
            ),
            pregunta('Logo del negocio (opcional)'),
            Row(children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: VistaLogo(logo: _logo, ajuste: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Sale en tus facturas y cotizaciones impresas o en PDF.',
                    style: t.bodyMedium),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _elegirLogo,
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(_logo.isEmpty ? 'Elegir imagen' : 'Cambiar'),
                ),
              ),
              if (_logo.isNotEmpty) ...[
                const SizedBox(width: 10),
                TextButton(
                    onPressed: () => setState(() => _logo = ''),
                    child: const Text('Quitar')),
              ],
            ]),
            pregunta('Datos para tus comprobantes (opcional)'),
            TextFormField(
              controller: _nit,
              keyboardType: TextInputType.text,
              maxLength: 20,
              decoration: const InputDecoration(
                  labelText: 'NIT o cédula', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _dir,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              decoration: const InputDecoration(
                  labelText: 'Dirección', hintText: 'Ej.: Cra 20 # 10-15, Trinidad',
                  counterText: ''),
            ),
            const SizedBox(height: 10),
            CampoTelefono(ctrl: _tel, etiqueta: 'WhatsApp del negocio'),
            const SizedBox(height: 20),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      ),
    );
  }
}
