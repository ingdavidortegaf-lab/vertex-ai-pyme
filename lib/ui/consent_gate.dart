import 'package:flutter/material.dart';
import '../data/local_db.dart';
import 'ilustraciones.dart';
import 'privacidad_page.dart';
import 'tema.dart';

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
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.pizarra,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(children: [
                const Row(children: [
                  LogoVertex(tam: 32),
                ]),
                const SizedBox(width: 150, height: 120, child: IlustracionEscudo()),
                const SizedBox(height: 10),
                Text('Bienvenido a VERTEX AI Pyme',
                    textAlign: TextAlign.center,
                    style: t.headlineSmall?.copyWith(color: p.tizaBlanca)),
                const SizedBox(height: 6),
                Text('Antes de empezar, lee cómo cuidamos tus datos y los de tus '
                    'clientes.',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: p.tizaSuave)),
              ]),
            ),
          ),
        ),
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: TextoAvisoPrivacidad(),
          ),
        ),
        Material(
          color: esquema.surfaceContainerLowest,
          child: Container(
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: esquema.outlineVariant))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
                child: Column(children: [
                  CheckboxListTile(
                    value: _check,
                    onChanged: (v) => setState(() => _check = v ?? false),
                    title: const Text('Leí el aviso de privacidad y autorizo el '
                        'tratamiento de mis datos'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _check ? _aceptar : null,
                        child: const Text('Aceptar y continuar'),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
