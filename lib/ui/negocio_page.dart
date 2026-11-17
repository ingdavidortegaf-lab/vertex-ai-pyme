import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../domain/documentos.dart';
import '../domain/formato.dart';
import 'comun.dart';
import 'tema.dart';

const tiposNegocio = [
  'Tienda de todo un poco',
  'Tienda o minimercado',
  'Droguería',
  'Ferretería',
  'Agro y veterinaria',
  'Restaurante o comidas',
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
  db.cambios.value++;
  avisar('Datos del negocio guardados');
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
  late final _tel = TextEditingController(text: mostrarTelefono(widget.actual.telefono));

  @override
  void dispose() {
    for (final c in [_nombre, _meta, _nit, _dir, _tel]) {
      c.dispose();
    }
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
          telefono: normalizarTelefono(_tel.text) ?? '',
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
                  label: Text(x),
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
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'WhatsApp del negocio', hintText: '300 123 4567'),
              validator: (v) => normalizarTelefono(v ?? '') == null
                  ? 'Celular colombiano de 10 dígitos que empiece por 3'
                  : null,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      ),
    );
  }
}
