import 'package:flutter/material.dart';
import '../domain/identificacion.dart';

/// Tipo y número de documento más el correo, para clientes y terceros.
class IdentificacionCtrl {
  String tipo;
  final TextEditingController documento;
  final TextEditingController correo;
  IdentificacionCtrl({String tipo = 'CC', String documento = '', String correo = ''})
      : tipo = tiposDocumento.containsKey(tipo) ? tipo : 'CC',
        documento = TextEditingController(text: documento),
        correo = TextEditingController(text: correo);

  /// Documento como se guarda (NIT con su dígito de verificación).
  String get documentoNormal => normalizarDocumento(tipo, documento.text);
  String get correoNormal => normalizarCorreo(correo.text);
  bool get esEmpresa => tipo == 'NIT';

  void dispose() {
    documento.dispose();
    correo.dispose();
  }
}

/// Casillas de identificación. [alCambiarTipo] avisa cuando pasa de persona
/// a empresa (NIT), para cambiar la etiqueta del nombre.
class CamposIdentificacion extends StatefulWidget {
  final IdentificacionCtrl ctrl;
  final VoidCallback? alCambiarTipo;

  /// Texto bajo el título (para qué sirven estos datos).
  final String ayuda;
  const CamposIdentificacion({
    super.key,
    required this.ctrl,
    this.alCambiarTipo,
    this.ayuda = 'Para la factura y el contador. Si no los tienes, déjalos en blanco.',
  });
  @override
  State<CamposIdentificacion> createState() => _CamposIdentificacionState();
}

class _CamposIdentificacionState extends State<CamposIdentificacion> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.documento.addListener(_refrescar);
  }

  @override
  void dispose() {
    widget.ctrl.documento.removeListener(_refrescar);
    super.dispose();
  }

  void _refrescar() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = widget.ctrl;
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    // Para el NIT se muestra el dígito de verificación calculado.
    String? ayudaDoc;
    if (c.tipo == 'NIT' && c.documento.text.trim().isNotEmpty &&
        problemaDocumento('NIT', c.documento.text) == null) {
      ayudaDoc = 'Queda: ${mostrarDocumento('NIT', c.documentoNormal)}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Documento y correo', style: t.titleSmall),
      Text(widget.ayuda, style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final e in const [('CC', 'Cédula'), ('NIT', 'NIT (empresa)'), ('CE', 'C. extranjería'), ('PPT', 'PPT'), ('PA', 'Pasaporte')])
          ChoiceChip(
            key: ValueKey('doc_${e.$1}'),
            label: Text(e.$2),
            selected: c.tipo == e.$1,
            onSelected: (_) {
              setState(() => c.tipo = e.$1);
              widget.alCambiarTipo?.call();
            },
          ),
      ]),
      const SizedBox(height: 8),
      TextFormField(
        key: const ValueKey('campo_documento'),
        controller: c.documento,
        keyboardType: c.tipo == 'PA' || c.tipo == 'CE' ? TextInputType.text : TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 20,
        decoration: InputDecoration(
          labelText: switch (c.tipo) {
            'NIT' => 'NIT (opcional)',
            'CC' => 'Número de cédula (opcional)',
            _ => 'Número del documento (opcional)',
          },
          hintText: c.tipo == 'NIT' ? 'Ej.: 900123456' : 'Ej.: 1118555444',
          helperText: ayudaDoc,
          counterText: '',
          prefixIcon: Icon(c.tipo == 'NIT' ? Icons.business_outlined : Icons.badge_outlined),
        ),
        validator: (v) => problemaDocumento(c.tipo, v ?? ''),
      ),
      const SizedBox(height: 8),
      TextFormField(
        key: const ValueKey('campo_correo'),
        controller: c.correo,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Correo (opcional)',
          hintText: 'Ej.: nombre@gmail.com',
          counterText: '',
          prefixIcon: Icon(Icons.alternate_email),
        ),
        validator: (v) => problemaCorreo(v ?? ''),
      ),
    ]);
  }
}
