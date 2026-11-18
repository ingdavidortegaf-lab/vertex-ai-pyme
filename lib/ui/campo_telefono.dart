import 'package:flutter/material.dart';
import '../domain/formato.dart';
import '../domain/paises.dart';

/// Celular con su país: guarda el indicativo elegido y el número que se
/// escribe. [valor] da el número completo para WhatsApp (o null si no es
/// válido; '' si está vacío).
class TelefonoCtrl {
  final TextEditingController texto;
  Pais pais;
  TelefonoCtrl([String guardado = ''])
      : texto = TextEditingController(),
        pais = colombia {
    final (cod, nacional) = separarTelefono(guardado);
    pais = paises.firstWhere((p) => p.codigo == cod, orElse: () => colombia);
    texto.text = pais.codigo == '57' ? (nacional.isEmpty ? '' : mostrarTelefono('57$nacional')) : nacional;
  }

  String? get valor => normalizarTelefono(texto.text, pais: pais.codigo);
  void dispose() => texto.dispose();
}

/// Campo de celular con selector de país (bandera e indicativo). Sirve para
/// clientes, proveedores y el negocio de cualquier país: Colombia, Estados
/// Unidos, Venezuela, España…
class CampoTelefono extends StatefulWidget {
  final TelefonoCtrl ctrl;
  final String etiqueta;
  final bool requerido;
  final ValueChanged<String>? alEnviar;
  const CampoTelefono({
    super.key,
    required this.ctrl,
    this.etiqueta = 'Celular para WhatsApp (opcional)',
    this.requerido = false,
    this.alEnviar,
  });
  @override
  State<CampoTelefono> createState() => _CampoTelefonoState();
}

class _CampoTelefonoState extends State<CampoTelefono> {
  Future<void> _elegirPais() async {
    final p = await showModalBottomSheet<Pais>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ListaPaises(),
    );
    if (p != null && mounted) setState(() => widget.ctrl.pais = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.ctrl.pais;
    return TextFormField(
      controller: widget.ctrl.texto,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        hintText: p.ejemplo,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 2),
          child: TextButton(
            key: const Key('selector_pais'),
            onPressed: _elegirPais,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(p.bandera, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text('+${p.codigo}'),
              const Icon(Icons.arrow_drop_down, size: 18),
            ]),
          ),
        ),
        helperText: 'Toca la bandera para elegir otro país',
      ),
      validator: (v) {
        final r = normalizarTelefono(v ?? '', pais: p.codigo);
        if (r == null) {
          return p.codigo == '57'
              ? 'Celular colombiano de 10 dígitos que empiece por 3'
              : 'Revisa el número: en ${p.nombre} se escribe como ${p.ejemplo}';
        }
        if (widget.requerido && r.isEmpty) return 'Escribe el celular';
        return null;
      },
      onFieldSubmitted: widget.alEnviar,
    );
  }
}

class _ListaPaises extends StatefulWidget {
  const _ListaPaises();
  @override
  State<_ListaPaises> createState() => _ListaPaisesState();
}

class _ListaPaisesState extends State<_ListaPaises> {
  var _filtro = '';
  @override
  Widget build(BuildContext context) {
    final f = normalizarTexto(_filtro);
    final l = paises
        .where((p) => f.isEmpty || normalizarTexto(p.nombre).contains(f) || p.codigo.startsWith(f.replaceAll('+', '')))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar país o indicativo'),
              onChanged: (v) => setState(() => _filtro = v),
            ),
          ),
          Expanded(
            child: ListView(children: [
              for (final p in l)
                ListTile(
                  leading: Text(p.bandera, style: const TextStyle(fontSize: 24)),
                  title: Text(p.nombre),
                  trailing: Text('+${p.codigo}'),
                  onTap: () => Navigator.pop(context, p),
                ),
              const ListTile(
                leading: Icon(Icons.public),
                title: Text('¿Otro país?'),
                subtitle: Text('Escribe el número completo empezando con + (ej.: +61 412 345 678)'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
