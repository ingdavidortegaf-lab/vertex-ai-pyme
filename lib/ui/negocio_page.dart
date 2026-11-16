import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import 'comun.dart';
import 'tema.dart';

const tiposNegocio = [
  'Tienda o minimercado',
  'Droguería',
  'Ferretería',
  'Agro y veterinaria',
  'Restaurante o comidas',
  'Ropa y calzado',
  'Otro',
];

/// Preguntas al dueño sobre su negocio: nombre, tipo y meta de ventas del
/// mes. Se guardan solo en el celular y personalizan el tablero y el asistente.
Future<void> mostrarMiNegocio(BuildContext context) async {
  final db = LocalDb.instance;
  final actual = (
    await db.ajuste('negocio_nombre') ?? '',
    await db.ajuste('negocio_tipo') ?? '',
    double.tryParse(await db.ajuste('negocio_meta') ?? '') ?? 0,
  );
  if (!context.mounted) return;
  final r = await showModalBottomSheet<(String, String, double)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormNegocio(actual: actual),
  );
  if (r == null) return;
  final (nombre, tipo, meta) = r;
  await db.setAjuste('negocio_nombre', nombre);
  await db.setAjuste('negocio_tipo', tipo);
  await db.setAjuste('negocio_meta', meta.toStringAsFixed(0));
  db.cambios.value++;
  avisar('Datos del negocio guardados');
}

class _FormNegocio extends StatefulWidget {
  final (String, String, double) actual;
  const _FormNegocio({required this.actual});
  @override
  State<_FormNegocio> createState() => _FormNegocioState();
}

class _FormNegocioState extends State<_FormNegocio> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.actual.$1);
  late String _tipo = widget.actual.$2;
  late final _meta = TextEditingController(
      text: widget.actual.$3 > 0 ? cop(widget.actual.$3).substring(1) : '');

  @override
  void dispose() {
    _nombre.dispose();
    _meta.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (
      _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
      _tipo,
      _meta.text.trim().isEmpty ? 0.0 : (parseMonto(_meta.text) ?? 0.0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
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
            Text('Con esto el tablero y el asistente se ajustan a ti. Se guarda '
                'solo en este celular.',
                style: t.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            Text('¿Cómo se llama tu negocio?', style: t.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: const InputDecoration(
                  hintText: 'Ej.: Tienda Don José', counterText: ''),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Escribe el nombre del negocio' : null,
            ),
            const SizedBox(height: 18),
            Text('¿Qué tipo de negocio es?', style: t.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in tiposNegocio)
                ChoiceChip(
                  label: Text(x),
                  selected: _tipo == x,
                  onSelected: (_) => setState(() => _tipo = x),
                ),
            ]),
            const SizedBox(height: 18),
            Text('¿Cuánto quieres vender este mes?', style: t.titleSmall),
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      ),
    );
  }
}
