import 'package:flutter/material.dart';
import '../data/local_db.dart';
import 'privacidad_page.dart';

/// Autorización de tratamiento de datos (Ley 1581 de 2012 – Habeas Data).
/// Se pide en el primer uso; sin aceptar, la app no avanza. Queda guardada
/// (con fecha) en la base cifrada y se puede revocar desde el menú.
class ConsentGate extends StatefulWidget {
  final Widget child;
  const ConsentGate({super.key, required this.child});

  static const claveConsentimiento = 'consentimiento_v1';

  /// Al revocar, la pantalla vuelve a pedir la autorización.
  static final revocado = ValueNotifier<int>(0);

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool? _ok;
  bool _check = false;

  @override
  void initState() {
    super.initState();
    ConsentGate.revocado.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    ConsentGate.revocado.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    final v = await LocalDb.instance.ajuste(ConsentGate.claveConsentimiento);
    if (mounted) {
      setState(() {
        _ok = v != null;
        _check = false;
      });
    }
  }

  Future<void> _aceptar() async {
    await LocalDb.instance.setAjuste(ConsentGate.claveConsentimiento,
        DateTime.now().toUtc().toIso8601String());
    if (mounted) setState(() => _ok = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ok == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_ok == true) return widget.child;
    return Scaffold(
      appBar: AppBar(title: const Text('Tus datos y tu privacidad')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Expanded(
              child: SingleChildScrollView(child: TextoAvisoPrivacidad()),
            ),
            CheckboxListTile(
              value: _check,
              onChanged: (v) => setState(() => _check = v ?? false),
              title: const Text(
                  'Leí el aviso de privacidad y autorizo el tratamiento de mis datos'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _check ? _aceptar : null,
                child: const Text('Continuar'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
